import GloriousCore
import GloriousUI
import SwiftUI

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
