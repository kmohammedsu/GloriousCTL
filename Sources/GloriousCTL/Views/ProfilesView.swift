import GloriousCore
import GloriousUI
import SwiftUI
import UniformTypeIdentifiers

struct ProfilesView: View {
  @EnvironmentObject private var controller: DeviceController
  @State private var newProfileName = ""
  @State private var showingNameSheet = false
  @State private var renaming: Profile?
  @State private var renameText = ""

  var body: some View {
    VStack(spacing: 0) {
      if controller.profiles.isEmpty {
        emptyState
      } else {
        List {
          ForEach(controller.profiles) { profile in
            ProfileRow(
              profile: profile,
              onApply: { controller.apply(profile: $0) },
              onUpdate: { controller.updateProfileFromCurrent($0) },
              onRename: {
                renaming = $0
                renameText = $0.name
              },
              onDelete: { controller.deleteProfile($0) })
          }
        }
      }

      Divider()

      HStack {
        Button {
          newProfileName = "Profile \(controller.profiles.count + 1)"
          showingNameSheet = true
        } label: {
          Label("Save Current as Profile", systemImage: "plus")
        }
        .disabled(controller.workingConfig == nil)

        Spacer()

        Button("Restore Original Config") { controller.restoreOriginal() }
          .help("Write back the very first configuration this app read from the mouse")
      }
      .padding(12)
    }
    .navigationTitle("Profiles")
    .sheet(isPresented: $showingNameSheet) {
      NameSheet(title: "Save Profile", text: $newProfileName) {
        controller.saveCurrentAsProfile(named: newProfileName)
      }
    }
    .sheet(item: $renaming) { profile in
      NameSheet(title: "Rename Profile", text: $renameText) {
        controller.renameProfile(profile, to: renameText)
      }
    }
  }

  private var emptyState: some View {
    VStack(spacing: 10) {
      Image(systemName: "square.stack.3d.up")
        .font(.system(size: 34)).foregroundStyle(.tertiary)
      Text("No profiles yet").font(.headline)
      Text(
        """
        The mouse holds one configuration onboard. Profiles live on the Mac, so you \
        can keep a set for gaming, another for work, and switch whenever you like.
        """
      )
      .font(.callout).foregroundStyle(.secondary)
      .multilineTextAlignment(.center)
      .frame(maxWidth: 420)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(40)
  }
}

struct ProfileRow: View {
  let profile: Profile
  let onApply: (Profile) -> Void
  let onUpdate: (Profile) -> Void
  let onRename: (Profile) -> Void
  let onDelete: (Profile) -> Void

  var body: some View {
    let config = profile.config
    HStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 3) {
        Text(profile.name).font(.body.weight(.medium))
        Text(
          "\(config.dpi(atStage: config.activeDPIStage - 1)) DPI · "
            + "\(config.dpiStageCount) stages · "
            + config.lightingEffect.displayName
        )
        .font(.caption).foregroundStyle(.secondary)
      }

      Spacer()

      Text(profile.modifiedAt, format: .dateTime.day().month().hour().minute())
        .font(.caption).foregroundStyle(.tertiary)

      Button("Load") { onApply(profile) }
      Menu {
        Button("Overwrite with Current Settings") { onUpdate(profile) }
        Button("Rename…") { onRename(profile) }
        Divider()
        Button("Delete", role: .destructive) { onDelete(profile) }
      } label: {
        Image(systemName: "ellipsis.circle")
      }
      .menuStyle(.borderlessButton)
      .fixedSize()
    }
    .padding(.vertical, 3)
  }
}

struct NameSheet: View {
  let title: String
  @Binding var text: String
  let onConfirm: () -> Void
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(title).font(.headline)
      TextField("Name", text: $text)
        .textFieldStyle(.roundedBorder)
        .frame(width: 280)
      HStack {
        Spacer()
        Button("Cancel") { dismiss() }
        Button("Save") {
          onConfirm()
          dismiss()
        }
        .buttonStyle(.borderedProminent)
        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
      }
    }
    .padding(20)
  }
}
