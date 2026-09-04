import Foundation

public struct HIDTransfer: Equatable, Sendable {
  public enum Direction: String, Sendable {
    case hostToDevice = "SET_REPORT"
    case deviceToHost = "GET_REPORT"
    case other = "OTHER"
  }

  public enum ReportType: String, Sendable {
    case feature = "Feature"
    case output = "Output"
    case input = "Input"
    case unknown = "?"
  }

  public let frame: Int
  public let direction: Direction
  public let reportType: ReportType
  public let reportID: UInt8
  public let declaredLength: Int
  public let data: [UInt8]

  public init(
    frame: Int, direction: Direction, reportType: ReportType,
    reportID: UInt8, declaredLength: Int, data: [UInt8]
  ) {
    self.frame = frame
    self.direction = direction
    self.reportType = reportType
    self.reportID = reportID
    self.declaredLength = declaredLength
    self.data = data
  }
}

public enum CaptureAnalyzer {

  private static let setReport: Int = 0x09
  private static let getReport: Int = 0x01

  public static func transfers(fromWiresharkJSON json: Data) throws -> [HIDTransfer] {
    guard let root = try JSONSerialization.jsonObject(with: json) as? [Any] else {
      throw AnalyzerError.notAPacketArray
    }
    return root.enumerated().compactMap { index, packet in
      transfer(from: packet, fallbackFrame: index + 1)
    }
  }

  private static func transfer(from packet: Any, fallbackFrame: Int) -> HIDTransfer? {
    guard let object = packet as? [String: Any] else { return nil }

    guard let request = intValue(in: object, keySuffix: "setup.bRequest"),
      request == setReport || request == getReport
    else { return nil }

    let wValue = intValue(in: object, keySuffix: "setup.wValue") ?? 0
    let reportType: HIDTransfer.ReportType
    switch (wValue >> 8) & 0xFF {
    case 0x01: reportType = .input
    case 0x02: reportType = .output
    case 0x03: reportType = .feature
    default: reportType = .unknown
    }

    let bmRequestType = intValue(in: object, keySuffix: "bmRequestType") ?? 0
    let direction: HIDTransfer.Direction =
      (bmRequestType & 0x80) != 0
      ? .deviceToHost : .hostToDevice

    return HIDTransfer(
      frame: intValue(in: object, keySuffix: "frame.number") ?? fallbackFrame,
      direction: request == getReport ? .deviceToHost : direction,
      reportType: reportType,
      reportID: UInt8(wValue & 0xFF),
      declaredLength: intValue(in: object, keySuffix: "setup.wLength") ?? 0,
      data: payload(in: object))
  }

  static func intValue(in object: Any, keySuffix: String) -> Int? {
    if let dictionary = object as? [String: Any] {
      for (key, value) in dictionary {
        if key.hasSuffix(keySuffix), let parsed = parseNumber(value) { return parsed }
      }
      for value in dictionary.values {
        if let found = intValue(in: value, keySuffix: keySuffix) { return found }
      }
    } else if let array = object as? [Any] {
      for value in array {
        if let found = intValue(in: value, keySuffix: keySuffix) { return found }
      }
    }
    return nil
  }

  static func parseNumber(_ value: Any) -> Int? {
    if let number = value as? Int { return number }
    if let number = value as? NSNumber { return number.intValue }
    guard var text = value as? String else { return nil }
    text = text.trimmingCharacters(in: .whitespaces)
    if text.lowercased().hasPrefix("0x") {
      return Int(text.dropFirst(2), radix: 16)
    }
    return Int(text)
  }

  static func payload(in object: Any) -> [UInt8] {
    for suffix in ["usbhid.data", "usb.capdata", "usb.data_fragment", "data.data"] {
      if let hex = stringValue(in: object, keySuffix: suffix), let bytes = hexBytes(hex) {
        return bytes
      }
    }
    return []
  }

  static func stringValue(in object: Any, keySuffix: String) -> String? {
    if let dictionary = object as? [String: Any] {
      for (key, value) in dictionary {
        if key.hasSuffix(keySuffix), let text = value as? String, !text.isEmpty {
          return text
        }
      }
      for value in dictionary.values {
        if let found = stringValue(in: value, keySuffix: keySuffix) { return found }
      }
    } else if let array = object as? [Any] {
      for value in array {
        if let found = stringValue(in: value, keySuffix: keySuffix) { return found }
      }
    }
    return nil
  }

  public static func hexBytes(_ text: String) -> [UInt8]? {
    let cleaned = text.replacingOccurrences(of: ":", with: "")
      .replacingOccurrences(of: " ", with: "")
      .replacingOccurrences(of: "\n", with: "")
    guard !cleaned.isEmpty, cleaned.count % 2 == 0 else { return nil }
    var bytes: [UInt8] = []
    var index = cleaned.startIndex
    while index < cleaned.endIndex {
      let next = cleaned.index(index, offsetBy: 2)
      guard let byte = UInt8(cleaned[index..<next], radix: 16) else { return nil }
      bytes.append(byte)
      index = next
    }
    return bytes
  }

  public enum AnalyzerError: Error, LocalizedError {
    case notAPacketArray
    public var errorDescription: String? {
      "That file is not a Wireshark JSON packet export. In Wireshark use "
        + "File > Export Packet Dissections > As JSON."
    }
  }
}

