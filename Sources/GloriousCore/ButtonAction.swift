import Foundation

public enum PhysicalButton: Int, CaseIterable, Codable, Identifiable, Sendable {
  case left = 0
  case right = 1
  case middle = 2
  case back = 3
  case forward = 4
  case dpi = 5

  public var id: Int { rawValue }
  public var displayName: String {
    switch self {
    case .left: return "Left Click"
    case .right: return "Right Click"
    case .middle: return "Middle Click"
    case .back: return "Side Back"
    case .forward: return "Side Forward"
    case .dpi: return "DPI Button"
    }
  }

  public var factoryDefault: ButtonAction {
    switch self {
    case .left: return .mouseButton(.left)
    case .right: return .mouseButton(.right)
    case .middle: return .mouseButton(.middle)
    case .back: return .mouseButton(.back)
    case .forward: return .mouseButton(.forward)
    case .dpi: return .dpiAction(.cycleUp)
    }
  }
}

public enum MouseButtonCode: UInt8, CaseIterable, Codable, Sendable {
  case left = 0x01
  case right = 0x02
  case middle = 0x04
  case back = 0x08
  case forward = 0x10

  public var displayName: String {
    switch self {
    case .left: return "Left Click"
    case .right: return "Right Click"
    case .middle: return "Middle Click"
    case .back: return "Back"
    case .forward: return "Forward"
    }
  }
}

public enum DPIActionCode: UInt8, CaseIterable, Codable, Sendable {
  case cycleUp = 0x00
  case increase = 0x01
  case decrease = 0x02

  public var displayName: String {
    switch self {
    case .cycleUp: return "Cycle DPI Stages"
    case .increase: return "DPI +"
    case .decrease: return "DPI −"
    }
  }
}

public enum MediaKeyCode: UInt8, CaseIterable, Codable, Sendable {
  case playPause = 0xCD
  case stop = 0xB7
  case next = 0xB5
  case previous = 0xB6
  case volumeUp = 0xE9
  case volumeDown = 0xEA
  case mute = 0xE2

  public var displayName: String {
    switch self {
    case .playPause: return "Play / Pause"
    case .stop: return "Stop"
    case .next: return "Next Track"
    case .previous: return "Previous Track"
    case .volumeUp: return "Volume Up"
    case .volumeDown: return "Volume Down"
    case .mute: return "Mute"
    }
  }
}

public struct KeyModifiers: OptionSet, Codable, Hashable, Sendable {
  public let rawValue: UInt8
  public init(rawValue: UInt8) { self.rawValue = rawValue }

  public static let leftControl = KeyModifiers(rawValue: 0x01)
  public static let leftShift = KeyModifiers(rawValue: 0x02)
  public static let leftOption = KeyModifiers(rawValue: 0x04)
  public static let leftCommand = KeyModifiers(rawValue: 0x08)
  public static let rightControl = KeyModifiers(rawValue: 0x10)
  public static let rightShift = KeyModifiers(rawValue: 0x20)
  public static let rightOption = KeyModifiers(rawValue: 0x40)
  public static let rightCommand = KeyModifiers(rawValue: 0x80)

  public var displayName: String {
    var parts: [String] = []
    if contains(.leftControl) || contains(.rightControl) { parts.append("⌃") }
    if contains(.leftOption) || contains(.rightOption) { parts.append("⌥") }
    if contains(.leftShift) || contains(.rightShift) { parts.append("⇧") }
    if contains(.leftCommand) || contains(.rightCommand) { parts.append("⌘") }
    return parts.joined()
  }
}

public enum ButtonAction: Codable, Hashable, Sendable {
  case disabled
  case mouseButton(MouseButtonCode)
  case keyboard(modifiers: KeyModifiers, keyCode: UInt8)
  case media(MediaKeyCode)
  case dpiAction(DPIActionCode)
  case macro(slot: UInt8, repeatCount: UInt8)
  case scrollUp
  case scrollDown

  private enum Class {
    static let disabled: UInt8 = 0x00
    static let mouse: UInt8 = 0x11
    static let keyboard: UInt8 = 0x21
    static let media: UInt8 = 0x22
    static let dpi: UInt8 = 0x41
    static let scroll: UInt8 = 0x12
    static let macro: UInt8 = 0x50
  }

