import XCTest

@testable import GloriousCore

final class ValidatorTests: XCTestCase {

  func testRealDeviceConfigPassesEveryCheck() {
    let validator = LayoutValidator(config: Fixtures.config)
    let failures = validator.checks.filter { !$0.passed }
    XCTAssertTrue(
      failures.isEmpty,
      "unexpected failures: " + failures.map(\.field).joined(separator: ", "))
    XCTAssertEqual(validator.confidence, 1.0)
  }

  func testValidatorCatchesAnImpossibleDPIStageCount() {
    var settings = Fixtures.settingsBlock
    settings[ConfigLayout.dpiStageCount] = 99
    let validator = LayoutValidator(
      config: MouseConfig(settings: settings, buttons: Fixtures.buttonsBlock))
    XCTAssertTrue(validator.checks.contains { $0.field == "DPI Stage Count" && !$0.passed })
  }

  func testValidatorCatchesAnUnknownLightingEffect() {
    var settings = Fixtures.settingsBlock
    settings[ConfigLayout.lightingEffect] = 0xEE
    let validator = LayoutValidator(
      config: MouseConfig(settings: settings, buttons: Fixtures.buttonsBlock))
    XCTAssertTrue(validator.checks.contains { $0.field == "Lighting Effect" && !$0.passed })
  }

  func testValidatorCatchesAWrongBlockEcho() {
    var settings = Fixtures.settingsBlock
    settings[ConfigLayout.blockCommand] = 0x12
    let validator = LayoutValidator(
      config: MouseConfig(settings: settings, buttons: Fixtures.buttonsBlock))
    XCTAssertTrue(validator.checks.contains { $0.field == "Block header" && !$0.passed })
  }
}
