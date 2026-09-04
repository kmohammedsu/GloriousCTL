import XCTest

@testable import GloriousCore

final class WriteCheckTests: XCTestCase {

  private let before: [UInt8] = [0x04, 0x11, 0x00, 0x10, 0x20, 0x30]

  func testWriteThatFullyLandsPasses() {
    var intended = before
    intended[3] = 0x99
    let result = WriteCheck.compare(before: before, intended: intended, after: intended)
    XCTAssertTrue(result.passed)
    XCTAssertEqual(result.landed, [3])
    XCTAssertTrue(result.rejected.isEmpty)
    XCTAssertTrue(result.collateral.isEmpty)
  }

  func testDeviceKeepingTheOldValueIsReportedAsRejected() {
    var intended = before
    intended[3] = 0x99
    let result = WriteCheck.compare(before: before, intended: intended, after: before)
    XCTAssertFalse(result.passed)
    XCTAssertEqual(result.rejected, [3])
    XCTAssertTrue(result.landed.isEmpty)
  }

  func testAnUntouchedByteChangingIsReportedAsCollateral() {
    var intended = before
    intended[3] = 0x99
    var after = intended
    after[5] = 0x77
    let result = WriteCheck.compare(before: before, intended: intended, after: after)
    XCTAssertFalse(result.passed)
    XCTAssertEqual(result.landed, [3])
    XCTAssertEqual(result.collateral, [5], "a byte we never wrote changed — offset is suspect")
  }

  func testDeviceManagedHeaderBytesAreIgnored() {
    var after = before
    after[ConfigLayout.reportID] = 0x00
    after[ConfigLayout.blockCommand] = 0x00
    let result = WriteCheck.compare(before: before, intended: before, after: after)
    XCTAssertTrue(result.passed, "header bytes are the device's to manage")
  }

  func testAnIdempotentWriteIsAPassWithNothingLanded() {
    let result = WriteCheck.compare(before: before, intended: before, after: before)
    XCTAssertTrue(result.passed)
    XCTAssertTrue(result.landed.isEmpty)
    XCTAssertEqual(result.summary, "no change intended; device unchanged")
  }

  func testComparisonToleratesDifferingLengths() {
    let short = Array(before.prefix(4))
    let result = WriteCheck.compare(before: before, intended: before, after: short)
    XCTAssertTrue(result.passed)
  }

  func testSummaryNamesTheOffsetsThatFailed() {
    var intended = before
    intended[3] = 0x99
    intended[4] = 0xAA
    let result = WriteCheck.compare(before: before, intended: intended, after: before)
    XCTAssertTrue(result.summary.contains("0x03"))
    XCTAssertTrue(result.summary.contains("0x04"))
  }
}
