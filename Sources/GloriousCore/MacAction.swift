import CoreGraphics
import Foundation

public enum MacAction: Codable, Hashable, Sendable, CaseIterable {
  case none
  case missionControl
  case applicationWindows
  case showDesktop
  case launchpad
  case spaceLeft
  case spaceRight
  case spotlight
  case screenshotRegion
  case lockScreen
  case volumeUp
  case volumeDown
  case mute
  case playPause
  case nextTrack
  case previousTrack
  case copy
  case paste
  case undo
  case redo
  case selectAll
  case newTab
  case closeTab
  case emojiPicker
  case switchApplication
  case save
  case find
  case print
  case zoomIn
  case zoomOut
  case actualSize
  case reopenClosedTab
  case minimizeWindow
  case hideApplication
  case forwardClick
  case backClick
  case middleClick

  public var displayName: String {
    switch self {
    case .none: return "Do Nothing"
    case .missionControl: return "Mission Control"
    case .applicationWindows: return "Application Windows"
    case .showDesktop: return "Show Desktop"
    case .launchpad: return "Launchpad"
    case .spaceLeft: return "Move Left a Space"
    case .spaceRight: return "Move Right a Space"
    case .spotlight: return "Spotlight"
    case .screenshotRegion: return "Screenshot Selection"
    case .lockScreen: return "Lock Screen"
    case .volumeUp: return "Volume Up"
    case .volumeDown: return "Volume Down"
    case .mute: return "Mute"
    case .playPause: return "Play / Pause"
    case .nextTrack: return "Next Track"
    case .previousTrack: return "Previous Track"
    case .copy: return "Copy"
    case .paste: return "Paste"
    case .undo: return "Undo"
    case .redo: return "Redo"
    case .selectAll: return "Select All"
    case .newTab: return "New Tab"
    case .closeTab: return "Close Tab"
    case .emojiPicker: return "Emoji & Symbols"
    case .switchApplication: return "Switch Application"
    case .save: return "Save"
    case .find: return "Find"
    case .print: return "Print"
    case .zoomIn: return "Zoom In"
    case .zoomOut: return "Zoom Out"
    case .actualSize: return "Actual Size"
    case .reopenClosedTab: return "Reopen Closed Tab"
    case .minimizeWindow: return "Minimize Window"
    case .hideApplication: return "Hide Application"
    case .forwardClick: return "Forward"
    case .backClick: return "Back"
    case .middleClick: return "Middle Click"
    }
  }

  /// Grouping used to break the action list into labelled sections. A flat list of
  /// every case is taller than the window and unreadable at a glance.
  public enum Category: String, CaseIterable, Sendable {
    case spacesAndWindows = "Spaces & Windows"
    case system = "System"
    case media = "Media"
    case editing = "Editing"
    case tabsAndView = "Tabs & View"
    case mouse = "Mouse Buttons"
  }

  public var category: Category {
    switch self {
    case .none, .missionControl, .applicationWindows, .showDesktop, .launchpad,
         .spaceLeft, .spaceRight, .switchApplication, .minimizeWindow, .hideApplication:
      return .spacesAndWindows
    case .spotlight, .screenshotRegion, .lockScreen, .emojiPicker:
      return .system
    case .volumeUp, .volumeDown, .mute, .playPause, .nextTrack, .previousTrack:
      return .media
    case .copy, .paste, .undo, .redo, .selectAll, .save, .find, .print:
      return .editing
    case .newTab, .closeTab, .reopenClosedTab, .zoomIn, .zoomOut, .actualSize:
      return .tabsAndView
    case .forwardClick, .backClick, .middleClick:
      return .mouse
    }
  }

  /// Selectable actions grouped for display, in a stable order. `.none` is excluded
  /// because callers present it separately.
  public static func grouped() -> [(category: Category, actions: [MacAction])] {
    Category.allCases.compactMap { category in
      let actions = MacAction.allCases.filter { $0 != .none && $0.category == category }
      return actions.isEmpty ? nil : (category, actions)
    }
  }