  public var encoded: [UInt8] {
    switch self {
    case .disabled:
      return [Class.disabled, 0x00, 0x00, 0x00]
    case .mouseButton(let code):
      return [Class.mouse, code.rawValue, 0x00, 0x00]
    case .keyboard(let mods, let key):
      return [Class.keyboard, mods.rawValue, key, 0x00]
    case .media(let code):
      return [Class.media, code.rawValue, 0x00, 0x00]
    case .dpiAction(let code):
      return [Class.dpi, code.rawValue, 0x00, 0x00]
    case .scrollUp:
      return [Class.scroll, 0x01, 0x00, 0x00]
    case .scrollDown:
      return [Class.scroll, 0xFF, 0x00, 0x00]
    case .macro(let slot, let count):
      return [Class.macro, slot, count, 0x00]
    }
  }

  public init(encoded bytes: ArraySlice<UInt8>) {
    let b = Array(bytes)
    guard b.count >= 4 else {
      self = .disabled
      return
    }
    switch b[0] {
    case Class.mouse:
      self = MouseButtonCode(rawValue: b[1]).map { ButtonAction.mouseButton($0) } ?? .disabled
    case Class.keyboard:
      self = .keyboard(modifiers: KeyModifiers(rawValue: b[1]), keyCode: b[2])
    case Class.media:
      self = MediaKeyCode(rawValue: b[1]).map { ButtonAction.media($0) } ?? .disabled
    case Class.dpi:
      self = DPIActionCode(rawValue: b[1]).map { ButtonAction.dpiAction($0) } ?? .disabled
    case Class.scroll:
      self = b[1] == 0xFF ? .scrollDown : .scrollUp
    case Class.macro:
      self = .macro(slot: b[1], repeatCount: b[2])
    default:
      self = .disabled
    }
  }

  public var displayName: String {
    switch self {
    case .disabled: return "Disabled"
    case .mouseButton(let c): return c.displayName
    case .keyboard(let m, let k): return m.displayName + HIDKeyboard.name(for: k)
    case .media(let c): return c.displayName
    case .dpiAction(let c): return c.displayName
    case .scrollUp: return "Scroll Up"
    case .scrollDown: return "Scroll Down"
    case .macro(let slot, let count):
      return count > 1 ? "Macro \(slot + 1) (×\(count))" : "Macro \(slot + 1)"
    }
  }
}

public enum HIDKeyboard {
  public static let usages: [(code: UInt8, name: String)] = {
    var t: [(UInt8, String)] = []
    for i in 0..<26 {
      t.append((UInt8(0x04 + i), String(UnicodeScalar(UInt8(65 + i)))))
    }
    for i in 0..<9 {
      t.append((UInt8(0x1E + i), String(i + 1)))
    }
    t.append((0x27, "0"))
    t += [
      (0x28, "Return"), (0x29, "Escape"), (0x2A, "Delete"), (0x2B, "Tab"),
      (0x2C, "Space"), (0x2D, "-"), (0x2E, "="), (0x2F, "["), (0x30, "]"),
      (0x31, "\\"), (0x33, ";"), (0x34, "'"), (0x35, "`"), (0x36, ","),
      (0x37, "."), (0x38, "/"), (0x39, "Caps Lock"),
    ]
    for i in 0..<12 { t.append((UInt8(0x3A + i), "F\(i + 1)")) }
    t += [
      (0x49, "Insert"), (0x4A, "Home"), (0x4B, "Page Up"),
      (0x4C, "Forward Delete"), (0x4D, "End"), (0x4E, "Page Down"),
      (0x4F, "→"), (0x50, "←"), (0x51, "↓"), (0x52, "↑"),
    ]
    return t
  }()

  private static let lookup: [UInt8: String] = Dictionary(
    usages.map { ($0.code, $0.name) }, uniquingKeysWith: { a, _ in a })

  public static func name(for code: UInt8) -> String {
    lookup[code] ?? String(format: "0x%02X", code)
  }
}
