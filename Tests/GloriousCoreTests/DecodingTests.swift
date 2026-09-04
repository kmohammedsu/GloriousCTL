import XCTest

@testable import GloriousCore

final class DecodingTests: XCTestCase {

  func testFixturesAreTheLengthsTheDeviceReports() {
    XCTAssertEqual(Fixtures.settingsBlock.count, ConfigBlock.settings.length)
    XCTAssertEqual(Fixtures.buttonsBlock.count, ConfigBlock.buttons.length)
  }

  func testEachBlockEchoesItsLatchCommand() {
    XCTAssertEqual(
      Fixtures.settingsBlock[ConfigLayout.blockCommand],
      ConfigBlock.settings.rawValue)
    XCTAssertEqual(
      Fixtures.buttonsBlock[ConfigLayout.blockCommand],
      ConfigBlock.buttons.rawValue)
  }

  func testDPIStagesDecodeToTheDevicesActualValues() {
    let config = Fixtures.config
    XCTAssertEqual(config.dpiStageCount, 6)
    XCTAssertEqual(config.activeDPIStage, 4)
    XCTAssertEqual(
      (0..<6).map { config.dpi(atStage: $0) },
      [400, 800, 1600, 3200, 5000, 10000])
  }

  func testDPIEncodingRoundTripsAcrossTheSensorRange() {
    for dpi in stride(from: 100, through: 12000, by: 100) {
      let encoded = ConfigLayout.encodeDPI(dpi)
      XCTAssertEqual(ConfigLayout.decodeDPI(encoded), dpi, "round trip failed at \(dpi)")
    }
  }

  func testDPIIsClampedToTheSensorRange() {
    XCTAssertEqual(ConfigLayout.decodeDPI(ConfigLayout.encodeDPI(50)), 100)
    XCTAssertEqual(ConfigLayout.decodeDPI(ConfigLayout.encodeDPI(99999)), 12000)
  }

  func testStageColoursDecodeToTheStockPrimaries() {
    let config = Fixtures.config
    XCTAssertEqual(
      (0..<6).map { config.color(atStage: $0).hexString },
      ["#FFFF00", "#0000FF", "#FF0000", "#00FF00", "#FF00FF", "#FFFFFF"])
  }

  func testLightingDecodesToGloriousModeAtFullBrightness() {
    let config = Fixtures.config
    XCTAssertEqual(config.lightingEffect, .glorious)
    XCTAssertEqual(config.brightness, .max)
    XCTAssertEqual(config.brightness.percent, 100)
    XCTAssertEqual(config.effectSpeed, .fast)
  }

  func testBrightnessAndSpeedShareOneByteWithoutClobberingEachOther() {
    var config = Fixtures.config
    config.brightness = .low
    XCTAssertEqual(config.effectSpeed, .fast, "changing brightness must not disturb speed")
    config.effectSpeed = .slowest
    XCTAssertEqual(config.brightness, .low, "changing speed must not disturb brightness")
    XCTAssertEqual(config.raw(.settings)[ConfigLayout.lightingBrightnessSpeed], 0x10)
  }

  func testSingleColorUsesItsOwnModeAndRBGColorBytes() {
    var config = Fixtures.config
    let gloriousMode = config.raw(.settings)[ConfigLayout.gloriousMode]
    config.lightingEffect = .singleColor
    XCTAssertEqual(config.singleColor.hexString, "#FF0000")
    XCTAssertEqual(config.brightness, .max)

    let teal = GloriousCore.RGBColor(red: 12, green: 210, blue: 155)
    config.singleColor = teal
    config.brightness = .medium
    let raw = config.raw(.settings)
    XCTAssertEqual(
      Array(raw[ConfigLayout.singleColor...(ConfigLayout.singleColor + 2)]),
      [12, 155, 210], "effect colours are stored R-B-G")
    XCTAssertEqual(
      raw[ConfigLayout.gloriousMode], gloriousMode,
      "editing single colour must not alter Glorious mode")
    XCTAssertEqual(config.singleColor, teal)
  }

  func testSingleBreathingColorRoundTrips() {
    var config = Fixtures.config
    config.lightingEffect = .singleBreathing
    let violet = GloriousCore.RGBColor(red: 170, green: 60, blue: 255)
    config.singleBreathingColor = violet
    XCTAssertEqual(config.singleBreathingColor, violet)
  }

  func testButtonMapDecodesToWhatTheDeviceIsActuallySetTo() {
    let config = Fixtures.config
    XCTAssertEqual(config.action(for: .left), .mouseButton(.left))
    XCTAssertEqual(config.action(for: .right), .mouseButton(.right))
    XCTAssertEqual(config.action(for: .middle), .mouseButton(.middle))
    XCTAssertEqual(
      config.action(for: .back),
      .keyboard(modifiers: .leftControl, keyCode: 0x19))
    XCTAssertEqual(
      config.action(for: .forward),
      .keyboard(modifiers: .leftControl, keyCode: 0x06))
    XCTAssertEqual(config.action(for: .dpi), .dpiAction(.cycleUp))
  }

  func testKeyboardActionsRenderWithMacGlyphs() {
    XCTAssertEqual(Fixtures.config.action(for: .back).displayName, "⌃V")
    XCTAssertEqual(Fixtures.config.action(for: .forward).displayName, "⌃C")
  }

  func testEveryButtonActionRoundTripsThroughItsEncoding() {
    let actions: [ButtonAction] = [
      .disabled, .mouseButton(.left), .mouseButton(.forward),
      .keyboard(modifiers: [.leftCommand, .leftShift], keyCode: 0x04),
      .media(.playPause), .dpiAction(.decrease),
      .scrollUp, .scrollDown, .macro(slot: 2, repeatCount: 5),
    ]
    for action in actions {
      XCTAssertEqual(
        ButtonAction(encoded: action.encoded[0...3]), action,
        "\(action) did not survive a round trip")
    }
  }
}
