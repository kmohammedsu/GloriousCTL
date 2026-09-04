import Foundation

public enum DeviceProtocol {

  public static let configReportID: UInt8 = 0x04
  public static let configReportSize = 520
  public static let configPayloadSize = 519

  public static let commandReportID: UInt8 = 0x05
  public static let commandReportSize = 6
  public static let commandPayloadSize = 5

  public static let eventReportID: UInt8 = 0x07
  public static let eventReportSize = 8

  public enum Command {
    public static let latchConfigForRead: [UInt8] = [0x11, 0x00, 0x00, 0x00, 0x00]

    public static func latchMacroForRead(slot: UInt8) -> [UInt8] {
      [0x21, slot, 0x00, 0x00, 0x00]
    }

    public static let latchDeviceInfo: [UInt8] = [0x12, 0x00, 0x00, 0x00, 0x00]
  }

  public enum Model: Int, CaseIterable, Sendable {
    case modelO = 0x0036
    case modelOAlt = 0x0033
    case modelDAlt = 0x0039

    public var displayName: String {
      switch self {
      case .modelO: return "Glorious Model O / O-"
      case .modelOAlt: return "Glorious Model O (alt revision)"
      case .modelDAlt: return "Glorious Model D / D-"
      }
    }

    public var buttonCount: Int { 6 }

    public var maxDPI: Int { 12000 }
  }
}
