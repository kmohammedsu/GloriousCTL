import XCTest

@testable import GloriousCore

final class WriteFramingTests: XCTestCase {

  func testDataLengthMatchesTheVendorConstants() {
    XCTAssertEqual(ConfigBlock.settings.dataLength, 0x7B)
    XCTAssertEqual(ConfigBlock.buttons.dataLength, 0x50)
  }

  func testDataLengthIsBlockLengthMinusHeader() {
    for block in ConfigBlock.allCases {
      XCTAssertEqual(block.dataLength, block.length - ConfigBlock.headerSize)
    }
  }

  func testWriteBufferCarriesTheLengthByteTheDeviceRequires() {
    let config = Fixtures.config
    for block in ConfigBlock.allCases {
      let buffer = config.bufferForWrite(block)
      XCTAssertEqual(
        buffer[ConfigLayout.blockDataLength], UInt8(block.dataLength),
        "\(block) must declare its payload length on write")
    }
  }

  func testTheDeviceReturnsZeroWhereTheWriteMustCarryALength() {
    XCTAssertEqual(Fixtures.settingsBlock[ConfigLayout.blockDataLength], 0)
    XCTAssertEqual(Fixtures.buttonsBlock[ConfigLayout.blockDataLength], 0)
  }

  func testWriteBufferIsSentAtTheFullDeclaredReportSize() {
    for block in ConfigBlock.allCases {
      XCTAssertEqual(
        Fixtures.config.bufferForWrite(block).count,
        DeviceProtocol.configReportSize,
        "the vendor software always writes 520 bytes")
    }
  }

  func testPaddingBeyondTheBlockIsZero() {
    let buffer = Fixtures.config.bufferForWrite(.buttons)
    for offset in ConfigBlock.buttons.length..<buffer.count {
      XCTAssertEqual(buffer[offset], 0, "padding at 0x\(String(offset, radix: 16)) must be zero")
    }
  }

  func testHeaderIdentifiesTheBlockBeingWritten() {
    XCTAssertEqual(Fixtures.config.bufferForWrite(.settings)[ConfigLayout.blockCommand], 0x11)
    XCTAssertEqual(Fixtures.config.bufferForWrite(.buttons)[ConfigLayout.blockCommand], 0x12)
  }

  func testConfigDataStartsAfterTheEightByteHeader() {
    let buffer = Fixtures.config.bufferForWrite(.settings)
    XCTAssertEqual(buffer[ConfigBlock.headerSize], Fixtures.settingsBlock[ConfigBlock.headerSize])
    XCTAssertEqual(buffer[ConfigLayout.dpiValues], ConfigLayout.encodeDPI(400))
  }

  func testEditsSurviveIntoTheWriteBuffer() {
    var config = Fixtures.config
    config.setDPI(1200, atStage: 0)
    let buffer = config.bufferForWrite(.settings)
    XCTAssertEqual(buffer[ConfigLayout.dpiValues], ConfigLayout.encodeDPI(1200))
    XCTAssertEqual(buffer[ConfigLayout.blockDataLength], 0x7B, "length must still be set")
  }
}
