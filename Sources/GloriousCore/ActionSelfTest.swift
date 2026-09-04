import AppKit
import CoreGraphics
import Foundation

private final class KeyCapture: @unchecked Sendable {
  var observed: [(key: Int64, flags: UInt64)] = []
  var sawFlagsChanged = false
}
private let capture = KeyCapture()

public enum ActionSelfTest {

  public static func run() -> String {
    var log = "GloriousCTL — action dispatch check\n"
    log += "Started: \(ISO8601DateFormatter().string(from: Date()))\n\n"
    log += "Accessibility: \(AXIsProcessTrusted() ? "granted" : "NOT granted")\n\n"

    guard AXIsProcessTrusted() else {
      return log + "Cannot post events without Accessibility.\n"
    }

    capture.observed.removeAll()
    capture.sawFlagsChanged = false

    let mask =
      (1 << CGEventType.keyDown.rawValue)
      | (1 << CGEventType.flagsChanged.rawValue)
    let callback: CGEventTapCallBack = { _, type, event, _ in
      let key = event.getIntegerValueField(.keyboardEventKeycode)
      capture.observed.append((key, event.flags.rawValue))
      if type == .flagsChanged { capture.sawFlagsChanged = true }
      return Unmanaged.passUnretained(event)
    }

    guard
      let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap, place: .tailAppendEventTap,
        options: .listenOnly, eventsOfInterest: CGEventMask(mask),
        callback: callback, userInfo: nil)
    else {
      return log + "Could not create an observation tap.\n"
    }
    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)

    CFRunLoopRunInMode(.defaultMode, 0.3, false)

    let target = MacAction.missionControl
    guard let stroke = target.keystroke else { return log + "no keystroke\n" }
    log += String(
      format: "Posting %@: key 0x%02X flags 0x%llX\n",
      target.displayName, Int(stroke.key), stroke.flags.rawValue)

    ActionDispatcher.perform(target)
    CFRunLoopRunInMode(.defaultMode, 0.8, false)

    CGEvent.tapEnable(tap: tap, enable: false)
    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)

    log += "\nKey-down events observed while posting: \(capture.observed.count)\n"
    for entry in capture.observed {
      log += String(
        format: "  key 0x%02X  flags 0x%llX%@\n", entry.key, entry.flags,
        entry.key == Int64(stroke.key) ? "   <-- ours" : "")
    }

    let sawOurs = capture.observed.contains { $0.key == Int64(stroke.key) }
    let sawControl = capture.observed.contains {
      $0.key == Int64(stroke.key) && ($0.flags & CGEventFlags.maskControl.rawValue) != 0
    }

    log += "\nModifier (flagsChanged) events seen: \(capture.sawFlagsChanged)\n"
    log += "\nVERDICT\n"
    if !sawOurs {
      log += "  The keystroke never entered the event stream. The post itself failed.\n"
    } else if !sawControl {
      log += "  The key was posted but WITHOUT the Control modifier, so macOS saw a\n"
      log += "  plain Up Arrow and had no reason to open Mission Control.\n"
    } else if !capture.sawFlagsChanged {
      log += "  The key was posted with the Control flag set, but no real modifier\n"
      log += "  key event accompanied it. System hotkeys are handled by the\n"
      log += "  WindowServer, which reads actual modifier state, so it saw a bare\n"
      log += "  Up Arrow and ignored it.\n"
    } else {
      log += "  Keystroke and modifier key events both posted correctly. If nothing\n"
      log += "  happened, the system hotkey is disabled or remapped under\n"
      log += "  System Settings > Keyboard > Keyboard Shortcuts > Mission Control.\n"
    }
    return log
  }
}
