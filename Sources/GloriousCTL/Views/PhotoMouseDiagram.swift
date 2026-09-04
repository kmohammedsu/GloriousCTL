import AppKit
import GloriousCore
import GloriousUI
import SwiftUI

struct PhotoMouseDiagram: View {
  let actions: [PhysicalButton: ButtonAction]
  let selected: PhysicalButton?
  let onSelect: (PhysicalButton) -> Void

  private static let productImage: NSImage = {
    guard let url = Bundle.module.url(forResource: "model-o-white", withExtension: "png"),
      let image = NSImage(contentsOf: url)
    else { return NSImage() }
    return image
  }()

  private struct Hotspot {
    let button: PhysicalButton
    let number: Int
    let point: CGPoint
  }

  private let hotspots: [Hotspot] = [
    .init(button: .left, number: 1, point: CGPoint(x: 0.385, y: 0.245)),
    .init(button: .right, number: 2, point: CGPoint(x: 0.615, y: 0.245)),
    .init(button: .middle, number: 3, point: CGPoint(x: 0.500, y: 0.195)),
    .init(button: .forward, number: 4, point: CGPoint(x: 0.255, y: 0.405)),
    .init(button: .back, number: 5, point: CGPoint(x: 0.255, y: 0.485)),
    .init(button: .dpi, number: 6, point: CGPoint(x: 0.500, y: 0.375)),
  ]

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        Ellipse()
          .fill(Theme.accent.opacity(0.055))
          .blur(radius: 64)
          .frame(
            width: proxy.size.width * 0.72,
            height: proxy.size.height * 0.68
          )
          .offset(y: proxy.size.height * 0.08)

        Image(nsImage: Self.productImage)
          .resizable()
          .interpolation(.high)
          .scaledToFit()
          .accessibilityLabel("White Glorious Model O mouse")

        ForEach(hotspots, id: \.button) { hotspot in
          hotspotView(hotspot)
            .position(
              x: proxy.size.width * hotspot.point.x,
              y: proxy.size.height * hotspot.point.y)
        }
      }
    }
    .aspectRatio(1235.0 / 1274.0, contentMode: .fit)
  }

  private func hotspotView(_ hotspot: Hotspot) -> some View {
    let isSelected = selected == hotspot.button
    return Button {
      onSelect(hotspot.button)
    } label: {
      ZStack {
        Circle()
          .fill(isSelected ? Theme.accent : Color.white)
        Circle()
          .strokeBorder(
            isSelected ? Color.white.opacity(0.9) : Theme.accent,
            lineWidth: isSelected ? 2 : 2.5)
        Text("\(hotspot.number)")
          .font(.system(size: 12, weight: .black, design: .rounded))
          .foregroundStyle(Color.black.opacity(0.86))
      }
      .frame(width: isSelected ? 34 : 30, height: isSelected ? 34 : 30)
      .shadow(color: Color.black.opacity(0.55), radius: 8, y: 3)
      .shadow(
        color: isSelected ? Theme.accent.opacity(0.65) : .clear,
        radius: 12
      )
      .animation(.easeOut(duration: 0.12), value: isSelected)
    }
    .buttonStyle(.plain)
    .help("\(hotspot.button.displayName) — \(actionName(for: hotspot.button))")
    .accessibilityLabel("Button \(hotspot.number), \(hotspot.button.displayName)")
    .accessibilityValue(actionName(for: hotspot.button))
  }

  private func actionName(for button: PhysicalButton) -> String {
    actions[button]?.displayName ?? button.factoryDefault.displayName
  }
}
