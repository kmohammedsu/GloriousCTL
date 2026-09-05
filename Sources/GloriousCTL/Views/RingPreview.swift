import GloriousCore
import GloriousUI
import SwiftUI

/// A live, interactive miniature of the ring being edited.
///
/// The ring is a radial menu but it is configured through a vertical list, so there
/// was no way to see what you were building. This mirrors the real overlay's
/// placement — evenly spaced, first item at twelve o'clock, running clockwise — and
/// doubles as the control surface: click a bubble to jump to its row, drag one onto
/// another slot to reorder.
struct RingPreview: View {
  let items: [ActionRingItem]
  var selectedID: UUID?
  var diameter: CGFloat = 168
  var onSelect: ((UUID) -> Void)?
  /// Reorders the list: the item at `from` is lifted out and inserted at `to`.
  var onMove: ((Int, Int) -> Void)?

  @State private var dragIndex: Int?
  @State private var dragTranslation: CGSize = .zero

  private var orbit: CGFloat { diameter / 2 - 22 }

  var body: some View {
    ZStack {
      Circle()
        .strokeBorder(
          Theme.border.opacity(0.55),
          style: StrokeStyle(lineWidth: 1, dash: items.isEmpty ? [3, 3] : []))

      if items.isEmpty {
        VStack(spacing: 2) {
          Image(systemName: "circle.dashed")
            .font(.system(size: 15)).foregroundStyle(Theme.textDim)
          Text("No items yet")
            .font(.system(size: 9)).foregroundStyle(Theme.textDim)
        }
      } else {
        // The centre is the cancel target in the real ring; showing it keeps the dead
        // zone reading as deliberate rather than as empty space.
        Circle()
          .fill(Color.white.opacity(0.05))
          .frame(width: 26, height: 26)
          .overlay(
            Image(systemName: "xmark")
              .font(.system(size: 8, weight: .semibold))
              .foregroundStyle(Theme.textDim))

        // Slot markers show where a dragged bubble can land, so the fixed positions
        // are visible while rearranging.
        if dragIndex != nil {
          ForEach(items.indices, id: \.self) { index in
            Circle()
              .strokeBorder(Theme.accent.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
              .frame(width: 32, height: 32)
              .offset(slotOffset(for: index))
          }
        }

        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
          bubble(item, index: index)
        }
      }
    }
    .frame(width: diameter, height: diameter)
  }

  private func bubble(_ item: ActionRingItem, index: Int) -> some View {
    let isDragging = dragIndex == index
    let isSelected = selectedID == item.id
    return Image(systemName: item.action.symbolName)
      .font(.system(size: 11))
      .foregroundStyle(isSelected ? Theme.accent : Theme.text)
      .frame(width: 30, height: 30)
      .background(Circle().fill(Color.white.opacity(isDragging ? 0.18 : 0.09)))
      .overlay(
        Circle().stroke(
          isSelected ? Theme.accent : Theme.accent.opacity(0.55),
          lineWidth: isSelected ? 1.6 : 1))
      .scaleEffect(isDragging ? 1.15 : 1)
      .offset(slotOffset(for: index))
      .offset(isDragging ? dragTranslation : .zero)
      .zIndex(isDragging ? 1 : 0)
      .help(item.displayName)
      .onTapGesture { onSelect?(item.id) }
      .gesture(
        DragGesture(minimumDistance: 4)
          .onChanged { value in
            dragIndex = index
            dragTranslation = value.translation
          }
          .onEnded { value in
            let target = nearestSlot(
              to: CGPoint(
                x: slotOffset(for: index).width + value.translation.width,
                y: slotOffset(for: index).height + value.translation.height))
            dragIndex = nil
            dragTranslation = .zero
            if target != index { onMove?(index, target) }
          })
  }

  /// Matches `ActionRingOverlay`: `π/2 − 2π·index/count`, clockwise from the top.
  /// SwiftUI's y axis points down, so the sine term is subtracted rather than added.
  private func slotOffset(for index: Int) -> CGSize {
    guard !items.isEmpty else { return .zero }
    let angle = CGFloat.pi / 2 - (2 * .pi * CGFloat(index) / CGFloat(items.count))
    return CGSize(width: cos(angle) * orbit, height: -sin(angle) * orbit)
  }

  private func nearestSlot(to point: CGPoint) -> Int {
    var best = 0
    var bestDistance = CGFloat.greatestFiniteMagnitude
    for index in items.indices {
      let slot = slotOffset(for: index)
      let distance = hypot(point.x - slot.width, point.y - slot.height)
      if distance < bestDistance {
        bestDistance = distance
        best = index
      }
    }
    return best
  }
}
