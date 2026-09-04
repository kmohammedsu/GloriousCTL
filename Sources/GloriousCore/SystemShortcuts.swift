import CoreGraphics
import Foundation

public enum SystemShortcuts {

  public static func isAssigned(_ hotkeyID: Int) -> Bool {
    guard let defaults = UserDefaults(suiteName: "com.apple.symbolichotkeys"),
      let hotkeys = defaults.dictionary(forKey: "AppleSymbolicHotKeys")
    else {
      return true
    }
    guard let entry = hotkeys[String(hotkeyID)] as? [String: Any] else {
      return true
    }
    guard (entry["enabled"] as? Bool) ?? false else { return false }

    guard let value = entry["value"] as? [String: Any] else { return true }
    if let parameters = value["parameters"] as? [Any] {
      return parameters.count >= 3
    }
    return false
  }

  public static func keystroke(for action: MacAction)
    -> (key: CGKeyCode, flags: CGEventFlags)?
  {
    guard let fallback = action.keystroke,
      let hotkeyID = action.symbolicHotkeyID
    else { return action.keystroke }
    guard let defaults = UserDefaults(suiteName: "com.apple.symbolichotkeys"),
      let hotkeys = defaults.dictionary(forKey: "AppleSymbolicHotKeys"),
      let entry = hotkeys[String(hotkeyID)] as? [String: Any]
    else {
      return fallback
    }
    guard (entry["enabled"] as? Bool) ?? false else { return nil }
    guard let value = entry["value"] as? [String: Any] else { return fallback }
    guard let parameters = value["parameters"] as? [Any], parameters.count >= 3,
      let keyNumber = parameters[1] as? NSNumber,
      let modifierNumber = parameters[2] as? NSNumber,
      keyNumber.intValue != 65_535
    else { return nil }

    let carbon = modifierNumber.uint64Value
    var flags: CGEventFlags = []
    if carbon & 0x0002_0000 != 0 { flags.insert(.maskShift) }
    if carbon & 0x0004_0000 != 0 { flags.insert(.maskControl) }
    if carbon & 0x0008_0000 != 0 { flags.insert(.maskAlternate) }
    if carbon & 0x0010_0000 != 0 { flags.insert(.maskCommand) }
    if carbon & 0x0080_0000 != 0 { flags.insert(.maskSecondaryFn) }
    return (CGKeyCode(keyNumber.uint16Value), flags)
  }

  public static func unavailableActions(in actions: [MacAction]) -> [MacAction] {
    actions.filter { action in
      guard action.requiresSystemShortcut else { return false }
      guard let id = action.symbolicHotkeyID else { return false }
      return !isAssigned(id)
    }
  }

  public static let settingsHint =
    "System Settings › Keyboard › Keyboard Shortcuts › Mission Control"
}
