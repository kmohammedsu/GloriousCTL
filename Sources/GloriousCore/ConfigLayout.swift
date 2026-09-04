import Foundation

public enum ConfigBlock: UInt8, CaseIterable, Sendable {
  case settings = 0x11
  case buttons = 0x12

  public var length: Int {
    switch self {
    case .settings: return 131
    case .buttons: return 88
    }
  }

  public var dataLength: Int { length - Self.headerSize }

  public static let headerSize = 8

  public var command: [UInt8] { [rawValue, 0x00, 0x00, 0x00, 0x00] }
}

public enum ConfigLayout {

  public static let reportID = 0x00
  public static let blockCommand = 0x01

  public static let blockSubIndex = 0x02

  public static let blockDataLength = 0x03

  public static let unknown08 = 0x08

  public static let dpiStageCount = 0x09

  public static let activeDPIStage = 0x0A

  public static let unknown0B = 0x0B
  public static let unknown0C = 0x0C

  public static let dpiValues = 0x0D
  public static let dpiStageCountMax = 6
  public static let dpiBytesPerStage = 1

  public static let dpiSecondaryAxis = 0x13

  public static let dpiColors = 0x1D
  public static let dpiColorBytesPerStage = 3

  public static let lightingEffect = 0x35

  public static let lightingBrightnessSpeed = 0x36

  public static let gloriousMode = 0x36
  public static let gloriousDirection = 0x37
  public static let singleColorMode = 0x38
  public static let singleColor = 0x39
  public static let breathingSevenMode = 0x3C
  public static let tailMode = 0x53
  public static let seamlessBreathingMode = 0x54
  public static let constantRGBMode = 0x55
  public static let raveMode = 0x74
  public static let randomMode = 0x7B
  public static let waveMode = 0x7C
  public static let singleBreathingMode = 0x7D
  public static let singleBreathingColor = 0x7E

  public static let effectParameters = 0x36

  public static let buttonMap = 0x08
  public static let buttonEntrySize = 4
  public static let buttonEntryCount = 20

  public static func encodeDPI(_ dpi: Int) -> UInt8 {
    let clamped = max(100, min(dpi, 12000))
    return UInt8(max(0, min(255, clamped / 100 - 1)))
  }

  public static func decodeDPI(_ raw: UInt8) -> Int { (Int(raw) + 1) * 100 }
}

extension ConfigBlock {
  public var filename: String {
    switch self {
    case .settings: return "settings"
    case .buttons: return "buttons"
    }
  }

  public var displayName: String {
    switch self {
    case .settings: return "Settings"
    case .buttons: return "Buttons"
    }
  }
}
