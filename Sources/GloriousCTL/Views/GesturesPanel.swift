import GloriousCore
import GloriousUI
import SwiftUI

struct GesturesPanel: View {
  @EnvironmentObject private var controller: DeviceController
  @State private var expandedButton: PhysicalButton?

  private var gestureButtons: [PhysicalButton] { [.back, .forward, .middle] }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      if !controller.gestures.hasAccessibilityPermission {
        permissionGate
      } else {
        ForEach(gestureButtons, id: \.self) { button in
          buttonSection(button)
        }

        unavailableShortcutWarning

        if let last = controller.gestures.lastGesture {
          Text(last)
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(Theme.accent)
            .lineLimit(2)
        }

        Text(
          "Hold the button, drag, and release. A click without dragging keeps its normal action."
        )
        .font(.system(size: 9)).foregroundStyle(Theme.textDim)
        .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  @ViewBuilder
  private var unavailableShortcutWarning: some View {
    let bound = controller.gestures.bindings.values
      .filter(\.enabled)
      .flatMap { binding in GestureDirection.allCases.map { binding.action(for: $0) } }
    let broken = Array(Set(SystemShortcuts.unavailableActions(in: bound)))
      .sorted { $0.displayName < $1.displayName }

    if !broken.isEmpty {
      VStack(alignment: .leading, spacing: 5) {
        Label(
          "Some actions have no keyboard shortcut assigned",
          systemImage: "exclamationmark.triangle.fill"
        )
        .font(.system(size: 10)).foregroundStyle(Theme.accent)
        Text(broken.map(\.displayName).joined(separator: ", "))
          .font(.system(size: 9)).foregroundStyle(Theme.text)
        Text(
          """
          macOS performs these through a keyboard shortcut, and yours are switched \
          on but have no key set — so the action does nothing and the Mac beeps. \
          Assign them under \(SystemShortcuts.settingsHint), or pick a different \
          action. Mission Control and Launchpad do not need a shortcut.
          """
        )
        .font(.system(size: 9)).foregroundStyle(Theme.textDim)
        .fixedSize(horizontal: false, vertical: true)
        Button("Open Keyboard Shortcuts") {
          NSWorkspace.shared.open(
            URL(
              string:
                "x-apple.systempreferences:com.apple.preference.keyboard?Shortcuts")!)
        }
        .buttonStyle(PlateButtonStyle(wide: false))
      }
      .padding(9)
      .background(
        RoundedRectangle(cornerRadius: Theme.corner)
          .fill(Theme.accent.opacity(0.10)))
    }
  }

  private var permissionGate: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Accessibility permission needed", systemImage: "hand.raised")
        .font(.system(size: 11)).foregroundStyle(Theme.accent)
      Text(
        """
        Gestures work by claiming the button before other apps see it, which macOS \
        gates behind Accessibility. This is separate from the Input Monitoring grant \
        the mouse itself needs.
        """
      )
      .font(.system(size: 9)).foregroundStyle(Theme.textDim)
      .fixedSize(horizontal: false, vertical: true)
      HStack(spacing: 6) {
        Button("Grant…") { controller.gestures.requestPermission() }
          .buttonStyle(PlateButtonStyle(wide: false, accented: true))
        Button("Open Settings") { controller.gestures.openAccessibilitySettings() }
          .buttonStyle(PlateButtonStyle(wide: false))
        Button("Recheck") {
          if controller.gestures.refreshPermission() { controller.saveGestureBindings() }
        }
        .buttonStyle(PlateButtonStyle(wide: false))
      }
    }
  }

  @ViewBuilder
  private func buttonSection(_ button: PhysicalButton) -> some View {
    let binding =
      controller.gestures.bindings[button]
      ?? GestureBinding.defaultBinding(for: button)

    VStack(alignment: .leading, spacing: 6) {
      HStack {
        AmberCheck(
          isOn: Binding(
            get: { binding.enabled },
            set: { on in
              var updated = binding
              updated.enabled = on
              controller.updateGesture(updated)
              if on { expandedButton = button }
            }), label: button.displayName)
        Spacer()
        if binding.enabled {
          Button(expandedButton == button ? "Hide" : "Edit") {
            expandedButton = expandedButton == button ? nil : button
          }
          .buttonStyle(PlateButtonStyle(wide: false))
        }
      }

      if binding.enabled && controller.gestureNeedsDeviceRemap(button) {
        HStack(alignment: .top, spacing: 6) {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 9)).foregroundStyle(Theme.accent)
          VStack(alignment: .leading, spacing: 4) {
            Text(
              """
              This button currently sends a keystroke, which gestures cannot \
              intercept. It needs to send a plain mouse button.
              """
            )
            .font(.system(size: 9)).foregroundStyle(Theme.textDim)
            .fixedSize(horizontal: false, vertical: true)
            Button("Fix and Apply") {
              controller.prepareButtonForGestures(button)
              controller.applyToDevice()
            }
            .buttonStyle(PlateButtonStyle(wide: false, accented: true))
          }
        }
      }

      if binding.enabled && expandedButton == button {
        ForEach(GestureDirection.allCases, id: \.self) { direction in
          HStack(spacing: 6) {
            Image(systemName: direction.symbolName)
              .font(.system(size: 9)).foregroundStyle(Theme.accent)
              .frame(width: 14)
            Text(direction.displayName)
              .font(.system(size: 9)).foregroundStyle(Theme.textDim)
              .frame(width: 78, alignment: .leading)
            MacActionMenu(
              selection: Binding(
                get: { binding.action(for: direction) },
                set: { action in
                  var updated = binding
                  updated.actions[direction] = action
                  controller.updateGesture(updated)
                }))
          }
        }
      }
    }
    .padding(.vertical, 3)
    .overlay(alignment: .bottom) { Divider().overlay(Theme.border.opacity(0.5)) }
  }
}

