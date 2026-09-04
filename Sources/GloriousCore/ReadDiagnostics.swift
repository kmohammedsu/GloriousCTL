import Foundation
import IOKit

public struct ReadDiagnostics {

  public struct Attempt {
    public let name: String
    public let detail: String
    public let status: IOReturn
    public let requested: Int
    public let actual: Int
    public let bytes: [UInt8]

    public var succeeded: Bool { status == kIOReturnSuccess }
  }

  public let attempts: [Attempt]
  public let capturedAt = Date()

  public init(transport: HIDTransport) {
    var attempts: [Attempt] = []

    func latch(_ payload: [UInt8]) {
      try? transport.setFeatureReport(id: DeviceProtocol.commandReportID, payload: payload)
    }

    func read(_ name: String, _ detail: String, id: UInt8, length: Int) {
      let result = transport.rawGetFeatureReport(id: id, length: length)
      attempts.append(
        Attempt(
          name: name, detail: detail, status: result.status,
          requested: length, actual: result.actual,
          bytes: Array(result.buffer.prefix(max(0, result.actual)))))
    }

    read(
      "cold-read", "GetReport(0x04, 520) with no preceding command",
      id: DeviceProtocol.configReportID, length: DeviceProtocol.configReportSize)

    latch(DeviceProtocol.Command.latchConfigForRead)
    Thread.sleep(forTimeInterval: 0.02)
    read(
      "latch-20ms", "cmd 0x05 [11], wait 20 ms, GetReport(0x04, 520)",
      id: DeviceProtocol.configReportID, length: DeviceProtocol.configReportSize)

    latch(DeviceProtocol.Command.latchConfigForRead)
    Thread.sleep(forTimeInterval: 0.20)
    read(
      "latch-200ms", "cmd 0x05 [11], wait 200 ms, GetReport(0x04, 520)",
      id: DeviceProtocol.configReportID, length: DeviceProtocol.configReportSize)

    latch(DeviceProtocol.Command.latchConfigForRead)
    Thread.sleep(forTimeInterval: 0.02)
    read(
      "double-read-a", "cmd 0x05 [11], first of two consecutive reads",
      id: DeviceProtocol.configReportID, length: DeviceProtocol.configReportSize)
    read(
      "double-read-b", "immediately repeated read, no new command",
      id: DeviceProtocol.configReportID, length: DeviceProtocol.configReportSize)

    latch(DeviceProtocol.Command.latchConfigForRead)
    Thread.sleep(forTimeInterval: 0.02)
    read(
      "exact-131", "cmd 0x05 [11], GetReport(0x04, 131)",
      id: DeviceProtocol.configReportID, length: 131)

    latch(DeviceProtocol.Command.latchConfigForRead)
    Thread.sleep(forTimeInterval: 0.02)
    read(
      "chunk-64", "cmd 0x05 [11], GetReport(0x04, 64)",
      id: DeviceProtocol.configReportID, length: 64)

    latch(DeviceProtocol.Command.latchConfigForRead)
    Thread.sleep(forTimeInterval: 0.02)
    read(
      "cmd-readback", "cmd 0x05 [11], then GetReport(0x05, 6)",
      id: DeviceProtocol.commandReportID, length: DeviceProtocol.commandReportSize)

    latch(DeviceProtocol.Command.latchDeviceInfo)
    Thread.sleep(forTimeInterval: 0.02)
    read(
      "device-info", "cmd 0x05 [12], GetReport(0x04, 520)",
      id: DeviceProtocol.configReportID, length: DeviceProtocol.configReportSize)

    latch(DeviceProtocol.Command.latchConfigForRead)
    Thread.sleep(forTimeInterval: 0.02)

    self.attempts = attempts
  }

  public func report(interfaces: [HIDInterfaceInfo], descriptor: Data?) -> String {
    var text = "GloriousCTL — config read diagnostics\n"
    text += "Captured: \(ISO8601DateFormatter().string(from: capturedAt))\n\n"

    text += "HID interfaces:\n"
    for info in interfaces {
      text += String(
        format: "  pid=0x%04X usagePage=0x%02X usage=0x%02X feature=%d input=%d %@\n",
        info.productID, info.usagePage, info.usage,
        info.maxFeatureReportSize, info.maxInputReportSize, info.product)
    }

    if let descriptor {
      text += "\nReport descriptor (\(descriptor.count) bytes):\n  "
      text += descriptor.map { String(format: "%02X", $0) }.joined(separator: " ")
      text += "\n"
    }

    text += "\n" + String(repeating: "=", count: 72) + "\n"
    for attempt in attempts {
      text += "\n[\(attempt.name)] \(attempt.detail)\n"
      text += "  status    : \(IOReturnNames.describe(attempt.status))\n"
      text += "  requested : \(attempt.requested) bytes\n"
      text += "  returned  : \(attempt.actual) bytes\n"
      if !attempt.bytes.isEmpty {
        text += "  data:\n"
        for row in stride(from: 0, to: attempt.bytes.count, by: 16) {
          let end = min(row + 16, attempt.bytes.count)
          let slice = attempt.bytes[row..<end]
          let hex = slice.map { String(format: "%02X", $0) }.joined(separator: " ")
          let ascii = slice.map { $0 >= 32 && $0 < 127 ? String(UnicodeScalar($0)) : "." }.joined()
          text += String(format: "    %04X  %-47@  %@\n", row, hex as NSString, ascii)
        }
      }
    }
    return text
  }
}
