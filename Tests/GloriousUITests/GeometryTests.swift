import SwiftUI
import XCTest

@testable import GloriousCore
@testable import GloriousUI

final class GeometryTests: XCTestCase {

  func testOutlineIsSymmetricAboutTheCentreLine() {
    let outline = MouseBody.outline
    for point in outline {
      let mirrored = CGPoint(x: 1 - point.x, y: point.y)
      let hasTwin = outline.contains {
        abs($0.x - mirrored.x) < 0.0001 && abs($0.y - mirrored.y) < 0.0001
      }
      XCTAssertTrue(
        hasTwin,
        "point \(point) has no mirrored counterpart — shell is lopsided")
    }
  }

  func testOutlineStaysInsideTheUnitSquare() {
    for point in MouseBody.outline {
      XCTAssertTrue((0...1).contains(point.x), "x out of range: \(point)")
      XCTAssertTrue((0...1).contains(point.y), "y out of range: \(point)")
    }
  }

  func testShellIsNarrowAtTheNoseAndWidestPastTheMiddle() {
    let widthAt: (CGFloat) -> CGFloat = { y in
      let nearest = MouseBody.outline
        .filter { $0.x > 0.5 }
        .min { abs($0.y - y) < abs($1.y - y) }
      return ((nearest?.x ?? 0.5) - 0.5) * 2
    }
    let nose = widthAt(0.13)
    let middle = widthAt(0.53)
    let tail = widthAt(0.89)

    XCTAssertLessThan(nose, middle * 0.90, "nose should be clearly narrower than the waist")
    XCTAssertLessThan(tail, middle, "tail should taper back in")
    XCTAssertGreaterThan(nose, 0.35, "nose should not be a point")
  }

  func testWidestPointSitsBehindTheMidline() {
    let widest = MouseBody.outline.filter { $0.x > 0.5 }.max { $0.x < $1.x }
    XCTAssertNotNil(widest)
    XCTAssertGreaterThan(widest!.y, 0.45)
    XCTAssertLessThan(widest!.y, 0.70)
  }

  func testRenderedPathFillsItsRect() {
    let rect = CGRect(x: 10, y: 20, width: 200, height: 380)
    let bounds = MouseBody().path(in: rect).boundingRect
    XCTAssertEqual(bounds.midX, rect.midX, accuracy: 1.5, "shell is not centred horizontally")
    XCTAssertEqual(bounds.width, rect.width, accuracy: 8)
    XCTAssertEqual(bounds.height, rect.height, accuracy: 8)
  }

  func testEveryButtonHasACallout() {
    for button in PhysicalButton.allCases {
      XCTAssertNotNil(MouseDiagram.anchors[button], "\(button) has no callout anchor")
    }
    XCTAssertEqual(Set(MouseDiagram.order), Set(PhysicalButton.allCases))
    XCTAssertEqual(MouseDiagram.order.count, PhysicalButton.allCases.count)
  }

  func testCalloutsSitInsideTheShell() {
    let rect = CGRect(x: 0, y: 0, width: 300, height: 560)
    let path = MouseBody().path(in: rect)
    for (button, anchor) in MouseDiagram.anchors {
      let point = CGPoint(
        x: rect.minX + anchor.x * rect.width,
        y: rect.minY + anchor.y * rect.height)
      XCTAssertTrue(
        path.contains(point),
        "callout for \(button) at \(anchor) falls outside the shell")
    }
  }

  func testLeftAndRightCalloutsMirrorEachOther() {
    guard let left = MouseDiagram.anchors[.left],
      let right = MouseDiagram.anchors[.right]
    else { return XCTFail("missing anchors") }
    XCTAssertEqual(left.x, 1 - right.x, accuracy: 0.001)
    XCTAssertEqual(left.y, right.y, accuracy: 0.001)
  }

  func testCalloutsDoNotOverlapEachOther() {
    let rect = CGRect(x: 0, y: 0, width: 300, height: 560)
    let points = MouseDiagram.order.compactMap { MouseDiagram.anchors[$0] }.map {
      CGPoint(x: $0.x * rect.width, y: $0.y * rect.height)
    }
    for i in points.indices {
      for j in points.indices where j > i {
        let distance = hypot(points[i].x - points[j].x, points[i].y - points[j].y)
        XCTAssertGreaterThan(distance, 26, "callouts \(i + 1) and \(j + 1) overlap")
      }
    }
  }
}