struct AutoSwitchPanel: View {
  @EnvironmentObject private var controller: DeviceController

  var body: some View {
    VStack(alignment: .leading, spacing: 9) {
      Toggle(
        isOn: Binding(
          get: { controller.appSwitcher.isEnabled },
          set: { on in
            controller.appSwitcher.isEnabled = on
            if on { controller.appSwitcher.start() } else { controller.appSwitcher.stop() }
          })
      ) {
        Text("Switch profile with the frontmost app")
          .font(.system(size: 10))
      }
      .toggleStyle(.switch)
      .controlSize(.mini)

      if let bundle = controller.appSwitcher.currentBundleID {
        Text("Front: \(bundle)")
          .font(.system(size: 9, design: .monospaced))
          .foregroundStyle(Theme.textDim).lineLimit(1)
      }
      if let applied = controller.appSwitcher.lastApplied {
        Text("Applied: \(applied)")
          .font(.system(size: 9)).foregroundStyle(Theme.accent)
      }

      if controller.profiles.isEmpty {
        Text("Save a profile first, then assign it to an app in the Profiles sheet.")
          .font(.system(size: 9)).foregroundStyle(Theme.textDim)
          .fixedSize(horizontal: false, vertical: true)
      } else {
        ForEach(controller.profiles) { profile in
          HStack(spacing: 6) {
            Text(profile.name).font(.system(size: 9)).lineLimit(1)
              .frame(width: 74, alignment: .leading)
            Text(profile.autoSwitchBundleID ?? "default for other apps")
              .font(.system(size: 9, design: .monospaced))
              .foregroundStyle(Theme.textDim).lineLimit(1)
            Spacer()
            Button("Set…") { assignFrontmost(to: profile) }
              .buttonStyle(PlateButtonStyle(wide: false))
          }
        }
        Text("“Set” assigns the app that was in front before GloriousCTL.")
          .font(.system(size: 9)).foregroundStyle(Theme.textDim)
          .fixedSize(horizontal: false, vertical: true)
      }

      Text(
        "Profiles are written to the mouse, so switching is debounced and skipped when the device already matches."
      )
      .font(.system(size: 9)).foregroundStyle(Theme.textDim)
      .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func assignFrontmost(to profile: Profile) {
    let candidate = NSWorkspace.shared.runningApplications
      .filter {
        $0.activationPolicy == .regular
          && $0.bundleIdentifier != Bundle.main.bundleIdentifier
      }
      .sorted { ($0.isActive ? 1 : 0) > ($1.isActive ? 1 : 0) }
      .first?.bundleIdentifier
    controller.setAutoSwitchBundleID(candidate, for: profile)
  }
}
