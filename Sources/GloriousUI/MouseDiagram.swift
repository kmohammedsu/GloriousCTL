import GloriousCore
import SwiftUI

public struct MouseDiagram: View {
  let actions: [PhysicalButton: ButtonAction]
  let underglow: Color
  var selected: PhysicalButton?
  var onSelect: (PhysicalButton) -> Void

  public init(
    actions: [PhysicalButton: ButtonAction],
    underglow: Color,
    selected: PhysicalButton? = nil,
    onSelect: @escaping (PhysicalButton) -> Void = { _ in }
  ) {
    self.actions = actions
    self.underglow = underglow
    self.selected = selected
    self.onSelect = onSelect
  }

  static let anchors: [PhysicalButton: CGPoint] = [
    .left: CGPoint(x: 0.315, y: 0.140),
    .right: CGPoint(x: 0.685, y: 0.140),
    .middle: CGPoint(x: 0.500, y: 0.088),
    .dpi: CGPoint(x: 0.500, y: 0.322),
    .forward: CGPoint(x: 0.170, y: 0.262),
    .back: CGPoint(x: 0.170, y: 0.350),
  ]

  static let order: [PhysicalButton] = [.left, .right, .middle, .forward, .back, .dpi]

  static let aspect: CGFloat = 66.0 / 128.0

  public var body: some View {
    GeometryReader { geometry in
      let bodyHeight = min(
        geometry.size.height * 0.94,
        geometry.size.width / Self.aspect * 0.92)
      let bodyWidth = bodyHeight * Self.aspect
      let rect = CGRect(
        x: (geometry.size.width - bodyWidth) / 2,
        y: (geometry.size.height - bodyHeight) / 2,
        width: bodyWidth, height: bodyHeight)

      ZStack(alignment: .topLeading) {
        underglowLayer(rect)
        shell(rect)
        perforations(rect)
        clickPlates(rect)
        dpiRecess(rect)
        scrollWheel(rect)
        sideButtons(rect)
        cableNotch(rect)
        badges(rect)
      }
    }
  }

  private func underglowLayer(_ rect: CGRect) -> some View {
    ZStack {
      MouseBody().path(in: rect.insetBy(dx: -7, dy: -7))
        .fill(underglow.opacity(0.30)).blur(radius: 20)
      MouseBody().path(in: rect.insetBy(dx: -3, dy: -3))
        .fill(underglow.opacity(0.42)).blur(radius: 8)
      MouseBody().path(in: rect)
        .strokedPath(.init(lineWidth: 2))
        .fill(underglow.opacity(0.85)).blur(radius: 2.5)
    }
  }

  private func shell(_ rect: CGRect) -> some View {
    ZStack {
      MouseBody().path(in: rect)
        .fill(
          LinearGradient(
            colors: [Color(white: 0.215), Color(white: 0.155), Color(white: 0.115)],
            startPoint: .top, endPoint: .bottom))

      MouseBody().path(in: rect)
        .fill(
          RadialGradient(
            colors: [.white.opacity(0.085), .clear],
            center: UnitPoint(x: 0.5, y: 0.18),
            startRadius: 0, endRadius: rect.width * 0.95))

      MouseBody().path(in: rect)
        .strokedPath(.init(lineWidth: 1))
        .fill(Color(white: 0.42))
    }
  }

