import XCTest

@testable import GloriousCore

final class MessageTests: XCTestCase {

  private var inlineMessages: [(String, String)] {
    [
      ("writeRejected", Messages.writeRejected),
      ("partialWrite", Messages.partialWrite(landed: 12, rejected: 3, collateral: 1)),
      ("readBackMismatch", Messages.readBackMismatch(count: 4, block: "Settings", offset: 0x36)),
    ]
  }

  func testInlineMessagesFitTheStatusStrip() {
    for (name, text) in inlineMessages {
      XCTAssertLessThanOrEqual(
        text.count, Messages.maxLength,
        "\(name) is \(text.count) chars and will be truncated")
    }
  }

  func testInlineMessagesAreSingleParagraphSentences() {
    for (name, text) in inlineMessages {
      XCTAssertFalse(text.contains("\n"), "\(name) contains a newline")
      XCTAssertEqual(
        text, text.trimmingCharacters(in: .whitespacesAndNewlines),
        "\(name) has stray whitespace")
      XCTAssertTrue(
        text.hasSuffix(".") || text.hasSuffix("!"),
        "\(name) should end in a full stop")
    }
  }

  func testEveryTransportErrorFitsTheStatusStrip() {
    let errors: [HIDError] = [
      .deviceNotFound, .permissionDenied, .notConnected,
      .openFailed(-536_870_212), .setReportFailed(-536_870_195),
      .getReportFailed(-536_870_195), .shortRead(expected: 520, got: 131),
      .blockMismatch(expected: 0x11, got: 0x12),
    ]
    for error in errors {
      let text = error.localizedDescription
      XCTAssertFalse(text.isEmpty, "\(error) has no description")
      XCTAssertLessThanOrEqual(text.count, 220, "\(error) description is too long: \(text)")
    }
  }

  func testDetailTextExplainsWhatTheShortMessageCannot() {
    XCTAssertGreaterThan(
      Messages.writeRejectedDetail.count,
      Messages.writeRejected.count * 2)
  }
}
