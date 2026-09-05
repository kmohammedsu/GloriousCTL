import AppKit

@MainActor
final class ActionRingOverlay {
  private let diameter: CGFloat = 560
  private var panel: NSPanel?
  private var ringView: ActionRingView?

  func show(items: [ActionRingItem]) {
    let cursor = NSEvent.mouseLocation
    let rect = NSRect(
      x: cursor.x - diameter / 2,
      y: cursor.y - diameter / 2,
      width: diameter, height: diameter)
    let panel = self.panel ?? makePanel(frame: rect)
    panel.setFrame(rect, display: true)
    ringView?.items = items
    ringView?.selectedIndex = nil
    panel.alphaValue = 0
    panel.orderFrontRegardless()
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.10
      context.timingFunction = CAMediaTimingFunction(name: .easeOut)
      panel.animator().alphaValue = 1
    }
  }

  func select(_ index: Int?) {
    ringView?.selectedIndex = index
  }

  func hide() {
    guard let panel else { return }
    NSAnimationContext.runAnimationGroup(
      { context in
        context.duration = 0.07
        panel.animator().alphaValue = 0
      },
      completionHandler: { [weak panel] in
        panel?.orderOut(nil)
      })
    ringView?.selectedIndex = nil
  }

  private func makePanel(frame: NSRect) -> NSPanel {
    let panel = NSPanel(
      contentRect: frame,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered, defer: false)
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.level = .popUpMenu
    panel.ignoresMouseEvents = true
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    let view = ActionRingView(frame: NSRect(origin: .zero, size: frame.size))
    panel.contentView = view
    ringView = view
    self.panel = panel
    return panel
  }
}

final class ActionRingView: NSView {
  var items: [ActionRingItem] = [] { didSet { needsDisplay = true } }
  var selectedIndex: Int? { didSet { needsDisplay = true } }

  override var isFlipped: Bool { false }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    guard !items.isEmpty else { return }

    let center = CGPoint(x: bounds.midX, y: bounds.midY)
    let guideRect = NSRect(
      x: center.x - 108, y: center.y - 108,
      width: 216, height: 216)
    let guide = NSBezierPath(ovalIn: guideRect)
    NSColor.white.withAlphaComponent(0.12).setStroke()
    guide.lineWidth = 1
    guide.setLineDash([2, 5], count: 2, phase: 0)
    guide.stroke()

    let bubbleRadius: CGFloat = 112
    for (index, item) in items.enumerated() {
      let angle = CGFloat(ActionRingLayout.drawingAngle(for: index))
      let bubblePoint = CGPoint(
        x: center.x + cos(angle) * bubbleRadius,
        y: center.y + sin(angle) * bubbleRadius)
      drawLabel(
        item.displayName, outside: bubblePoint, angle: angle,
        selected: selectedIndex == index)
      drawBubble(item: item, at: bubblePoint, selected: selectedIndex == index)
    }

