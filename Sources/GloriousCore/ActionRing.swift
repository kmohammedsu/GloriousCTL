import CoreGraphics
import Foundation

public enum RingAction: Codable, Hashable, Sendable {
  case none
  case system(MacAction)
  case open(path: String)
  case openURL(String)
  case runShortcut(name: String)

  public var displayName: String {
    switch self {
    case .none:
      return "Do Nothing"
    case .system(let action):
      return action.displayName
    case .open(let path):
      guard !path.isEmpty else { return "Choose App or File…" }
      return URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
    case .openURL(let value):
      guard !value.isEmpty else { return "Enter URL…" }
      return URL(string: value)?.host ?? value
    case .runShortcut(let name):
      return name.isEmpty ? "Enter Shortcut Name…" : name
    }
  }

  public var symbolName: String {
    switch self {
    case .none: return "minus"
    case .system(.missionControl): return "rectangle.3.group"
    case .system(.applicationWindows): return "rectangle.on.rectangle"
    case .system(.showDesktop): return "macwindow"
    case .system(.launchpad): return "square.grid.3x3.fill"
    case .system(.spaceLeft): return "arrow.left"
    case .system(.spaceRight): return "arrow.right"
    case .system(.spotlight): return "magnifyingglass"
    case .system(.screenshotRegion): return "camera.viewfinder"
    case .system(.lockScreen): return "lock.fill"
    case .system(.volumeUp): return "speaker.wave.3.fill"
    case .system(.volumeDown): return "speaker.wave.1.fill"
    case .system(.mute): return "speaker.slash.fill"
    case .system(.playPause): return "playpause.fill"
    case .system(.nextTrack): return "forward.end.fill"
    case .system(.previousTrack): return "backward.end.fill"
    case .system(.copy): return "doc.on.doc"
    case .system(.paste): return "doc.on.clipboard"
    case .system(.undo): return "arrow.uturn.backward"
    case .system(.redo): return "arrow.uturn.forward"
    case .system(.selectAll): return "selection.pin.in.out"
    case .system(.newTab): return "plus.square.on.square"
    case .system(.closeTab): return "xmark.square"
    case .system(.emojiPicker): return "face.smiling"
    case .system(.switchApplication): return "command"
    case .system(.save): return "square.and.arrow.down"
    case .system(.find): return "doc.text.magnifyingglass"
    case .system(.print): return "printer"
    case .system(.zoomIn): return "plus.magnifyingglass"
    case .system(.zoomOut): return "minus.magnifyingglass"
    case .system(.actualSize): return "1.magnifyingglass"
    case .system(.reopenClosedTab): return "arrow.uturn.backward.square"
    case .system(.minimizeWindow): return "minus.square"
    case .system(.hideApplication): return "eye.slash"
    case .system(.forwardClick): return "arrow.right.circle"
    case .system(.backClick): return "arrow.left.circle"
    case .system(.middleClick): return "computermouse"
    case .system(.none): return "minus"
    case .open: return "app.badge"
    case .openURL: return "link"
    case .runShortcut: return "wand.and.stars"
    }
  }

  public var isConfigured: Bool {
    switch self {
    case .none, .system(.none): return false
    case .open(let path): return !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    case .openURL(let value): return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    case .runShortcut(let name):
      return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    case .system: return true
    }
  }
}

public struct ActionRingItem: Codable, Hashable, Sendable, Identifiable {
  public var id: UUID
  public var title: String
  public var action: RingAction

  public init(id: UUID = UUID(), title: String = "", action: RingAction = .none) {
    self.id = id
    self.title = title
    self.action = action
  }

  public var displayName: String {
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? action.displayName : trimmed
  }
}

public struct ActionRingConfiguration: Codable, Hashable, Sendable, Identifiable {
  public var id: Int { button.rawValue }
  public var button: PhysicalButton
  public var enabled: Bool
  public var holdDuration: Double
  public var items: [ActionRingItem]

  public init(
    button: PhysicalButton, enabled: Bool = false,
    holdDuration: Double = 0.55, items: [ActionRingItem] = []
  ) {
    self.button = button
    self.enabled = enabled
    self.holdDuration = holdDuration
    self.items = items
  }

  public static func defaultConfiguration(for button: PhysicalButton) -> ActionRingConfiguration {
    let actions: [MacAction] = [
      .missionControl, .applicationWindows, .showDesktop,
      .launchpad, .spotlight, .screenshotRegion, .lockScreen, .playPause,
    ]
    return ActionRingConfiguration(
      button: button,
      enabled: button == .middle,
      items: actions.map { ActionRingItem(action: .system($0)) })
  }
}

/// Where ring items sit.
///
/// Slots are the eight compass points, filled north, south, east, west and then the
/// diagonals. They are fixed: adding a fifth item drops it into the north-east slot
/// and leaves the first four exactly where they were. Spacing items evenly by count
/// instead would rotate every existing item on each edit, which is the one thing a
/// radial menu cannot afford — its speed comes from the direction being remembered.
public enum ActionRingLayout {
  /// Clockwise from north, in radians, in the order slots are filled.
  public static let slotAngles: [Double] = [
    0,            // north
    .pi,          // south
    .pi / 2,      // east
    3 * .pi / 2,  // west
    .pi / 4,      // north-east
    3 * .pi / 4,  // south-east
    5 * .pi / 4,  // south-west
    7 * .pi / 4,  // north-west
  ]

  public static var capacity: Int { slotAngles.count }

  /// Clockwise from north, in radians.
  public static func compassAngle(for index: Int) -> Double {
    slotAngles[index % capacity]
  }

  /// Standard maths convention (0 = right, counter-clockwise), for drawing.
  public static func drawingAngle(for index: Int) -> Double {
    .pi / 2 - compassAngle(for: index)
  }
}

public enum ActionRingSelection {
  /// Picks the nearest occupied slot rather than dividing the circle into equal
  /// wedges, so a two-item ring still splits the screen in half: fixed positions
  /// without shrinking the targets.
  public static func index(
    dx: Double, dy: Double, itemCount: Int,
    deadZone: Double = 30
  ) -> Int? {
    guard itemCount > 0, hypot(dx, dy) >= deadZone else { return nil }
    var angle = atan2(dx, -dy)
    if angle < 0 { angle += 2 * .pi }

    var best = 0
    var bestDelta = Double.greatestFiniteMagnitude
    for index in 0..<min(itemCount, ActionRingLayout.capacity) {
      var delta = abs(angle - ActionRingLayout.compassAngle(for: index))
      if delta > .pi { delta = 2 * .pi - delta }
      if delta < bestDelta {
        bestDelta = delta
        best = index
      }
    }
    return best
  }
}
