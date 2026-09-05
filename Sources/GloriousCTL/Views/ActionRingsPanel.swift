import AppKit
import GloriousCore
import GloriousUI
import SwiftUI

struct ActionRingsPanel: View {
  @EnvironmentObject private var controller: DeviceController
  @State private var expandedButton: PhysicalButton? = .middle

  private let ringButtons: [PhysicalButton] = [.middle, .back, .forward]

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      if !controller.gestures.hasAccessibilityPermission {
        permissionGate
      }

      ForEach(ringButtons, id: \.self) { button in
        ringSection(button)
      }

      Text(
        "Quick press keeps the normal click. Hold to open, drag toward a bubble, then release to run it. Releasing in the centre cancels and closes the ring."
      )
      .font(.system(size: 9)).foregroundStyle(Theme.textDim)
      .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var permissionGate: some View {
    VStack(alignment: .leading, spacing: 7) {
      Label("Accessibility permission needed", systemImage: "hand.raised")
        .font(.system(size: 10)).foregroundStyle(Theme.accent)
      Text(
        "Action rings intercept a held mouse button, so macOS requires Accessibility permission."
      )
      .font(.system(size: 9)).foregroundStyle(Theme.textDim)
      .fixedSize(horizontal: false, vertical: true)
      HStack(spacing: 6) {
        Button("Grant…") { controller.gestures.requestPermission() }
          .buttonStyle(PlateButtonStyle(wide: false, accented: true))
        Button("Recheck") {
          if controller.gestures.refreshPermission() { controller.saveGestureBindings() }
        }
        .buttonStyle(PlateButtonStyle(wide: false))
      }
    }
    .padding(8)
    .background(
      RoundedRectangle(cornerRadius: Theme.corner)
        .fill(Theme.accent.opacity(0.10)))
  }

  @ViewBuilder
  private func ringSection(_ button: PhysicalButton) -> some View {
    let ring = configuration(for: button)
    VStack(alignment: .leading, spacing: 7) {
      HStack {
        AmberCheck(
          isOn: Binding(
            get: { ring.enabled },
            set: { enabled in update(button) { $0.enabled = enabled } }),
          label: button.displayName)
        Spacer()
        Button(expandedButton == button ? "Hide" : "Edit") {
          expandedButton = expandedButton == button ? nil : button
        }
        .buttonStyle(PlateButtonStyle(wide: false))
      }

      if ring.enabled && controller.gestureNeedsDeviceRemap(button) {
        VStack(alignment: .leading, spacing: 5) {
          Label(
            "Button must send a plain mouse click", systemImage: "exclamationmark.triangle.fill"
          )
          .font(.system(size: 9)).foregroundStyle(Theme.accent)
          Button("Fix and Apply") {
            controller.prepareButtonForGestures(button)
            controller.applyToDevice()
          }
          .buttonStyle(PlateButtonStyle(wide: false, accented: true))
        }
      }

      if expandedButton == button {
        HStack(spacing: 6) {
          Text("Strength")
            .font(.system(size: 9)).foregroundStyle(Theme.textDim)
          Slider(
            value: Binding(
              get: { ring.holdDuration },
              set: { value in update(button) { $0.holdDuration = value } }),
            in: 0.35...1.2, step: 0.05)
          Text(holdStrengthName(ring.holdDuration))
            .font(.system(size: 8))
            .foregroundStyle(Theme.text).frame(width: 46, alignment: .trailing)
            .help(String(format: "Hold for %.2f seconds to open the ring", ring.holdDuration))
        }

        ForEach(ring.items) { item in
          itemEditor(button: button, itemID: item.id)
        }

        HStack {
          Button("Add Item") {
            update(button) { ring in
              guard ring.items.count < 8 else { return }
              ring.items.append(ActionRingItem())
            }
          }
          .buttonStyle(PlateButtonStyle(wide: false))
          .disabled(ring.items.count >= 8)
          Spacer()
          Text("\(ring.items.count)/8")
            .font(.system(size: 8, design: .monospaced))
            .foregroundStyle(Theme.textDim)
        }
      }
    }
    .padding(.vertical, 3)
    .overlay(alignment: .bottom) { Divider().overlay(Theme.border.opacity(0.5)) }
  }

