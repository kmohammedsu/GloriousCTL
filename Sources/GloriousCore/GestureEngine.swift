import AppKit
import Combine
import CoreGraphics
import Foundation

@MainActor
public final class GestureEngine: ObservableObject {

  @Published public private(set) var isRunning = false
  @Published public private(set) var hasAccessibilityPermission = false
  @Published public private(set) var lastGesture: String?
  @Published public var bindings: [PhysicalButton: GestureBinding] = [:]
  @Published public var rings: [PhysicalButton: ActionRingConfiguration] = [:]
  @Published public var separateMouseScrolling = false

  public var recognizer = GestureRecognizer()

  public static var logURL: URL? {
    try? FileManager.default.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask, appropriateFor: nil, create: true
    )
    .appendingPathComponent("GloriousCTL/gesture-log.txt")
  }

  public static func log(_ message: String) {
    guard let url = logURL else { return }
    let stamp = ISO8601DateFormatter().string(from: Date())
    let line = "[\(stamp)] \(message)\n"
    if let handle = try? FileHandle(forWritingTo: url) {
      handle.seekToEndOfFile()
      handle.write(Data(line.utf8))
      try? handle.close()
    } else {
      try? line.write(to: url, atomically: true, encoding: .utf8)
    }
  }

  public static func clearLog() {
    guard let url = logURL else { return }
    try? "".write(to: url, atomically: true, encoding: .utf8)
  }

  private var tap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var trackingButton: PhysicalButton?
  private var startLocation: CGPoint = .zero
  /// Moving reference point for the horizontal repeat ratchet; advances one step at a
  /// time so a long sweep fires repeatedly instead of once.
  private var repeatAnchorX: CGFloat = 0
  private var repeatDidFire = false
  /// Multiplier applied to discrete wheel steps. 1 leaves macOS alone.
  public var scrollSpeed: Double = 1
  private var ringIsVisible = false
  private var ringSelection: Int?
  private var activeRingItems: [ActionRingItem] = []
  private var longPressWorkItem: DispatchWorkItem?
  private let ringOverlay = ActionRingOverlay()

  public init() {
    refreshPermission()
  }

  deinit {}

  @discardableResult
  public func refreshPermission() -> Bool {
    hasAccessibilityPermission = AXIsProcessTrusted()
    return hasAccessibilityPermission
  }

  public func requestPermission() {
    let key = "AXTrustedCheckOptionPrompt" as CFString
    _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    refreshPermission()
  }

  public func openAccessibilitySettings() {
    NSWorkspace.shared.open(
      URL(
        string:
          "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
  }

  public func previewActionRing(for button: PhysicalButton = .middle) {
    let ring = rings[button] ?? ActionRingConfiguration.defaultConfiguration(for: button)
    activeRingItems = ring.items
    startLocation = CGEvent(source: nil)?.location ?? .zero
    ringIsVisible = true
    ringOverlay.show(items: ring.items)
  }

  nonisolated static func button(forEventNumber number: Int64) -> PhysicalButton? {
    switch number {
    case 2: return .middle
    case 3: return .back
    case 4: return .forward
    default: return nil
    }
  }

  public func start() {
    guard !isRunning, refreshPermission() else { return }

    let mask =
      (1 << CGEventType.otherMouseDown.rawValue)
      | (1 << CGEventType.otherMouseUp.rawValue)
      | (1 << CGEventType.otherMouseDragged.rawValue)
      | (1 << CGEventType.scrollWheel.rawValue)

    let callback: CGEventTapCallBack = { proxy, type, event, refcon in
      guard let refcon else { return Unmanaged.passUnretained(event) }
      let engine = Unmanaged<GestureEngine>.fromOpaque(refcon).takeUnretainedValue()
      return MainActor.assumeIsolated {
        engine.handle(proxy: proxy, type: type, event: event)
      }
    }

    guard
      let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: CGEventMask(mask),
        callback: callback,
        userInfo: Unmanaged.passUnretained(self).toOpaque())
    else {
      hasAccessibilityPermission = false
      return
    }

    self.tap = tap
    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    isRunning = true
    Self.log(
      "tap started; enabled bindings: "
        + bindings.values.filter(\.enabled)
        .map { $0.button.displayName }.joined(separator: ", "))
  }

  public func stop() {
    if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
    if let runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    }
    tap = nil
    runLoopSource = nil
    cancelLongPress()
    ringOverlay.hide()
    ringIsVisible = false
    ringSelection = nil
    activeRingItems = []
    trackingButton = nil
    isRunning = false
  }

  private func handle(
    proxy: CGEventTapProxy, type: CGEventType,
    event: CGEvent
  ) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
      return Unmanaged.passUnretained(event)
    }

    if event.getIntegerValueField(.eventSourceUserData) == ActionDispatcher.syntheticMarker {
      return Unmanaged.passUnretained(event)
    }

    if type == .scrollWheel {
      adjustDiscreteScrollIfNeeded(event)
      return Unmanaged.passUnretained(event)
    }

    let number = event.getIntegerValueField(.mouseEventButtonNumber)
    guard let button = Self.button(forEventNumber: number) else {
      if type == .otherMouseDown {
        Self.log("ignored: button number \(number) is not gesture-capable")
      }
      return Unmanaged.passUnretained(event)
    }
    let binding = bindings[button] ?? GestureBinding.defaultBinding(for: button)
    let ring = rings[button] ?? ActionRingConfiguration.defaultConfiguration(for: button)
    guard binding.enabled || ring.enabled else {
      if type == .otherMouseDown {
        Self.log("ignored: \(button.displayName) has no enabled gesture or ring")
      }
      return Unmanaged.passUnretained(event)
    }

    switch type {
    case .otherMouseDown:
      cancelLongPress()
      trackingButton = button
      startLocation = event.location
      ringIsVisible = false
      ringSelection = nil
      activeRingItems = ring.items
      repeatAnchorX = event.location.x
      repeatDidFire = false
      Self.log("down: \(button.displayName) at \(Int(startLocation.x)),\(Int(startLocation.y))")
      if ring.enabled, !ring.items.isEmpty {
        let work = DispatchWorkItem { [weak self] in
          guard let self, self.trackingButton == button else { return }
          self.ringIsVisible = true
          self.ringSelection = nil
          self.ringOverlay.show(items: ring.items)
          Self.log("ring opened: \(button.displayName)")
        }
        longPressWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + ring.holdDuration, execute: work)
      }
      return nil

    case .otherMouseDragged:
      guard trackingButton == button else { return Unmanaged.passUnretained(event) }
      let dx = Double(event.location.x - startLocation.x)
      let dy = Double(event.location.y - startLocation.y)
      if ringIsVisible {
        updateRingSelection(at: event.location)
        return nil
      }
      if hypot(dx, dy) >= recognizer.threshold {
        cancelLongPress()
      }
      if binding.enabled, binding.repeatHorizontal, abs(dx) > abs(dy) {
        emitHorizontalRepeats(for: binding, at: event.location.x)
      }
      return nil

    case .otherMouseUp:
      guard trackingButton == button else { return Unmanaged.passUnretained(event) }
      cancelLongPress()
      trackingButton = nil
      let end = event.location

      if ringIsVisible {
        finishRingSelection(button: button)
        return nil
      }

      if repeatDidFire {
        repeatDidFire = false
        Self.log("up: \(button.displayName) ended a repeat drag; no extra action")
        return nil
      }

      let direction = recognizer.classify(
        dx: Double(end.x - startLocation.x),
        dy: Double(end.y - startLocation.y))
      let action =
        binding.enabled
        ? binding.action(for: direction)
        : (direction == .tap ? GestureBinding.passthroughTap(for: button) : .none)
      lastGesture = "\(button.displayName): \(direction.displayName) → \(action.displayName)"
      let dx = Int(end.x - startLocation.x)
      let dy = Int(end.y - startLocation.y)
      Self.log(
        "up: \(button.displayName) dx=\(dx) dy=\(dy) -> \(direction.rawValue) "
          + "-> \(action.displayName)")

      if action != .none {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
          Self.log(
            "dispatching \(action.displayName)"
              + (action.keystroke.map {
                String(
                  format: " key 0x%02X flags 0x%llX",
                  Int($0.key), $0.flags.rawValue)
              } ?? ""))
          let accepted = ActionDispatcher.perform(action)
          Self.log(accepted ? "dispatch accepted" : "dispatch unavailable")
        }
      } else {
        Self.log("action is Do Nothing; nothing dispatched")
      }
      return nil

    default:
      return Unmanaged.passUnretained(event)
    }
  }

  /// Fires the left/right action once per `repeatStep` points of sideways travel, so
  /// holding the button and sweeping keeps moving instead of acting once on release.
  private func emitHorizontalRepeats(for binding: GestureBinding, at x: CGFloat) {
    let step = max(12, binding.repeatStep)
    var travel = Double(x - repeatAnchorX)
    while abs(travel) >= step {
      let direction: GestureDirection = travel > 0 ? .right : .left
      let action = binding.action(for: direction)
      repeatAnchorX += CGFloat(travel > 0 ? step : -step)
      travel = Double(x - repeatAnchorX)
      guard action != .none else { continue }
      repeatDidFire = true
      cancelLongPress()
      lastGesture = "\(binding.button.displayName): repeat \(direction.displayName) → \(action.displayName)"
      Self.log("repeat: \(direction.rawValue) -> \(action.displayName)")
      _ = ActionDispatcher.perform(action)
    }
  }

  private func cancelLongPress() {
    longPressWorkItem?.cancel()
    longPressWorkItem = nil
  }

  nonisolated public static func shouldReverseScroll(
    isContinuous: Bool,
    separateMouseScrolling: Bool
  ) -> Bool {
    separateMouseScrolling && !isContinuous
  }

  /// Scales one wheel delta. A notch must never round away to nothing, or the wheel
  /// would go dead at low multipliers, so the magnitude is kept at one minimum.
  nonisolated public static func scaledScrollDelta(_ value: Int64, speed: Double) -> Int64 {
    guard value != 0, speed != 1 else { return value }
    let scaled = (Double(value) * speed).rounded()
    if scaled == 0 { return value > 0 ? 1 : -1 }
    return Int64(scaled)
  }

  /// Whole wheel notches. These are genuinely integral.
  private static let lineDeltaFields: [CGEventField] = [
    .scrollWheelEventDeltaAxis1, .scrollWheelEventDeltaAxis2, .scrollWheelEventDeltaAxis3,
  ]

  /// Sub-notch deltas. The fixed-point fields hold 16.16 values, so reading and
  /// writing them through the integer accessors manipulates the raw bits rather than
  /// the scroll distance, and macOS ends up with deltas that disagree with each
  /// other — the wheel then behaves as though nothing was changed at all.
  private static let preciseDeltaFields: [CGEventField] = [
    .scrollWheelEventPointDeltaAxis1, .scrollWheelEventPointDeltaAxis2,
    .scrollWheelEventPointDeltaAxis3, .scrollWheelEventFixedPtDeltaAxis1,
    .scrollWheelEventFixedPtDeltaAxis2, .scrollWheelEventFixedPtDeltaAxis3,
  ]

  /// Direction and speed both act on the wheel only. Continuous events come from the
  /// trackpad and are left exactly as macOS produced them.
  private func adjustDiscreteScrollIfNeeded(_ event: CGEvent) {
    let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
    guard !isContinuous else { return }

    let reverse = Self.shouldReverseScroll(
      isContinuous: isContinuous,
      separateMouseScrolling: separateMouseScrolling)
    let speed = scrollSpeed
    guard reverse || speed != 1 else { return }

    let sign: Double = reverse ? -1 : 1

    for field in Self.lineDeltaFields {
      let value = event.getIntegerValueField(field)
      guard value != 0, value != .min else { continue }
      var updated = Self.scaledScrollDelta(value, speed: speed)
      if reverse { updated = -updated }
      event.setIntegerValueField(field, value: updated)
    }

    for field in Self.preciseDeltaFields {
      let value = event.getDoubleValueField(field)
      guard value != 0 else { continue }
      event.setDoubleValueField(field, value: value * speed * sign)
    }
  }

  private func updateRingSelection(at location: CGPoint) {
    ringSelection = ActionRingSelection.index(
      dx: Double(location.x - startLocation.x),
      dy: Double(location.y - startLocation.y),
      itemCount: activeRingItems.count,
      deadZone: 42)
    ringOverlay.select(ringSelection)
  }

  private func finishRingSelection(button: PhysicalButton? = nil) {
    let selected = ringSelection.flatMap { index in
      activeRingItems.indices.contains(index) ? activeRingItems[index] : nil
    }
    dismissRing()
    guard let selected, selected.action.isConfigured else {
      Self.log("ring cancelled")
      return
    }
    let source = button?.displayName ?? "Action"
    lastGesture = "\(source) ring → \(selected.displayName)"
    Self.log("ring selected: \(selected.displayName)")
    // The overlay window has just been ordered out. Injecting a system hotkey while
    // the window server is still settling that change gets it dropped, so wait
    // noticeably longer here than for a plain drag, which has no window to close.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
      let accepted = ActionDispatcher.perform(selected.action)
      Self.log(accepted ? "ring dispatch accepted" : "ring dispatch unavailable")
    }
  }

  private func dismissRing() {
    ringOverlay.hide()
    ringIsVisible = false
    ringSelection = nil
    activeRingItems = []
  }
}
