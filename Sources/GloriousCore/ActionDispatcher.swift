import AppKit
import CoreGraphics
import Darwin
import Foundation

public enum ActionDispatcher {

  public static let syntheticMarker: Int64 = 0x47_4C_4F_52

  /// `GestureEngine.log` is main-actor isolated, so hop across to reach it.
  private static func logDeliveryFailure(_ action: MacAction) {
    Task { @MainActor in
      GestureEngine.log(
        "\(action.displayName): System Events refused the keystroke — check "
          + "Automation access under Privacy & Security")
    }
  }


  @discardableResult
  public static func perform(_ action: MacAction) -> Bool {
    if let notification = action.dockNotification,
      postDockNotification(notification)
    {
      return true
    }
    if let path = action.launchesApplication,
      FileManager.default.fileExists(atPath: path)
    {
      let url = URL(fileURLWithPath: path)
      let config = NSWorkspace.OpenConfiguration()
      config.activates = true
      NSWorkspace.shared.openApplication(at: url, configuration: config)
      return true
    }
    if let command = action.executableAction,
      launchExecutable(command.path, arguments: command.arguments)
    {
      return true
    }
    if let stroke = SystemShortcuts.keystroke(for: action) {
      // Shortcuts the window server handles itself ignore synthetic CGEvents, so
      // those go through System Events instead. See SystemShortcutKey.
      if action.symbolicHotkeyID != nil {
        let script = SystemShortcutKey.script(key: stroke.key, flags: stroke.flags)
        if launchExecutable("/usr/bin/osascript", arguments: ["-e", script]) {
          return true
        }
        // Posting the event instead almost certainly will not work for a shortcut the
        // window server handles, so the action will appear to do nothing. Say so:
        // without this the most likely cause, Automation access being declined, is
        // invisible.
        logDeliveryFailure(action)
      }
      postKeystroke(key: stroke.key, flags: stroke.flags)
      return true
    }
    if let media = action.mediaKey {
      postMediaKey(media)
      return true
    }
    if let button = action.mouseButton {
      postMouseClick(button)
      return true
    }
    return false
  }

  private typealias CoreDockSender = @convention(c) (CFString, UnsafeMutableRawPointer?) -> Void

  private static let coreDockSender: CoreDockSender? = {
    let path =
      "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/HIServices.framework/Versions/A/HIServices"
    guard let handle = dlopen(path, RTLD_LAZY),
      let symbol = dlsym(handle, "CoreDockSendNotification")
    else { return nil }
    return unsafeBitCast(symbol, to: CoreDockSender.self)
  }()

  @discardableResult
  private static func postDockNotification(_ name: String) -> Bool {
    guard let sender = coreDockSender else { return false }
    sender(name as CFString, nil)
    return true
  }

  @discardableResult
  private static func launchExecutable(_ path: String, arguments: [String]) -> Bool {
    guard FileManager.default.isExecutableFile(atPath: path) else { return false }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = arguments
    do {
      try process.run()
      return true
    } catch {
      return false
    }
  }

  @discardableResult
  public static func perform(_ action: RingAction) -> Bool {
    switch action {
    case .none:
      return false
    case .system(let action):
      return perform(action)
    case .open(let path):
      guard !path.isEmpty else { return false }
      return NSWorkspace.shared.open(URL(fileURLWithPath: path))
    case .openURL(let value):
      let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { return false }
      let normalized = trimmed.contains("://") ? trimmed : "https://" + trimmed
      guard let url = URL(string: normalized) else { return false }
      return NSWorkspace.shared.open(url)
    case .runShortcut(let name):
      let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { return false }
      return launchExecutable("/usr/bin/shortcuts", arguments: ["run", trimmed])
    }
  }

  private static func source() -> CGEventSource? {
    let source = CGEventSource(stateID: .combinedSessionState)
    source?.userData = syntheticMarker
    return source
  }

  private static let modifierKeys: [(flag: CGEventFlags, key: CGKeyCode)] = [
    (.maskControl, 0x3B),
    (.maskShift, 0x38),
    (.maskAlternate, 0x3A),
    (.maskCommand, 0x37),
    (.maskSecondaryFn, 0x3F),
  ]

  public static func postKeystroke(key: CGKeyCode, flags: CGEventFlags) {
    let src = source()
    let held = modifierKeys.filter { flags.contains($0.flag) }

    func post(_ event: CGEvent?, flags: CGEventFlags) {
      guard let event else { return }
      event.flags = flags
      event.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)
      event.post(tap: .cghidEventTap)
    }

    // Posted back to back, the arrow can be processed before the window server has
    // registered the modifier keydown, so a system shortcut sees a bare arrow key and
    // ignores it. Spacing the events lets the modifier state settle first. This runs
    // off the main thread so the pauses never stall the UI.
    let gap: UInt32 = 12_000  // microseconds

    postingQueue.async {
      var accumulated: CGEventFlags = []
      for modifier in held {
        accumulated.insert(modifier.flag)
        post(
          CGEvent(keyboardEventSource: src, virtualKey: modifier.key, keyDown: true),
          flags: accumulated)
        usleep(gap)
      }

      post(CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: true), flags: flags)
      usleep(gap)
      post(CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: false), flags: flags)
      usleep(gap)

      for modifier in held.reversed() {
        accumulated.remove(modifier.flag)
        post(
          CGEvent(keyboardEventSource: src, virtualKey: modifier.key, keyDown: false),
          flags: accumulated)
      }
    }
  }

  /// Serial so two overlapping actions cannot interleave their modifier keys.
  private static let postingQueue = DispatchQueue(
    label: "gloriousctl.keystroke", qos: .userInitiated)

  private static func postMediaKey(_ keyType: Int32) {
    for isDown in [true, false] {
      let flags: NSEvent.ModifierFlags = isDown ? .init(rawValue: 0xA00) : .init(rawValue: 0xB00)
      let data1 = Int((keyType << 16) | ((isDown ? 0xA : 0xB) << 8))
      guard
        let event = NSEvent.otherEvent(
          with: .systemDefined, location: .zero, modifierFlags: flags,
          timestamp: 0, windowNumber: 0, context: nil,
          subtype: 8, data1: data1, data2: -1)
      else { continue }
      event.cgEvent?.post(tap: .cghidEventTap)
    }
  }

  private static func postMouseClick(_ button: CGMouseButton) {
    let location = NSEvent.mouseLocation
    let screenHeight = NSScreen.screens.first?.frame.height ?? 0
    let point = CGPoint(x: location.x, y: screenHeight - location.y)
    let src = source()

    let downType: CGEventType
    let upType: CGEventType
    switch button {
    case .left:
      downType = .leftMouseDown
      upType = .leftMouseUp
    case .right:
      downType = .rightMouseDown
      upType = .rightMouseUp
    default:
      downType = .otherMouseDown
      upType = .otherMouseUp
    }

    for (type, _) in [(downType, true), (upType, false)] {
      guard
        let event = CGEvent(
          mouseEventSource: src, mouseType: type,
          mouseCursorPosition: point, mouseButton: button)
      else { continue }
      event.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)
      event.post(tap: .cghidEventTap)
    }
  }
}
