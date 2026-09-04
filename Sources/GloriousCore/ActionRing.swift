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

public enum ActionRingSelection {
  public static func index(
    dx: Double, dy: Double, itemCount: Int,
    deadZone: Double = 30
  ) -> Int? {
    guard itemCount > 0, hypot(dx, dy) >= deadZone else { return nil }
    var angle = atan2(dx, -dy)
    if angle < 0 { angle += 2 * .pi }
    let segment = 2 * Double.pi / Double(itemCount)
    return Int(floor((angle + segment / 2) / segment)) % itemCount
  }
}
