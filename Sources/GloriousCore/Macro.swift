import Foundation

public struct MacroEvent: Codable, Hashable, Identifiable, Sendable {
  public enum Kind: String, Codable, Sendable {
    case keyDown, keyUp, mouseDown, mouseUp, delay
  }

  public var id: UUID
  public var kind: Kind
  public var code: UInt8
  public var delayMilliseconds: UInt16

  public init(id: UUID = UUID(), kind: Kind, code: UInt8 = 0, delayMilliseconds: UInt16 = 0) {
    self.id = id
    self.kind = kind
    self.code = code
    self.delayMilliseconds = delayMilliseconds
  }

  public var displayName: String {
    switch kind {
    case .keyDown: return "↓ \(HIDKeyboard.name(for: code))"
    case .keyUp: return "↑ \(HIDKeyboard.name(for: code))"
    case .mouseDown: return "↓ \(MouseButtonCode(rawValue: code)?.displayName ?? "Button")"
    case .mouseUp: return "↑ \(MouseButtonCode(rawValue: code)?.displayName ?? "Button")"
    case .delay: return "Wait \(delayMilliseconds) ms"
    }
  }
}

public struct Macro: Codable, Hashable, Identifiable, Sendable {
  public var id: UUID
  public var name: String
  public var slot: UInt8
  public var events: [MacroEvent]
  public var repeatCount: UInt8

  public init(
    id: UUID = UUID(), name: String, slot: UInt8,
    events: [MacroEvent] = [], repeatCount: UInt8 = 1
  ) {
    self.id = id
    self.name = name
    self.slot = slot
    self.events = events
    self.repeatCount = repeatCount
  }

  public static let maxEvents = 168

  public var isWithinDeviceLimits: Bool { events.count <= Self.maxEvents }

  public var totalDurationMilliseconds: Int {
    events.reduce(0) { $0 + Int($1.delayMilliseconds) }
  }

  public func encoded() -> [UInt8] {
    var out: [UInt8] = []
    for event in events.prefix(Self.maxEvents) {
      let flags: UInt8
      switch event.kind {
      case .keyDown: flags = 0x81
      case .keyUp: flags = 0x01
      case .mouseDown: flags = 0x82
      case .mouseUp: flags = 0x02
      case .delay: flags = 0x04
      }
      out += [
        flags, event.code,
        UInt8(event.delayMilliseconds & 0xFF),
        UInt8((event.delayMilliseconds >> 8) & 0xFF),
      ]
    }
    return out
  }

  public static func decode(_ bytes: [UInt8], slot: UInt8, name: String) -> Macro {
    var events: [MacroEvent] = []
    var index = 0
    while index + 3 < bytes.count {
      let flags = bytes[index]
      if flags == 0 { break }
      let code = bytes[index + 1]
      let delay = UInt16(bytes[index + 2]) | (UInt16(bytes[index + 3]) << 8)
      let kind: MacroEvent.Kind
      switch flags {
      case 0x81: kind = .keyDown
      case 0x01: kind = .keyUp
      case 0x82: kind = .mouseDown
      case 0x02: kind = .mouseUp
      default: kind = .delay
      }
      events.append(MacroEvent(kind: kind, code: code, delayMilliseconds: delay))
      index += 4
    }
    return Macro(name: name, slot: slot, events: events)
  }
}
