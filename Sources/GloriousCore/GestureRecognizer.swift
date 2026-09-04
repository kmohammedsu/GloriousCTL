import Foundation

public enum GestureDirection: String, Codable, Hashable, Sendable, CaseIterable {
  case tap, up, down, left, right

  public var displayName: String {
    switch self {
    case .tap: return "Click (no drag)"
    case .up: return "Drag Up"
    case .down: return "Drag Down"
    case .left: return "Drag Left"
    case .right: return "Drag Right"
    }
  }

  public var symbolName: String {
    switch self {
    case .tap: return "hand.tap"
    case .up: return "arrow.up"
    case .down: return "arrow.down"
    case .left: return "arrow.left"
    case .right: return "arrow.right"
    }
  }
}

public struct GestureRecognizer: Sendable {

  public var threshold: Double

  public var dominanceRatio: Double

  public init(threshold: Double = 22, dominanceRatio: Double = 1.3) {
    self.threshold = threshold
    self.dominanceRatio = dominanceRatio
  }

  public func classify(dx: Double, dy: Double) -> GestureDirection {
    let absX = abs(dx)
    let absY = abs(dy)

    if absX < threshold && absY < threshold { return .tap }

    if absX >= threshold && absY >= threshold {
      if absX > absY * dominanceRatio { return dx > 0 ? .right : .left }
      if absY > absX * dominanceRatio { return dy > 0 ? .down : .up }
      return .tap
    }

    if absX >= threshold { return dx > 0 ? .right : .left }
    return dy > 0 ? .down : .up
  }
}

public struct GestureBinding: Codable, Hashable, Sendable, Identifiable {
  public var id: Int { button.rawValue }

  public var button: PhysicalButton
  public var enabled: Bool
  public var actions: [GestureDirection: MacAction]

  public init(
    button: PhysicalButton, enabled: Bool = false,
    actions: [GestureDirection: MacAction] = [:]
  ) {
    self.button = button
    self.enabled = enabled
    self.actions = actions
  }

  public func action(for direction: GestureDirection) -> MacAction {
    actions[direction] ?? .none
  }

  static func passthroughTap(for button: PhysicalButton) -> MacAction {
    switch button {
    case .back: return .backClick
    case .forward: return .forwardClick
    case .middle: return .middleClick
    default: return .none
    }
  }

  public static func defaultBinding(for button: PhysicalButton) -> GestureBinding {
    GestureBinding(
      button: button, enabled: false,
      actions: [
        .tap: passthroughTap(for: button),
        .up: .missionControl,
        .down: .applicationWindows,
        .left: .spaceLeft,
        .right: .spaceRight,
      ])
  }
}