  private enum Key {
    static let upArrow: CGKeyCode = 0x7E
    static let downArrow: CGKeyCode = 0x7D
    static let leftArrow: CGKeyCode = 0x7B
    static let rightArrow: CGKeyCode = 0x7C
    static let space: CGKeyCode = 0x31
    static let q: CGKeyCode = 0x0C
    static let four: CGKeyCode = 0x15
    static let f11: CGKeyCode = 0x67
    static let a: CGKeyCode = 0x00
    static let c: CGKeyCode = 0x08
    static let t: CGKeyCode = 0x11
    static let v: CGKeyCode = 0x09
    static let w: CGKeyCode = 0x0D
    static let z: CGKeyCode = 0x06
    static let tab: CGKeyCode = 0x30
    static let f: CGKeyCode = 0x03
    static let h: CGKeyCode = 0x04
    static let m: CGKeyCode = 0x2E
    static let p: CGKeyCode = 0x23
    static let s: CGKeyCode = 0x01
    static let zero: CGKeyCode = 0x1D
    static let minus: CGKeyCode = 0x1B
    static let equal: CGKeyCode = 0x18
  }

  public var keystroke: (key: CGKeyCode, flags: CGEventFlags)? {
    switch self {
    case .missionControl: return (Key.upArrow, .maskControl)
    case .applicationWindows: return (Key.downArrow, .maskControl)
    case .spaceLeft: return (Key.leftArrow, .maskControl)
    case .spaceRight: return (Key.rightArrow, .maskControl)
    case .showDesktop: return (Key.f11, .maskSecondaryFn)
    case .spotlight: return (Key.space, .maskCommand)
    case .screenshotRegion: return (Key.four, [.maskCommand, .maskShift])
    case .lockScreen: return (Key.q, [.maskControl, .maskCommand])
    case .copy: return (Key.c, .maskCommand)
    case .paste: return (Key.v, .maskCommand)
    case .undo: return (Key.z, .maskCommand)
    case .redo: return (Key.z, [.maskCommand, .maskShift])
    case .selectAll: return (Key.a, .maskCommand)
    case .newTab: return (Key.t, .maskCommand)
    case .closeTab: return (Key.w, .maskCommand)
    case .emojiPicker: return (Key.space, [.maskControl, .maskCommand])
    case .switchApplication: return (Key.tab, .maskCommand)
    case .save: return (Key.s, .maskCommand)
    case .find: return (Key.f, .maskCommand)
    case .print: return (Key.p, .maskCommand)
    case .zoomIn: return (Key.equal, [.maskCommand, .maskShift])
    case .zoomOut: return (Key.minus, .maskCommand)
    case .actualSize: return (Key.zero, .maskCommand)
    case .reopenClosedTab: return (Key.t, [.maskCommand, .maskShift])
    case .minimizeWindow: return (Key.m, .maskCommand)
    case .hideApplication: return (Key.h, .maskCommand)
    default: return nil
    }
  }

  public var mediaKey: Int32? {
    switch self {
    case .volumeUp: return 0
    case .volumeDown: return 1
    case .mute: return 7
    case .playPause: return 16
    case .nextTrack: return 17
    case .previousTrack: return 18
    default: return nil
    }
  }

  public var mouseButton: CGMouseButton? {
    switch self {
    case .backClick: return CGMouseButton(rawValue: 3)
    case .forwardClick: return CGMouseButton(rawValue: 4)
    case .middleClick: return .center
    default: return nil
    }
  }

  public var launchesApplication: String? {
    switch self {
    case .missionControl: return "/System/Applications/Mission Control.app"
    case .spotlight: return "/System/Library/CoreServices/Spotlight.app"
    default: return nil
    }
  }

  public var dockNotification: String? {
    switch self {
    case .missionControl: return "com.apple.expose.awake"
    case .applicationWindows: return "com.apple.expose.front.awake"
    case .showDesktop: return "com.apple.showdesktop.awake"
    case .launchpad: return "com.apple.launchpad.toggle"
    default: return nil
    }
  }

  public var executableAction: (path: String, arguments: [String])? {
    switch self {
    case .screenshotRegion: return ("/usr/sbin/screencapture", ["-i"])
    default: return nil
    }
  }

  public var requiresSystemShortcut: Bool {
    symbolicHotkeyID != nil && dockNotification == nil
      && launchesApplication == nil && executableAction == nil
  }

  public var symbolicHotkeyID: Int? {
    switch self {
    case .applicationWindows: return 33
    case .spaceLeft: return 79
    case .spaceRight: return 81
    case .showDesktop: return 36
    case .spotlight: return 64
    case .screenshotRegion: return 30
    default: return nil
    }
  }

  public var isDispatchable: Bool {
    keystroke != nil || mediaKey != nil || mouseButton != nil
      || launchesApplication != nil || dockNotification != nil
      || executableAction != nil
  }
}