extension CaptureAnalyzer {

  public static func configTraffic(_ transfers: [HIDTransfer]) -> [HIDTransfer] {
    transfers.filter {
      $0.reportType == .feature
        && ($0.reportID == DeviceProtocol.configReportID
          || $0.reportID == DeviceProtocol.commandReportID)
    }
  }

  public static func report(_ all: [HIDTransfer]) -> String {
    let traffic = configTraffic(all)
    var text = "GloriousCTL — USB capture analysis\n\n"

    guard !traffic.isEmpty else {
      return text + """
        No feature-report traffic found on reports 0x04 or 0x05.

        Check that the capture includes the mouse's device address, that the
        Glorious software actually applied a setting while capturing, and that the
        export is a JSON packet dissection rather than a summary.
        """
    }

    text += "Transcript (\(traffic.count) config transfers)\n"
    text += String(repeating: "-", count: 68) + "\n"
    for transfer in traffic {
      text += String(
        format: "#%-6d %-10@ report 0x%02X  len=%-4d  %@\n",
        transfer.frame, transfer.direction.rawValue as NSString,
        transfer.reportID, transfer.declaredLength,
        preview(transfer.data) as NSString)
    }

    let writes = traffic.filter { $0.direction == .hostToDevice }
    let blockWrites = writes.filter { $0.reportID == DeviceProtocol.configReportID }

    text += "\n" + String(repeating: "=", count: 68) + "\n"
    text += "FINDINGS\n\n"

    let commands = writes.filter { $0.reportID == DeviceProtocol.commandReportID }
    text += "Commands sent on report 0x05: \(commands.count)\n"
    var unknown: Set<UInt8> = []
    for command in commands {
      let byte =
        command.data.count > 1
        ? command.data[1]
        : (command.data.first ?? 0)
      let known = ConfigBlock(rawValue: byte) != nil
      if !known { unknown.insert(byte) }
      text += String(
        format: "  #%-6d cmd 0x%02X  %@%@\n", command.frame, byte,
        preview(command.data) as NSString,
        known ? "  (known latch)" : "  <-- NOT USED BY THIS APP")
    }
    if !unknown.isEmpty {
      text += "\n  New command bytes: "
      text += unknown.sorted().map { String(format: "0x%02X", $0) }.joined(separator: ", ")
      text += "\n  These are very likely the write-enable and/or commit steps.\n"
    }

    text += "\nBlock writes on report 0x04: \(blockWrites.count)\n"
    for write in blockWrites {
      let before = traffic.last {
        $0.frame < write.frame
          && $0.reportID == DeviceProtocol.commandReportID
          && $0.direction == .hostToDevice
      }
      let after = traffic.first {
        $0.frame > write.frame
          && $0.reportID == DeviceProtocol.commandReportID
          && $0.direction == .hostToDevice
      }
      text += String(format: "  #%-6d %d bytes\n", write.frame, write.data.count)
      text +=
        "    preceded by: "
        + (before.map {
          String(format: "cmd 0x%02X (#%d)", $0.data.count > 1 ? $0.data[1] : 0, $0.frame)
        } ?? "nothing") + "\n"
      text +=
        "    followed by: "
        + (after.map {
          String(format: "cmd 0x%02X (#%d)", $0.data.count > 1 ? $0.data[1] : 0, $0.frame)
        } ?? "nothing") + "\n"
    }

    text += "\nRead/write-back comparison\n"
    var foundComparison = false
    for write in blockWrites {
      guard
        let read = traffic.last(where: {
          $0.frame < write.frame && $0.direction == .deviceToHost
            && $0.reportID == DeviceProtocol.configReportID
            && !$0.data.isEmpty
        })
      else { continue }
      foundComparison = true

      text += String(
        format: "  read #%d (%d bytes) vs write #%d (%d bytes)\n",
        read.frame, read.data.count, write.frame, write.data.count)
      if read.data.count != write.data.count {
        text += "    LENGTH DIFFERS — the host writes a different size than it reads.\n"
      }
      let shared = min(read.data.count, write.data.count)
      let differing = (0..<shared).filter { read.data[$0] != write.data[$0] }
      if differing.isEmpty {
        text += "    no byte differences in the shared range\n"
      } else {
        text += "    \(differing.count) byte(s) differ:\n"
        for offset in differing.prefix(24) {
          let note =
            offset < ConfigBlock.headerSize
            ? "   <-- HEADER: length, checksum or sequence"
            : ""
          text += String(
            format: "      0x%02X  %02X -> %02X%@\n",
            offset, read.data[offset], write.data[offset],
            note as NSString)
        }
        if differing.count > 24 { text += "      ...\n" }
        let headerChanges = differing.filter { $0 < ConfigBlock.headerSize }
        if !headerChanges.isEmpty {
          text += "\n    The header bytes above change on write but read back as zero.\n"
          text += "    That is the field this app is not setting.\n"
        }
      }
    }
    if !foundComparison {
      text += "  No read preceding a write in this capture, so no comparison possible.\n"
    }

    return text
  }

  private static func preview(_ bytes: [UInt8], limit: Int = 16) -> String {
    guard !bytes.isEmpty else { return "(no data stage)" }
    let head = bytes.prefix(limit).map { String(format: "%02X", $0) }.joined(separator: " ")
    return bytes.count > limit ? head + " ..." : head
  }
}
