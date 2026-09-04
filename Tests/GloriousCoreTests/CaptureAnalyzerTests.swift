import XCTest

@testable import GloriousCore

final class CaptureAnalyzerTests: XCTestCase {

  private func packet(
    frame: Int, bRequest: Int, wValue: Int, wLength: Int,
    bmRequestType: Int, data: String?
  ) -> [String: Any] {
    var setup: [String: Any] = [
      "usb.setup.bRequest": "\(bRequest)",
      "usb.setup.wValue": String(format: "0x%04x", wValue),
      "usb.setup.wLength": "\(wLength)",
      "usb.bmRequestType": String(format: "0x%02x", bmRequestType),
    ]
    if let data { setup["usbhid.data"] = data }
    return [
      "_source": [
        "layers": [
          "frame": ["frame.number": "\(frame)"],
          "usb": ["Setup Data": setup],
        ]
      ]
    ]
  }

  private func json(_ packets: [[String: Any]]) throws -> Data {
    try JSONSerialization.data(withJSONObject: packets)
  }

  func testExtractsASetReportOnTheCommandChannel() throws {
    let data = try json([
      packet(
        frame: 7, bRequest: 0x09, wValue: 0x0305,
        wLength: 6, bmRequestType: 0x21,
        data: "05:11:00:00:00:00")
    ])
    let transfers = try CaptureAnalyzer.transfers(fromWiresharkJSON: data)
    XCTAssertEqual(transfers.count, 1)
    XCTAssertEqual(transfers[0].frame, 7)
    XCTAssertEqual(transfers[0].direction, .hostToDevice)
    XCTAssertEqual(transfers[0].reportType, .feature)
    XCTAssertEqual(transfers[0].reportID, 0x05)
    XCTAssertEqual(transfers[0].data.prefix(2), [0x05, 0x11])
  }

  func testExtractsAGetReportAsDeviceToHost() throws {
    let data = try json([
      packet(
        frame: 9, bRequest: 0x01, wValue: 0x0304,
        wLength: 520, bmRequestType: 0xA1,
        data: "04:11:00:00")
    ])
    let transfers = try CaptureAnalyzer.transfers(fromWiresharkJSON: data)
    XCTAssertEqual(transfers[0].direction, .deviceToHost)
    XCTAssertEqual(transfers[0].reportID, 0x04)
    XCTAssertEqual(transfers[0].declaredLength, 520)
  }

  func testIgnoresTrafficThatIsNotAReportTransfer() throws {
    let data = try json([
      packet(
        frame: 1, bRequest: 0x06, wValue: 0x0100,
        wLength: 18, bmRequestType: 0x80, data: nil)
    ])
    XCTAssertTrue(try CaptureAnalyzer.transfers(fromWiresharkJSON: data).isEmpty)
  }

  func testParsesHexWithAndWithoutSeparators() {
    XCTAssertEqual(CaptureAnalyzer.hexBytes("04:11:00"), [0x04, 0x11, 0x00])
    XCTAssertEqual(CaptureAnalyzer.hexBytes("041100"), [0x04, 0x11, 0x00])
    XCTAssertEqual(CaptureAnalyzer.hexBytes("04 11 00"), [0x04, 0x11, 0x00])
    XCTAssertNil(CaptureAnalyzer.hexBytes("0411 0"))
    XCTAssertNil(CaptureAnalyzer.hexBytes("zz"))
  }

  func testParsesDecimalAndHexNumberStrings() {
    XCTAssertEqual(CaptureAnalyzer.parseNumber("9"), 9)
    XCTAssertEqual(CaptureAnalyzer.parseNumber("0x21"), 0x21)
    XCTAssertEqual(CaptureAnalyzer.parseNumber(42), 42)
    XCTAssertNil(CaptureAnalyzer.parseNumber("not a number"))
  }

  func testFindsFieldsRegardlessOfHowDeeplyTheyAreNested() {
    let nested: [String: Any] = ["a": ["b": ["c": ["usb.setup.wLength": "131"]]]]
    XCTAssertEqual(CaptureAnalyzer.intValue(in: nested, keySuffix: "setup.wLength"), 131)
  }

  func testReportNamesCommandBytesTheAppDoesNotUse() throws {
    let data = try json([
      packet(
        frame: 1, bRequest: 0x09, wValue: 0x0305, wLength: 6,
        bmRequestType: 0x21, data: "05:11:00:00:00:00"),
      packet(
        frame: 2, bRequest: 0x09, wValue: 0x0305, wLength: 6,
        bmRequestType: 0x21, data: "05:aa:00:00:00:00"),
    ])
    let report = CaptureAnalyzer.report(
      try CaptureAnalyzer.transfers(fromWiresharkJSON: data))
    XCTAssertTrue(report.contains("NOT USED BY THIS APP"))
    XCTAssertTrue(report.contains("0xAA"))
    XCTAssertTrue(report.contains("(known latch)"))
  }

  func testReportFlagsHeaderBytesThatDifferBetweenReadAndWrite() throws {
    let data = try json([
      packet(
        frame: 1, bRequest: 0x01, wValue: 0x0304, wLength: 520,
        bmRequestType: 0xA1, data: "04:11:00:00:00:00:00:00:63"),
      packet(
        frame: 2, bRequest: 0x09, wValue: 0x0304, wLength: 131,
        bmRequestType: 0x21, data: "04:11:7b:00:5a:00:00:00:62"),
    ])
    let report = CaptureAnalyzer.report(
      try CaptureAnalyzer.transfers(fromWiresharkJSON: data))
    XCTAssertTrue(report.contains("HEADER"), "header differences must be called out")
    XCTAssertTrue(report.contains("0x02"))
    XCTAssertTrue(
      report.contains("that this app is not setting")
        || report.contains("this app is not setting"))
  }

  func testReportExplainsAnEmptyCapture() throws {
    let report = CaptureAnalyzer.report([])
    XCTAssertTrue(report.contains("No feature-report traffic"))
  }

  func testRejectsAFileThatIsNotAPacketArray() throws {
    let data = try JSONSerialization.data(withJSONObject: ["not": "an array"])
    XCTAssertThrowsError(try CaptureAnalyzer.transfers(fromWiresharkJSON: data))
  }
}