  /// The slider sets how long the button must be held before the ring opens. Users
  /// think of that as how firm the press has to be, not as a number of seconds, so it
  /// reads as a strength; the exact duration stays available as a tooltip.
  private func holdStrengthName(_ duration: Double) -> String {
    switch duration {
    case ..<0.5: return "Lightest"
    case ..<0.7: return "Light"
    case ..<0.9: return "Medium"
    case ..<1.1: return "Firm"
    default: return "Firmest"
    }
  }

  @ViewBuilder
  private func itemEditor(button: PhysicalButton, itemID: UUID) -> some View {
    if let item = configuration(for: button).items.first(where: { $0.id == itemID }) {
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 5) {
          Image(systemName: item.action.symbolName)
            .font(.system(size: 9)).foregroundStyle(Theme.accent)
            .frame(width: 13)
          ringActionMenu(button: button, itemID: itemID)

          Button {
            update(button) { ring in
              ring.items.removeAll { $0.id == itemID }
            }
          } label: {
            Image(systemName: "trash")
          }
          .buttonStyle(PlateButtonStyle(wide: false))
          .disabled(configuration(for: button).items.count <= 1)
        }

        TextField("Ring label (optional)", text: itemTitleBinding(button: button, itemID: itemID))
          .textFieldStyle(.roundedBorder).controlSize(.mini)

        customValueEditor(button: button, itemID: itemID, action: item.action)
      }
      .padding(6)
      .background(
        RoundedRectangle(cornerRadius: Theme.corner)
          .fill(Color.white.opacity(0.035)))
    }
  }

  @ViewBuilder
  private func customValueEditor(
    button: PhysicalButton, itemID: UUID,
    action: RingAction
  ) -> some View {
    switch action {
    case .open(let path):
      HStack(spacing: 5) {
        Text(path.isEmpty ? "No app or file selected" : path)
          .font(.system(size: 8, design: .monospaced))
          .foregroundStyle(Theme.textDim).lineLimit(1)
        Spacer()
        Button("Choose…") { choosePath(button: button, itemID: itemID) }
          .buttonStyle(PlateButtonStyle(wide: false))
      }
    case .openURL:
      TextField(
        "https://example.com",
        text: customStringBinding(
          button: button, itemID: itemID, kind: .url)
      )
      .textFieldStyle(.roundedBorder).controlSize(.mini)
    case .runShortcut:
      TextField(
        "Exact name from the Shortcuts app",
        text: customStringBinding(
          button: button, itemID: itemID, kind: .shortcut)
      )
      .textFieldStyle(.roundedBorder).controlSize(.mini)
    default:
      EmptyView()
    }
  }

  private func configuration(for button: PhysicalButton) -> ActionRingConfiguration {
    controller.gestures.rings[button]
      ?? ActionRingConfiguration.defaultConfiguration(for: button)
  }

  private func update(
    _ button: PhysicalButton,
    _ change: (inout ActionRingConfiguration) -> Void
  ) {
    var ring = configuration(for: button)
    change(&ring)
    controller.updateActionRing(ring)
  }

  private func updateItem(
    _ button: PhysicalButton, id: UUID,
    _ change: (inout ActionRingItem) -> Void
  ) {
    update(button) { ring in
      guard let index = ring.items.firstIndex(where: { $0.id == id }) else { return }
      change(&ring.items[index])
    }
  }

  private func itemTitleBinding(button: PhysicalButton, itemID: UUID) -> Binding<String> {
    Binding(
      get: { configuration(for: button).items.first(where: { $0.id == itemID })?.title ?? "" },
      set: { value in updateItem(button, id: itemID) { $0.title = value } })
  }

  private enum ActionChoice: Hashable {
    case none
    case system(MacAction)
    case open, url, shortcut
  }

  /// Ring slots additionally offer the custom open / URL / shortcut choices, so the
  /// menu is built here rather than reusing `MacActionMenu`.
  @ViewBuilder
  private func ringActionMenu(button: PhysicalButton, itemID: UUID) -> some View {
    let choice = actionChoiceBinding(button: button, itemID: itemID)
    Menu {
      actionMenuItem("Do Nothing", isSelected: choice.wrappedValue == .none) {
        choice.wrappedValue = .none
      }
      Divider()
      ForEach(MacAction.grouped(), id: \.category) { group in
        Menu {
          ForEach(group.actions, id: \.self) { action in
            actionMenuItem(
              action.displayName, isSelected: choice.wrappedValue == .system(action)
            ) {
              choice.wrappedValue = .system(action)
            }
          }
        } label: {
          Label(group.category.rawValue, systemImage: group.category.symbolName)
        }
      }
      Divider()
      Menu {
        actionMenuItem("Open App or File…", isSelected: choice.wrappedValue == .open) {
          choice.wrappedValue = .open
        }
        actionMenuItem("Open URL…", isSelected: choice.wrappedValue == .url) {
          choice.wrappedValue = .url
        }
        actionMenuItem(
          "Run macOS Shortcut…", isSelected: choice.wrappedValue == .shortcut
        ) {
          choice.wrappedValue = .shortcut
        }
      } label: {
        Label("Custom…", systemImage: "arrow.up.forward.app")
      }
    } label: {
      Text(ringActionTitle(choice.wrappedValue))
        .font(.system(size: 10))
        .lineLimit(1)
        .truncationMode(.middle)
    }
    .controlSize(.small)
    .frame(width: 152)
  }

  private func ringActionTitle(_ choice: ActionChoice) -> String {
    switch choice {
    case .none: return "Do Nothing"
    case .system(let action): return action.displayName
    case .open: return "Open App or File…"
    case .url: return "Open URL…"
    case .shortcut: return "Run macOS Shortcut…"
    }
  }

  private func actionChoiceBinding(button: PhysicalButton, itemID: UUID) -> Binding<ActionChoice> {
    Binding(
      get: {
        guard
          let action = configuration(for: button).items
            .first(where: { $0.id == itemID })?.action
        else { return .none }
        switch action {
        case .none: return .none
        case .system(let action): return .system(action)
        case .open: return .open
        case .openURL: return .url
        case .runShortcut: return .shortcut
        }
      },
      set: { choice in
        switch choice {
        case .none:
          updateItem(button, id: itemID) { $0.action = .none }
        case .system(let action):
          updateItem(button, id: itemID) { $0.action = .system(action) }
        case .open:
          updateItem(button, id: itemID) { $0.action = .open(path: "") }
          choosePath(button: button, itemID: itemID)
        case .url:
          updateItem(button, id: itemID) { $0.action = .openURL("") }
        case .shortcut:
          updateItem(button, id: itemID) { $0.action = .runShortcut(name: "") }
        }
      })
  }

  private enum CustomStringKind { case url, shortcut }

  private func customStringBinding(
    button: PhysicalButton, itemID: UUID,
    kind: CustomStringKind
  ) -> Binding<String> {
    Binding(
      get: {
        guard
          let action = configuration(for: button).items
            .first(where: { $0.id == itemID })?.action
        else { return "" }
        switch action {
        case .openURL(let value) where kind == .url: return value
        case .runShortcut(let name) where kind == .shortcut: return name
        default: return ""
        }
      },
      set: { value in
        updateItem(button, id: itemID) { item in
          item.action = kind == .url ? .openURL(value) : .runShortcut(name: value)
        }
      })
  }

  private func choosePath(button: PhysicalButton, itemID: UUID) {
    let panel = NSOpenPanel()
    panel.message = "Choose an application, file, or folder for this ring item."
    panel.canChooseFiles = true
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    updateItem(button, id: itemID) { item in
      item.action = .open(path: url.path)
      if item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        item.title = url.deletingPathExtension().lastPathComponent
      }
    }
  }
}
