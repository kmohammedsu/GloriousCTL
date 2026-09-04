import Foundation

public enum PollingRate: UInt8, CaseIterable, Codable, Identifiable, Sendable {
  case hz125 = 1
  case hz250 = 2
  case hz500 = 4
  case hz1000 = 8

  public var id: UInt8 { rawValue }
  public var hz: Int {
    switch self {
    case .hz125: return 125
    case .hz250: return 250
    case .hz500: return 500
    case .hz1000: return 1000
    }
  }
  public var displayName: String { "\(hz) Hz" }
  public var intervalMilliseconds: Double { 1000.0 / Double(hz) }
}

public enum LightingEffect: UInt8, CaseIterable, Codable, Identifiable, Sendable {
  case off = 0x00
  case glorious = 0x01
  case singleColor = 0x02
  case breathing = 0x03
  case tail = 0x04
  case seamlessBreathing = 0x05
  case constantRGB = 0x06
  case rave = 0x07
  case random = 0x08
  case wave = 0x09
  case singleBreathing = 0x0A

  public var id: UInt8 { rawValue }

  public var displayName: String {
    switch self {
    case .off: return "Off"
    case .glorious: return "Glorious Mode"
    case .singleColor: return "Single Color"
    case .breathing: return "Breathing"
    case .tail: return "Tail"
    case .seamlessBreathing: return "Seamless Breathing"
    case .constantRGB: return "Constant RGB"
    case .rave: return "Rave"
    case .random: return "Random"
    case .wave: return "Wave"
    case .singleBreathing: return "Single Color Breathing"
    }
  }

  public var colorCount: Int {
    switch self {
    case .off, .glorious, .random, .wave, .seamlessBreathing: return 0
    case .singleColor, .singleBreathing, .tail: return 1
    case .breathing, .constantRGB: return 6
    case .rave: return 2
    }
  }

  public var supportsBrightness: Bool { self != .off }
  public var supportsSpeed: Bool {
    switch self {
    case .off, .singleColor, .constantRGB: return false
    default: return true
    }
  }
}

public enum Brightness: UInt8, CaseIterable, Codable, Identifiable, Sendable {
  case off = 0
  case low = 1
  case medium = 2
  case high = 3
  case max = 4
  public var id: UInt8 { rawValue }
  public var displayName: String {
    switch self {
    case .off: return "Off"
    case .low: return "25%"
    case .medium: return "50%"
    case .high: return "75%"
    case .max: return "100%"
    }
  }
  public var percent: Int { Int(rawValue) * 25 }
}

public enum EffectSpeed: UInt8, CaseIterable, Codable, Identifiable, Sendable {
  case slowest = 0
  case slow = 1
  case medium = 2
  case fast = 3
  public var id: UInt8 { rawValue }
  public var displayName: String {
    switch self {
    case .slowest: return "Slowest"
    case .slow: return "Slow"
    case .medium: return "Medium"
    case .fast: return "Fast"
    }
  }
}

public struct RGBColor: Codable, Hashable, Sendable {
  public var red: UInt8
  public var green: UInt8
  public var blue: UInt8

  public init(red: UInt8, green: UInt8, blue: UInt8) {
    self.red = red
    self.green = green
    self.blue = blue
  }

  public static let white = RGBColor(red: 255, green: 255, blue: 255)
  public static let black = RGBColor(red: 0, green: 0, blue: 0)

  public var bytes: [UInt8] { [red, green, blue] }

  public init(bytes: ArraySlice<UInt8>) {
    let a = Array(bytes)
    self.red = a.count > 0 ? a[0] : 0
    self.green = a.count > 1 ? a[1] : 0
    self.blue = a.count > 2 ? a[2] : 0
  }

  public var hexString: String { String(format: "#%02X%02X%02X", red, green, blue) }

  public init?(hexString: String) {
    var s = hexString.trimmingCharacters(in: .whitespaces)
    if s.hasPrefix("#") { s.removeFirst() }
    guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
    self.red = UInt8((v >> 16) & 0xFF)
    self.green = UInt8((v >> 8) & 0xFF)
    self.blue = UInt8(v & 0xFF)
  }
}

public enum LiftOffDistance: UInt8, CaseIterable, Codable, Identifiable, Sendable {
  case low = 1
  case medium = 2
  case high = 3
  public var id: UInt8 { rawValue }
  public var displayName: String {
    switch self {
    case .low: return "1 mm (low)"
    case .medium: return "2 mm (medium)"
    case .high: return "3 mm (high)"
    }
  }
}

public enum DebounceTime: UInt8, CaseIterable, Codable, Identifiable, Sendable {
  case ms2 = 1
  case ms4 = 2
  case ms6 = 3
  case ms8 = 4
  case ms10 = 5
  case
    ms12 = 6
  case ms14 = 7
  case ms16 = 8
  case ms18 = 9
  case ms20 = 10
  public var id: UInt8 { rawValue }
  public var milliseconds: Int { Int(rawValue) * 2 }
  public var displayName: String { "\(milliseconds) ms" }
}
