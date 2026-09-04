import SwiftUI
import XCTest

@testable import GloriousCore
@testable import GloriousUI

@MainActor
final class RenderTests: XCTestCase {

  private func render(size: CGSize) throws -> NSBitmapImageRep {
    let view = ZStack {
      Theme.background
      MouseDiagram(
        actions: [.left: .mouseButton(.left)],
        underglow: .blue
      )
      .padding(16)
    }
    .frame(width: size.width, height: size.height)

    let renderer = ImageRenderer(content: view)
    renderer.isOpaque = true
    guard let image = renderer.nsImage,
      let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff)
    else {
      throw XCTSkip("ImageRenderer unavailable in this environment")
    }
    return bitmap
  }

  func testDiagramRendersSomethingOtherThanAFlatBackground() throws {
    let bitmap = try render(size: CGSize(width: 300, height: 460))
    var distinct = Set<String>()
    for x in stride(from: 4, to: bitmap.pixelsWide - 4, by: 11) {
      for y in stride(from: 4, to: bitmap.pixelsHigh - 4, by: 11) {
        if let colour = bitmap.colorAt(x: x, y: y) {
          distinct.insert(
            String(
              format: "%.2f,%.2f,%.2f",
              colour.redComponent, colour.greenComponent,
              colour.blueComponent))
        }
      }
    }
    XCTAssertGreaterThan(
      distinct.count, 12,
      "diagram rendered nearly flat — the shell is probably missing")
  }

  func testShellOccupiesTheMiddleOfTheCanvas() throws {
    let bitmap = try render(size: CGSize(width: 300, height: 460))
    let centre = bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2)
    let corner = bitmap.colorAt(x: 3, y: 3)
    XCTAssertNotNil(centre)
    XCTAssertNotNil(corner)
    XCTAssertGreaterThan(
      centre!.brightnessComponent, corner!.brightnessComponent,
      "no shell drawn in the middle of the canvas")
  }

  func testRendersAcrossTheSizesTheAppUses() throws {
    for size in [CGSize(width: 220, height: 340), CGSize(width: 420, height: 620)] {
      let bitmap = try render(size: size)
      XCTAssertGreaterThan(bitmap.pixelsWide, 0)
      XCTAssertGreaterThan(bitmap.pixelsHigh, 0)
    }
  }
}