    drawHub(at: center)
  }

  private func drawBubble(item: ActionRingItem, at point: CGPoint, selected: Bool) {
    let diameter: CGFloat = selected ? 66 : 56
    let rect = NSRect(
      x: point.x - diameter / 2, y: point.y - diameter / 2,
      width: diameter, height: diameter)

    if selected {
      let halo = NSBezierPath(ovalIn: rect.insetBy(dx: -7, dy: -7))
      NSColor.systemOrange.withAlphaComponent(0.22).setFill()
      halo.fill()
      NSColor.systemOrange.withAlphaComponent(0.9).setStroke()
      halo.lineWidth = 2
      halo.stroke()
    }

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.48)
    shadow.shadowBlurRadius = selected ? 16 : 10
    shadow.shadowOffset = NSSize(width: 0, height: -3)

    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    let bubble = NSBezierPath(ovalIn: rect)
    (selected
      ? NSColor.systemOrange
      : NSColor(calibratedWhite: 0.055, alpha: 0.96)).setFill()
    bubble.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSColor.white.withAlphaComponent(selected ? 0.88 : 0.20).setStroke()
    bubble.lineWidth = 1
    bubble.stroke()

    if let base = NSImage(
      systemSymbolName: item.action.symbolName,
      accessibilityDescription: item.displayName)
    {
      let color = selected ? NSColor.black.withAlphaComponent(0.88) : .white
      let config = NSImage.SymbolConfiguration(
        pointSize: selected ? 23 : 20,
        weight: .medium
      )
      .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
      let image = base.withSymbolConfiguration(config) ?? base
      let iconSize: CGFloat = selected ? 27 : 24
      let iconRect = NSRect(
        x: point.x - iconSize / 2, y: point.y - iconSize / 2,
        width: iconSize, height: iconSize)
      image.draw(in: iconRect)
    }
  }

  private func drawLabel(
    _ text: String, outside bubblePoint: CGPoint, angle: CGFloat,
    selected: Bool
  ) {
    let maxWidth: CGFloat = 150
    let font = NSFont.systemFont(
      ofSize: selected ? 11 : 10,
      weight: selected ? .semibold : .medium)
    let measured = (text as NSString).size(withAttributes: [.font: font])
    let width = min(maxWidth, max(46, measured.width + 20))
    let height: CGFloat = selected ? 29 : 25

    let bubbleHalf: CGFloat = selected ? 33 : 28
    let gap: CGFloat = 10
    let xDirection = cos(angle)
    let yDirection = sin(angle)
    var origin = CGPoint.zero
    if abs(xDirection) > 0.55 {
      origin.x =
        xDirection > 0
        ? bubblePoint.x + bubbleHalf + gap
        : bubblePoint.x - bubbleHalf - gap - width
      origin.y = bubblePoint.y - height / 2
    } else {
      origin.x = bubblePoint.x - width / 2
      origin.y =
        yDirection > 0
        ? bubblePoint.y + bubbleHalf + gap
        : bubblePoint.y - bubbleHalf - gap - height
    }
    let rect = NSRect(origin: origin, size: NSSize(width: width, height: height))

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 7
    shadow.shadowOffset = NSSize(width: 0, height: -2)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    let pill = NSBezierPath(roundedRect: rect, xRadius: height / 2, yRadius: height / 2)
    (selected
      ? NSColor.systemOrange
      : NSColor(calibratedWhite: 0.08, alpha: 0.88)).setFill()
    pill.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSColor.white.withAlphaComponent(selected ? 0.78 : 0.13).setStroke()
    pill.lineWidth = 1
    pill.stroke()

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.lineBreakMode = .byTruncatingTail
    (text as NSString).draw(
      in: rect.insetBy(dx: 8, dy: 6),
      withAttributes: [
        .font: font,
        .foregroundColor: selected ? NSColor.black.withAlphaComponent(0.88) : .white,
        .paragraphStyle: paragraph,
      ])
  }

  private func drawHub(at center: CGPoint) {
    let hubRect = NSRect(x: center.x - 16, y: center.y - 16, width: 32, height: 32)
    let hub = NSBezierPath(ovalIn: hubRect)
    NSColor(calibratedWhite: 0.90, alpha: 0.94).setFill()
    hub.fill()
    NSColor.black.withAlphaComponent(0.14).setStroke()
    hub.lineWidth = 1
    hub.stroke()

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    ("×" as NSString).draw(
      in: NSRect(x: center.x - 20, y: center.y - 7, width: 40, height: 14),
      withAttributes: [
        .font: NSFont.systemFont(ofSize: 14, weight: .medium),
        .foregroundColor: NSColor.black.withAlphaComponent(0.68),
        .paragraphStyle: paragraph,
      ])
  }
}

public enum ActionRingPreviewRenderer {
  @MainActor
  public static func png(items: [ActionRingItem], selectedIndex: Int? = nil) -> Data? {
    let frame = NSRect(x: 0, y: 0, width: 560, height: 560)
    let view = ActionRingView(frame: frame)
    view.items = items
    view.selectedIndex = selectedIndex
    guard let bitmap = view.bitmapImageRepForCachingDisplay(in: frame) else { return nil }
    view.cacheDisplay(in: frame, to: bitmap)
    return bitmap.representation(using: .png, properties: [:])
  }
}
