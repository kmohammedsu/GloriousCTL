import GloriousCore
import GloriousUI
import SwiftUI

struct ActionPicker: View {
  let button: PhysicalButton

  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var controller: DeviceController
  @State private var keyCode: UInt8 = 0x04
  @State private var modifiers: KeyModifiers = []
  @State private var macroRepeats = 1

  private var currentAction: ButtonAction {
    controller.workingConfig?.action(for: button) ?? button.factoryDefault
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text("Assign \(button.displayName)").font(.title2.weight(.semibold))
          Text("Current: \(currentAction.displayName)").foregroundStyle(.secondary)
        }
        Spacer()
        Button("Done") { dismiss() }
          .keyboardShortcut(.defaultAction)
      }
      .padding(20)

      Divider()

      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          actionGroup(
            "Mouse",
            actions: MouseButtonCode.allCases.map {
              ($0.displayName, ButtonAction.mouseButton($0))
            })
          actionGroup(
            "Media",
            actions: MediaKeyCode.allCases.map {
              ($0.displayName, ButtonAction.media($0))
            })
          actionGroup(
            "DPI",
            actions: DPIActionCode.allCases.map {
              ($0.displayName, ButtonAction.dpiAction($0))
            })
          actionGroup(
            "Scrolling",
            actions: [
              ("Scroll Up", .scrollUp),
              ("Scroll Down", .scrollDown),
            ])
          keyboardEditor
          macroEditor
          actionGroup(
            "Other",
            actions: [
              ("Disabled", .disabled),
              ("Factory Default", button.factoryDefault),
            ])
        }
        .padding(20)
      }
    }
    .frame(width: 560, height: 650)
    .preferredColorScheme(.dark)
    .onAppear { loadCurrentKeyboardAction() }
  }

  private func actionGroup(_ title: String, actions: [(String, ButtonAction)]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title.uppercased())
        .font(.caption.weight(.bold))
        .foregroundStyle(Theme.textDim)
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
        ForEach(Array(actions.enumerated()), id: \.offset) { _, item in
          actionButton(item.0, action: item.1)
        }
      }
    }
  }

  private var keyboardEditor: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("KEYBOARD SHORTCUT")
        .font(.caption.weight(.bold))
        .foregroundStyle(Theme.textDim)
      HStack {
        modifierToggle("⌃", modifier: .leftControl)
        modifierToggle("⌥", modifier: .leftOption)
        modifierToggle("⇧", modifier: .leftShift)
        modifierToggle("⌘", modifier: .leftCommand)
        Picker("Key", selection: $keyCode) {
          ForEach(HIDKeyboard.usages, id: \.code) { key in
            Text(key.name).tag(key.code)
          }
        }
        .labelsHidden()
        .frame(maxWidth: .infinity)
        Button("Assign") {
          apply(.keyboard(modifiers: modifiers, keyCode: keyCode))
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.accent)
      }
    }
  }

  private var macroEditor: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("MACROS")
        .font(.caption.weight(.bold))
        .foregroundStyle(Theme.textDim)
      if controller.macros.isEmpty {
        Text("Create a macro in the Macro Editor first.")
          .font(.callout)
          .foregroundStyle(.secondary)
      } else {
        HStack {
          Stepper("Repeat \(macroRepeats)×", value: $macroRepeats, in: 1...255)
          Spacer()
        }
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
          ForEach(controller.macros) { macro in
            actionButton(
              macro.name,
              action: .macro(slot: macro.slot, repeatCount: UInt8(macroRepeats))
            )
          }
        }
      }
    }
  }

  private func actionButton(_ title: String, action: ButtonAction) -> some View {
    Button {
      apply(action)
    } label: {
      HStack {
        Text(title).lineLimit(1)
        Spacer()
        if currentAction == action { Image(systemName: "checkmark") }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .buttonStyle(.bordered)
    .tint(currentAction == action ? Theme.accent : Theme.textDim)
  }

  private func modifierToggle(_ title: String, modifier: KeyModifiers) -> some View {
    Button(title) {
      if modifiers.contains(modifier) {
        modifiers.remove(modifier)
      } else {
        modifiers.insert(modifier)
      }
    }
    .buttonStyle(.bordered)
    .tint(modifiers.contains(modifier) ? Theme.accent : Theme.textDim)
  }

  private func loadCurrentKeyboardAction() {
    guard case .keyboard(let currentModifiers, let currentKeyCode) = currentAction else { return }
    modifiers = currentModifiers
    keyCode = currentKeyCode
  }

  private func apply(_ action: ButtonAction) {
    controller.edit { $0.setAction(action, for: button) }
  }
}
