import AppKit
import CoreGraphics
import GloriousCore
import SwiftUI

@MainActor
enum AppBootstrap {
  private static let maintenanceFlags: Set<String> = [
    "--preview-action-ring",
    "--simulate-gesture",
    "--fix-gesture-buttons",
    "--self-test-actions",
    "--self-test-gestures",
    "--probe-commands",
    "--probe-write",
    "--self-test-write",
    "--render-main-window",
  ]

  static func renderMainWindowIfRequested(controller: DeviceController) {
    let arguments = CommandLine.arguments
    guard let flagIndex = arguments.firstIndex(of: "--render-main-window") else { return }
    let output =
      arguments.indices.contains(flagIndex + 1)
      ? arguments[flagIndex + 1]
      : "/tmp/gloriousctl-main-window.png"
    controller.preparePreviewState()
    let size = NSSize(width: 1180, height: 760)
    let host = NSHostingView(
      rootView: MainWindow()
        .environmentObject(controller)
        .frame(width: size.width, height: size.height)
    )
    host.frame = NSRect(origin: .zero, size: size)
    host.layoutSubtreeIfNeeded()
    if let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
      host.cacheDisplay(in: host.bounds, to: bitmap)
      let data = bitmap.representation(using: .png, properties: [:])
      try? data?.write(to: URL(fileURLWithPath: output), options: .atomic)
    }
    exit(0)
  }

  static func start(controller: DeviceController) {
    let arguments = Set(CommandLine.arguments)
    guard !maintenanceFlags.isDisjoint(with: arguments) else {
      DispatchQueue.main.async {
        controller.connect()
        controller.startMonitoring()
        controller.saveGestureBindings()
      }
      return
    }

    controller.connect()
    if arguments.contains("--preview-action-ring") {
      controller.gestures.previewActionRing()
    } else if arguments.contains("--simulate-gesture") {
      simulateGesture(controller: controller)
    } else if arguments.contains("--fix-gesture-buttons") {
      fixGestureButtons(controller: controller)
    } else if arguments.contains("--self-test-actions") {
      writeReport(ActionSelfTest.run(), named: "action-check.txt")
      NSApplication.shared.terminate(nil)
    } else if arguments.contains("--self-test-gestures") {
      testGestures(controller: controller)
    } else if arguments.contains("--probe-commands") {
      _ = controller.runCommandWindowProbe()
      NSApplication.shared.terminate(nil)
    } else if arguments.contains("--probe-write") {
      _ = controller.runWriteStrategyProbe()
      NSApplication.shared.terminate(nil)
    } else if arguments.contains("--self-test-write") {
      _ = controller.runWriteSelfTest()
      NSApplication.shared.terminate(nil)
    }
  }

  private static func simulateGesture(controller: DeviceController) {
    GestureEngine.clearLog()
    GestureEngine.log("=== simulate-gesture begin ===")
    controller.saveGestureBindings()
    GestureEngine.log("tap running: \(controller.gestures.isRunning)")
    let source = CGEventSource(stateID: .hidSystemState)
    let start = CGPoint(x: 600, y: 500)

    func post(_ type: CGEventType, at point: CGPoint) {
      guard let button = CGMouseButton(rawValue: 3),
        let event = CGEvent(
          mouseEventSource: source,
          mouseType: type,
          mouseCursorPosition: point,
          mouseButton: button
        )
      else { return }
      event.setIntegerValueField(.mouseEventButtonNumber, value: 3)
      event.post(tap: .cghidEventTap)
    }

    post(.otherMouseDown, at: start)
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    for step in 1...6 {
      post(.otherMouseDragged, at: CGPoint(x: start.x, y: start.y - CGFloat(step) * 20))
      RunLoop.current.run(until: Date().addingTimeInterval(0.03))
    }
    post(.otherMouseUp, at: CGPoint(x: start.x, y: start.y - 120))
    RunLoop.current.run(until: Date().addingTimeInterval(1.2))
    GestureEngine.log("=== simulate-gesture end ===")
    NSApplication.shared.terminate(nil)
  }

  private static func fixGestureButtons(controller: DeviceController) {
    var report = "GloriousCTL — gesture button mapping\n\n"
    guard let config = controller.workingConfig else {
      writeReport(
        report + "No configuration loaded (mouse not connected?)\n", named: "button-map.txt")
      NSApplication.shared.terminate(nil)
      return
    }

    for button in [PhysicalButton.back, .forward, .middle] {
      let action = config.action(for: button)
      let isMouseButton: Bool
      if case .mouseButton = action { isMouseButton = true } else { isMouseButton = false }
      report += "  \(button.displayName): \(action.displayName)"
      report += isMouseButton ? "  (usable for gestures)\n" : "  <-- NOT a mouse button\n"
    }

    let buttons = controller.gestures.bindings.compactMap { button, binding in
      binding.enabled && controller.gestureNeedsDeviceRemap(button) ? button : nil
    }
    if buttons.isEmpty {
      report += "\nNo remapping needed.\n"
    } else {
      buttons.forEach(controller.prepareButtonForGestures)
      report += "\nRemapping: \(buttons.map(\.displayName).joined(separator: ", "))\n"
      report +=
        controller.applyToDevice()
        ? "Written to the mouse successfully.\n"
        : "Write FAILED: \(controller.lastError ?? "unknown")\n"
    }
    writeReport(report, named: "button-map.txt")
    NSApplication.shared.terminate(nil)
  }

  private static func testGestures(controller: DeviceController) {
    var report = "GloriousCTL — gesture plumbing check\n\n"
    let granted = controller.gestures.refreshPermission()
    report += "Accessibility permission: \(granted ? "granted" : "NOT granted")\n"
    controller.saveGestureBindings()
    report += "Event tap running: \(controller.gestures.isRunning)\nBindings:\n"
    for binding in controller.gestures.bindings.values.sorted(by: {
      $0.button.rawValue < $1.button.rawValue
    }) {
      report += "  \(binding.button.displayName): \(binding.enabled ? "enabled" : "disabled")  "
      report +=
        GestureDirection.allCases.map {
          "\($0.rawValue)=\(binding.action(for: $0).displayName)"
        }.joined(separator: ", ") + "\n"
    }
    report += "\nAuto-switch enabled: \(controller.appSwitcher.isEnabled)\n"
    writeReport(report, named: "gesture-check.txt")
    NSApplication.shared.terminate(nil)
  }

  private static func writeReport(_ report: String, named filename: String) {
    guard
      let base = try? FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
      ).appendingPathComponent("GloriousCTL", isDirectory: true)
    else { return }
    try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    try? report.write(
      to: base.appendingPathComponent(filename),
      atomically: true,
      encoding: .utf8
    )
  }
}
