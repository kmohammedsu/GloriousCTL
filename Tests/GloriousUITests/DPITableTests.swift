import SwiftUI
import XCTest

@testable import GloriousCore
@testable import GloriousUI

final class DPITableTests: XCTestCase {

  private func table(selected: Int, stageCount: Int = 6) -> DPIStageTable {
    var value = selected
    let binding = Binding(get: { value }, set: { value = $0 })
    return DPIStageTable(
      stages: (0..<stageCount).map {
        .init(id: $0, dpi: ($0 + 1) * 400, color: .white)
      },
      enabledCount: 4, activeStage: 4, selectedStage: binding)
  }

  func testSelectionClampsAboveTheLastRow() {
    XCTAssertEqual(table(selected: 99).effectiveSelection, 5)
  }

  func testSelectionClampsBelowTheFirstRow() {
    XCTAssertEqual(table(selected: -3).effectiveSelection, 0)
  }

  func testValidSelectionIsUsedAsGiven() {
    XCTAssertEqual(table(selected: 2).effectiveSelection, 2)
  }

  func testSafeSubscriptDoesNotTrapOutOfRange() {
    let values = [1, 2, 3]
    XCTAssertEqual(values[safe: 1], 2)
    XCTAssertNil(values[safe: 9])
    XCTAssertNil(values[safe: -1])
  }

  func testColourConversionRoundTrips() {
    for colour in [
      GloriousCore.RGBColor(red: 255, green: 255, blue: 0),
      GloriousCore.RGBColor(red: 0, green: 0, blue: 255),
      GloriousCore.RGBColor(red: 18, green: 200, blue: 77),
    ] {
      XCTAssertEqual(
        Color(rgbColor: colour).asRGBColor, colour,
        "colour did not survive the SwiftUI round trip")
    }
  }
}
