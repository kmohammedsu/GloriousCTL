import SwiftUI

public enum SmoothPath {

  public static func closed(
    through points: [CGPoint], in rect: CGRect,
    tension: CGFloat = 1.0
  ) -> Path {
    guard points.count > 2 else { return Path() }

    let scaled = points.map {
      CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height)
    }

    var path = Path()
    path.move(to: scaled[0])

    let count = scaled.count
    for index in 0..<count {
      let p0 = scaled[(index - 1 + count) % count]
      let p1 = scaled[index]
      let p2 = scaled[(index + 1) % count]
      let p3 = scaled[(index + 2) % count]

      let control1 = CGPoint(
        x: p1.x + (p2.x - p0.x) / (6 * tension),
        y: p1.y + (p2.y - p0.y) / (6 * tension))
      let control2 = CGPoint(
        x: p2.x - (p3.x - p1.x) / (6 * tension),
        y: p2.y - (p3.y - p1.y) / (6 * tension))
      path.addCurve(to: p2, control1: control1, control2: control2)
    }
    path.closeSubpath()
    return path
  }
}

public struct MouseBody: Shape {

  public init() {}

  static let rightHalf: [CGPoint] = [
    CGPoint(x: 0.500, y: 0.000),
    CGPoint(x: 0.640, y: 0.006),
    CGPoint(x: 0.752, y: 0.048),
    CGPoint(x: 0.848, y: 0.130),
    CGPoint(x: 0.922, y: 0.246),
    CGPoint(x: 0.968, y: 0.390),
    CGPoint(x: 0.988, y: 0.532),
    CGPoint(x: 0.980, y: 0.668),
    CGPoint(x: 0.944, y: 0.788),
    CGPoint(x: 0.878, y: 0.888),
    CGPoint(x: 0.780, y: 0.958),
    CGPoint(x: 0.648, y: 0.994),
    CGPoint(x: 0.500, y: 1.000),
  ]

  public static var outline: [CGPoint] {
    let mirrored = rightHalf.dropFirst().dropLast().reversed().map {
      CGPoint(x: 1 - $0.x, y: $0.y)
    }
    return rightHalf + mirrored
  }

  public func path(in rect: CGRect) -> Path {
    SmoothPath.closed(through: Self.outline, in: rect)
  }
}

public struct Honeycomb: Shape {
  public var cell: CGFloat
  public init(cell: CGFloat = 9) { self.cell = cell }

  public func path(in rect: CGRect) -> Path {
    var path = Path()
    let radius = cell / 2
    let stepX = radius * 1.82
    let stepY = radius * 1.58
    var row = 0
    var y = rect.minY
    while y < rect.maxY + cell {
      var x = rect.minX + (row.isMultiple(of: 2) ? 0 : stepX / 2)
      while x < rect.maxX + cell {
        path.addPath(hexagon(center: CGPoint(x: x, y: y), radius: radius * 0.74))
        x += stepX
      }
      y += stepY
      row += 1
    }
    return path
  }

  private func hexagon(center: CGPoint, radius: CGFloat) -> Path {
    var path = Path()
    for corner in 0..<6 {
      let angle = CGFloat(corner) * .pi / 3 - .pi / 2
      let point = CGPoint(
        x: center.x + radius * cos(angle),
        y: center.y + radius * sin(angle))
      corner == 0 ? path.move(to: point) : path.addLine(to: point)
    }
    path.closeSubpath()
    return path
  }
}
