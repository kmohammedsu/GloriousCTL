import CoreGraphics
import Foundation

/// Sends a keystroke through System Events rather than by posting a CGEvent.
///
/// Shortcuts that macOS itself handles — moving between desktops in particular — are
/// matched by the window server, and it ignores synthetic CGEvents no matter how they
/// are constructed. Measured against the screen rather than the window server's own
/// bookkeeping, every variant failed: combined and HID event sources, with and
/// without a marker, with and without gaps between the modifier and the key. Driving
/// System Events works every time.
///
/// This costs a subprocess and needs Automation permission for System Events, so it
/// is reserved for the shortcuts that genuinely require it; ordinary keystrokes still
/// go out as CGEvents, which is faster and needs no permission.
enum SystemShortcutKey {

  /// AppleScript modifier names, in the order System Events expects them.
  private static func modifierList(_ flags: CGEventFlags) -> [String] {
    var names: [String] = []
    if flags.contains(.maskCommand) { names.append("command down") }
    if flags.contains(.maskControl) { names.append("control down") }
    if flags.contains(.maskAlternate) { names.append("option down") }
    if flags.contains(.maskShift) { names.append("shift down") }
    return names
  }

  static func script(key: CGKeyCode, flags: CGEventFlags) -> String {
    let modifiers = modifierList(flags)
    let using =
      modifiers.isEmpty ? "" : " using {\(modifiers.joined(separator: ", "))}"
    return "tell application \"System Events\" to key code \(Int(key))\(using)"
  }
}