  private func perforations(_ rect: CGRect) -> some View {
    Honeycomb(cell: max(9, rect.width * 0.105))
      .path(
        in: CGRect(
          x: rect.minX, y: rect.minY + rect.height * 0.44,
          width: rect.width, height: rect.height * 0.50)
      )
      .fill(Color.black.opacity(0.34))
      .clipShape(
        MouseBody().path(
          in: rect.insetBy(
            dx: rect.width * 0.085,
            dy: rect.height * 0.045))
      )
      .mask(
        LinearGradient(
          stops: [
            .init(color: .clear, location: 0.0),
            .init(color: .black, location: 0.14),
            .init(color: .black, location: 0.82),
            .init(color: .clear, location: 1.0),
          ],
          startPoint: .top, endPoint: .bottom
        )
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY))
  }

  private func clickPlates(_ rect: CGRect) -> some View {
    let plateBottom = rect.minY + rect.height * 0.380
    let gap = rect.width * 0.016

    return ZStack {
      ForEach([0, 1], id: \.self) { side in
        let isLeft = side == 0
        MouseBody().path(in: rect)
          .fill(
            LinearGradient(
              colors: [Color.white.opacity(0.105), Color.white.opacity(0.030)],
              startPoint: .top, endPoint: .bottom)
          )
          .clipShape(
            Rectangle().path(
              in: CGRect(
                x: isLeft ? rect.minX - 2 : rect.midX + gap,
                y: rect.minY - 2,
                width: rect.width / 2 - gap + 2,
                height: plateBottom - rect.minY + 2)))
      }

      let seamTop = rect.minY + rect.height * 0.175
      let seamBottom = rect.minY + rect.height * 0.288
      Capsule()
        .fill(Color.black.opacity(0.62))
        .frame(width: max(1.5, gap * 0.55), height: seamBottom - seamTop)
        .position(x: rect.midX, y: (seamTop + seamBottom) / 2)

      Path { path in
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.045, y: plateBottom))
        path.addQuadCurve(
          to: CGPoint(x: rect.maxX - rect.width * 0.045, y: plateBottom),
          control: CGPoint(x: rect.midX, y: plateBottom + rect.height * 0.026))
      }
      .stroke(Color.black.opacity(0.65), lineWidth: 1.4)
    }
  }

  private func scrollWheel(_ rect: CGRect) -> some View {
    let width = rect.width * 0.115
    let height = rect.height * 0.132
    let centre = CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.108)

    return ZStack {
      RoundedRectangle(cornerRadius: width * 0.5)
        .fill(Color.black.opacity(0.90))
        .frame(width: width * 1.42, height: height * 1.22)

      RoundedRectangle(cornerRadius: width * 0.46)
        .fill(
          LinearGradient(
            colors: [Color(white: 0.22), Color(white: 0.09)],
            startPoint: .top, endPoint: .bottom)
        )
        .overlay(
          RoundedRectangle(cornerRadius: width * 0.46)
            .strokeBorder(underglow.opacity(0.90), lineWidth: 1.3)
        )
        .frame(width: width, height: height)
        .shadow(color: underglow.opacity(0.60), radius: 4)
    }
    .position(centre)
  }

  private func sideButtons(_ rect: CGRect) -> some View {
    ForEach([0, 1], id: \.self) { index in
      let y = rect.minY + rect.height * (index == 0 ? 0.262 : 0.350)
      RoundedRectangle(cornerRadius: rect.width * 0.028)
        .fill(
          LinearGradient(
            colors: [Color(white: 0.28), Color(white: 0.16)],
            startPoint: .top, endPoint: .bottom)
        )
        .overlay(
          RoundedRectangle(cornerRadius: rect.width * 0.028)
            .strokeBorder(Color.black.opacity(0.75), lineWidth: 1)
        )
        .frame(width: rect.width * 0.155, height: rect.height * 0.048)
        .rotationEffect(.degrees(index == 0 ? -7 : -3))
        .position(x: rect.minX + rect.width * 0.170, y: y)
    }
  }

  private func cableNotch(_ rect: CGRect) -> some View {
    RoundedRectangle(cornerRadius: rect.height * 0.006)
      .fill(Color.black.opacity(0.55))
      .frame(width: rect.width * 0.215, height: rect.height * 0.011)
      .position(x: rect.midX, y: rect.minY + rect.height * 0.008)
  }

  private func dpiRecess(_ rect: CGRect) -> some View {
    Circle()
      .fill(Color.black.opacity(0.45))
      .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
      .frame(width: rect.width * 0.165, height: rect.width * 0.165)
      .position(x: rect.midX, y: rect.minY + rect.height * 0.322)
  }

  private func badges(_ rect: CGRect) -> some View {
    ForEach(Array(Self.order.enumerated()), id: \.element) { index, button in
      if let anchor = Self.anchors[button] {
        CalloutBadge(
          number: index + 1,
          isSelected: selected == button,
          label: actions[button]?.displayName ?? ""
        )
        .position(
          x: rect.minX + anchor.x * rect.width,
          y: rect.minY + anchor.y * rect.height
        )
        .onTapGesture { onSelect(button) }
      }
    }
  }
}

public struct CalloutBadge: View {
  let number: Int
  let isSelected: Bool
  let label: String

  public init(number: Int, isSelected: Bool, label: String) {
    self.number = number
    self.isSelected = isSelected
    self.label = label
  }

  public var body: some View {
    Text("\(number)")
      .font(.system(size: 10, weight: .bold))
      .foregroundStyle(Color(white: 0.08))
      .frame(width: 20, height: 20)
      .background(Circle().fill(Theme.accent))
      .overlay(
        Circle().strokeBorder(
          .white.opacity(isSelected ? 0.95 : 0.25),
          lineWidth: isSelected ? 1.6 : 0.8)
      )
      .shadow(color: .black.opacity(0.6), radius: 3, y: 1)
      .scaleEffect(isSelected ? 1.18 : 1)
      .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
      .help(label)
  }
}
