import XCTest

@testable import GloriousCore

final class WriteSafetyTests: XCTestCase {

  func testEditingOneFieldChangesExactlyOneByte() {
    let original = Fixtures.config
    var edited = original
    edited.setDPI(1200, atStage: 2)

    let changed = edited.changedOffsets(comparedTo: original, in: .settings)
    XCTAssertEqual(changed, [ConfigLayout.dpiValues + 2])
    XCTAssertTrue(
      edited.changedOffsets(comparedTo: original, in: .buttons).isEmpty,
      "editing DPI must not touch the button block")
  }

  func testEditingAColourChangesExactlyThreeBytes() {
    let original = Fixtures.config
    var edited = original
    edited.setColor(RGBColor(red: 1, green: 2, blue: 3), atStage: 0)
    XCTAssertEqual(
      edited.changedOffsets(comparedTo: original, in: .settings),
      [
        ConfigLayout.dpiColors, ConfigLayout.dpiColors + 1,
        ConfigLayout.dpiColors + 2,
      ])
  }

  func testUnknownRegionIsPreservedByteForByte() {
    let original = Fixtures.config
    var edited = original
    edited.lightingEffect = .rave
    edited.brightness = .low
    edited.setDPI(6400, atStage: 5)
    edited.setAction(.media(.mute), for: .forward)

    let claimed: Set<Int> = Set(
      [ConfigLayout.lightingEffect, ConfigLayout.raveMode]
        + (0..<ConfigLayout.dpiStageCountMax).map { ConfigLayout.dpiValues + $0 })
    let before = original.raw(.settings)
    let after = edited.raw(.settings)
    for offset in 0..<before.count where !claimed.contains(offset) {
      XCTAssertEqual(
        before[offset], after[offset],
        String(format: "byte 0x%02X was modified but is not a mapped field", offset))
    }
  }

  func testWriteBufferRestoresTheReportIDAndCommand() {
    var config = Fixtures.config
    config.lightingEffect = .wave

    let settings = config.bufferForWrite(.settings)
    XCTAssertEqual(settings[ConfigLayout.reportID], DeviceProtocol.configReportID)
    XCTAssertEqual(settings[ConfigLayout.blockCommand], ConfigBlock.settings.rawValue)

    let buttons = config.bufferForWrite(.buttons)
    XCTAssertEqual(buttons[ConfigLayout.blockCommand], ConfigBlock.buttons.rawValue)

    for block in ConfigBlock.allCases {
      XCTAssertEqual(
        config.bufferForWrite(block).count,
        DeviceProtocol.configReportSize)
    }
  }

  func testShortReadsArePaddedSoOffsetsStayStable() {
    let truncated = Array(Fixtures.settingsBlock.prefix(60))
    let config = MouseConfig(settings: truncated, buttons: Fixtures.buttonsBlock)
    XCTAssertEqual(config.raw(.settings).count, ConfigBlock.settings.length)
    XCTAssertEqual(config.dpi(atStage: 0), 400, "fields before the cut must still decode")
  }

  func testRoundTripThroughRawBytesIsLossless() {
    let config = Fixtures.config
    let restored = MouseConfig(
      settings: config.raw(.settings),
      buttons: config.raw(.buttons))
    XCTAssertEqual(config, restored)
  }
}
