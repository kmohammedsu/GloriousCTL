import AppKit
import GloriousCore
import GloriousUI
import SwiftUI

struct MainWindow: View {
  @EnvironmentObject private var controller: DeviceController

  @State private var control: ControlArea = .buttons
  @State private var selectedButton: PhysicalButton? = .middle
  @State private var editingButton: PhysicalButton?
  @State private var showingMacroEditor = false
  @State private var showingInspector = false
  @State private var showingProfiles = false

  private var config: MouseConfig? { controller.workingConfig }
  private static let appIcon: NSImage = {
    guard let url = Bundle.module.url(forResource: "app-icon", withExtension: "png"),
      let image = NSImage(contentsOf: url)
    else { return NSImage() }
    return image
  }()

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [Theme.background, Color(red: 0.035, green: 0.04, blue: 0.05)],
        startPoint: .topLeading, endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      VStack(spacing: 0) {
        header

        if controller.state.isConnected, let config {
          HStack(spacing: 14) {
            navigationRail.frame(width: 190)
            deviceStage(config).frame(maxWidth: .infinity, maxHeight: .infinity)
            editor(config).frame(width: 340)
          }
          .padding(.horizontal, 18)
          .padding(.bottom, 12)

          bottomBar
        } else {
          ConnectionPlaceholder()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
    }
    .preferredColorScheme(.dark)
    .foregroundStyle(Theme.text)
    .frame(width: 1180, height: 760)
    .sheet(item: $editingButton) { button in
      ActionPicker(button: button).environmentObject(controller)
    }
    .sheet(isPresented: $showingMacroEditor) {
      MacroEditorSheet().environmentObject(controller)
    }
    .sheet(isPresented: $showingInspector) {
      InspectorSheet().environmentObject(controller)
    }
    .sheet(isPresented: $showingProfiles) {
      ProfilesSheet().environmentObject(controller)
    }
  }

  private var header: some View {
    HStack(spacing: 12) {
      Image(nsImage: Self.appIcon)
        .resizable()
        .interpolation(.high)
        .frame(width: 42, height: 42)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: Theme.accent.opacity(0.20), radius: 12)

      VStack(alignment: .leading, spacing: 2) {
        Text("GloriousCTL")
          .font(.system(size: 18, weight: .bold, design: .rounded))
          .foregroundStyle(Theme.text)
        Text("MODEL O CONTROL CENTER")
          .font(.system(size: 9, weight: .semibold))
          .tracking(1.6)
          .foregroundStyle(Theme.textDim)
      }

      Spacer()
      connectionPill
      Button {
        showingInspector = true
      } label: {
        Image(systemName: "waveform.badge.magnifyingglass")
      }
      .buttonStyle(PlateButtonStyle(wide: false))
      .help("Protocol Inspector")
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 13)
  }

  private var connectionPill: some View {
    HStack(spacing: 7) {
      Circle()
        .fill(controller.state.isConnected ? Color.green : Theme.textDim)
        .frame(width: 7, height: 7)
      Text(controller.state.isConnected ? "Model O connected" : "Disconnected")
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(Theme.text)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(Capsule().fill(Theme.panelRaised))
    .overlay(Capsule().strokeBorder(Theme.border))
  }

  private var navigationRail: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text("CONFIGURE")
        .font(.system(size: 9, weight: .bold))
        .tracking(1.5)
        .foregroundStyle(Theme.textDim)
        .padding(.horizontal, 10)
        .padding(.bottom, 4)

      ForEach(ControlArea.allCases) { item in
        Button {
          withAnimation(.easeOut(duration: 0.12)) { control = item }
        } label: {
          HStack(spacing: 10) {
            Image(systemName: item.symbol)
              .font(.system(size: 13, weight: .semibold))
              .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
              Text(item.title).font(.system(size: 11, weight: .semibold))
              Text(item.subtitle)
                .font(.system(size: 8))
                .foregroundStyle(control == item ? Color.black.opacity(0.55) : Theme.textDim)
                .lineLimit(1)
            }
            Spacer()
          }
          .foregroundStyle(control == item ? Color.black.opacity(0.82) : Theme.text)
          .padding(.horizontal, 10)
          .padding(.vertical, 9)
          .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
              .fill(control == item ? Theme.accent : Color.clear)
          )
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }

      Spacer()

      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Image(systemName: "square.stack.3d.up")
          Text("Profiles").font(.system(size: 11, weight: .semibold))
          Spacer()
          Image(systemName: "chevron.right").font(.system(size: 8))
        }
        Text(controller.profiles.first?.name ?? "No saved profile")
          .font(.system(size: 9))
          .foregroundStyle(Theme.textDim)
          .lineLimit(1)
      }
      .foregroundStyle(Theme.text)
      .padding(11)
      .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.panel))
      .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.border))
      .contentShape(Rectangle())
      .onTapGesture { showingProfiles = true }
    }
    .padding(.vertical, 12)
  }

  private func deviceStage(_ config: MouseConfig) -> some View {
    VStack(spacing: 8) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 3) {
          Text("Glorious Model O")
            .font(.system(size: 21, weight: .semibold, design: .rounded))
          Text("Select a numbered control to remap it")
            .font(.system(size: 10)).foregroundStyle(Theme.textDim)
        }
        Spacer()
        Label("Onboard memory", systemImage: "memorychip")
          .font(.system(size: 9, weight: .medium)).foregroundStyle(Theme.textDim)
      }

      PhotoMouseDiagram(actions: config.buttonMap, selected: selectedButton) { button in
        selectedButton = button
        control = .buttons
      }
      .frame(maxWidth: 500, maxHeight: .infinity)
      .padding(.horizontal, 6)

      buttonLegend(config)
    }
    .padding(18)
    .background(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(Theme.panel.opacity(0.78))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .strokeBorder(Theme.border))
  }

  private func buttonLegend(_ config: MouseConfig) -> some View {
    LazyVGrid(
      columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
      spacing: 6
    ) {
      ForEach(Array(PhysicalButton.allCases.enumerated()), id: \.element) { index, button in
        Button {
          selectedButton = button
          control = .buttons
        } label: {
          HStack(spacing: 7) {
            Text("\(index + 1)")
              .font(.system(size: 9, weight: .black, design: .rounded))
              .foregroundStyle(Color.black.opacity(0.8))
              .frame(width: 19, height: 19)
              .background(Circle().fill(selectedButton == button ? Theme.accent : Color.white))
            VStack(alignment: .leading, spacing: 1) {
              Text(button.displayName).font(.system(size: 9, weight: .semibold))
              Text(config.action(for: button).displayName)
                .font(.system(size: 8)).foregroundStyle(Theme.textDim).lineLimit(1)
            }
            Spacer(minLength: 0)
          }
          .foregroundStyle(Theme.text)
          .padding(7)
          .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .fill(selectedButton == button ? Theme.panelRaised : Color.clear)
          )
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
    }
  }

  private func editor(_ config: MouseConfig) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 9) {
        Image(systemName: control.symbol)
          .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.accent)
        VStack(alignment: .leading, spacing: 1) {
          Text(control.title).font(.system(size: 15, weight: .bold, design: .rounded))
          Text(control.editorDescription)
            .font(.system(size: 9)).foregroundStyle(Theme.textDim)
        }
        Spacer()
      }
      .padding(16)

      Divider().overlay(Theme.border)

      ScrollView {
        editorContent(config)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(16)
      }
      .scrollIndicators(.automatic)
    }
    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.panel))
    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.border))
  }

  @ViewBuilder
  private func editorContent(_ config: MouseConfig) -> some View {
    switch control {
    case .buttons: buttonEditor(config)
    case .dpi: DPISettingPanel(config: config)
    case .lighting: LightingPanel(config: config)
    case .rings: ActionRingsPanel()
    case .scrolling: ScrollingPanel()
    case .apps: AutoSwitchPanel()
    case .advanced: advancedEditor
    }
  }

  private func buttonEditor(_ config: MouseConfig) -> some View {
    let button = selectedButton ?? .middle
    let number = (PhysicalButton.allCases.firstIndex(of: button) ?? 0) + 1
    return VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 11) {
        Text("\(number)")
          .font(.system(size: 14, weight: .black, design: .rounded))
          .foregroundStyle(Color.black.opacity(0.85))
          .frame(width: 34, height: 34)
          .background(Circle().fill(Theme.accent))
        VStack(alignment: .leading, spacing: 2) {
          Text(button.displayName).font(.system(size: 14, weight: .semibold))
          Text("Physical control").font(.system(size: 9)).foregroundStyle(Theme.textDim)
        }
      }

      VStack(alignment: .leading, spacing: 5) {
        Text("CURRENT ACTION")
          .font(.system(size: 8, weight: .bold)).tracking(1.1).foregroundStyle(Theme.textDim)
        HStack {
          Image(systemName: "cursorarrow.click.2").foregroundStyle(Theme.accent)
          Text(config.action(for: button).displayName).font(.system(size: 12, weight: .medium))
          Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.panelRaised))
      }

      Button("Change assignment…") { editingButton = button }
        .buttonStyle(PlateButtonStyle(accented: true))

      if [.middle, .back, .forward].contains(button) {
        Divider().overlay(Theme.border)
        Text(
          "This control can also open an Actions Ring or trigger four directional gestures. A quick click keeps its normal assignment."
        )
        .font(.system(size: 10)).foregroundStyle(Theme.textDim)
        .fixedSize(horizontal: false, vertical: true)
        Button("Edit ring and drags") { control = .rings }
          .buttonStyle(PlateButtonStyle(wide: false))
      }

      Divider().overlay(Theme.border)
      Button("Macro editor…") { showingMacroEditor = true }
        .buttonStyle(PlateButtonStyle())
    }
  }

  private var advancedEditor: some View {
    VStack(alignment: .leading, spacing: 16) {
      UnmappedPanel(
        fields: ["Lift-off distance", "Debounce time", "Motion sync"],
        note: "These offsets are not safely decoded yet, so GloriousCTL leaves them untouched.")
      UnmappedPanel(
        fields: ["USB polling rate (125 / 250 / 500 / 1000 Hz)"],
        note:
          "The rate appears to live outside the known settings block. Use the inspector to help locate it without guessing writes."
      )
      Button("Open Protocol Inspector…") { showingInspector = true }
        .buttonStyle(PlateButtonStyle(accented: true))
    }
  }

  private var bottomBar: some View {
    HStack(spacing: 10) {
      if let error = controller.lastError {
        StatusBanner(message: error, detail: controller.lastErrorDetail)
      } else if controller.hasUnsavedChanges {
        Label("\(controller.pendingChangeCount) pending changes", systemImage: "circle.fill")
          .font(.system(size: 10, weight: .medium)).foregroundStyle(Theme.accent)
      } else {
        Label("Settings match the mouse", systemImage: "checkmark.circle.fill")
          .font(.system(size: 10, weight: .medium)).foregroundStyle(Theme.textDim)
      }
      Spacer()
      Button("Profiles") { showingProfiles = true }
        .buttonStyle(PlateButtonStyle(wide: false))
      Button("Restore") { controller.restoreOriginal() }
        .buttonStyle(PlateButtonStyle(wide: false))
        .help("Restore the configuration first read from this mouse")
      Button("Apply to mouse") { controller.applyToDevice() }
        .buttonStyle(PlateButtonStyle(wide: false, accented: true))
        .disabled(!controller.hasUnsavedChanges)
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 14)
  }
}

private enum ControlArea: String, CaseIterable, Identifiable {
  case buttons, dpi, lighting, rings, scrolling, apps, advanced
  var id: String { rawValue }

  var title: String {
    switch self {
    case .buttons: return "Buttons"
    case .dpi: return "DPI & sensor"
    case .lighting: return "Lighting"
    case .rings: return "Actions Ring"
    case .scrolling: return "Scrolling"
    case .apps: return "App profiles"
    case .advanced: return "Advanced"
    }
  }
  var subtitle: String {
    switch self {
    case .buttons: return "Remap six controls"
    case .dpi: return "Speed and stages"
    case .lighting: return "RGB effects"
    case .rings: return "Rings and drags"
    case .scrolling: return "Mouse + trackpad"
    case .apps: return "Automatic switching"
    case .advanced: return "Device diagnostics"
    }
  }
  var editorDescription: String {
    switch self {
    case .buttons: return "Choose a numbered control"
    case .dpi: return "Tune pointer response"
    case .lighting: return "Set the onboard RGB effect"
    case .rings: return "Hold a button for a ring, or drag it in a direction"
    case .scrolling: return "Correct the wheel without changing the trackpad"
    case .apps: return "Change profiles with the frontmost app"
    case .advanced: return "Safe access to unfinished controls"
    }
  }
  var symbol: String {
    switch self {
    case .buttons: return "cursorarrow.click.2"
    case .dpi: return "scope"
    case .lighting: return "lightspectrum.horizontal"
    case .rings: return "circle.hexagongrid"
    case .scrolling: return "computermouse.and.cursorarrow"
    case .apps: return "square.stack.3d.up.fill"
    case .advanced: return "slider.horizontal.3"
    }
  }
}

struct ConnectionPlaceholder: View {
  @EnvironmentObject private var controller: DeviceController
  var body: some View {
    VStack(spacing: 14) {
      Image(
        systemName: controller.state == .needsPermission ? "lock.shield" : "cable.connector.slash"
      )
      .font(.system(size: 40)).foregroundStyle(Theme.accent)
      Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
      Text(detail)
        .font(.system(size: 11)).foregroundStyle(Theme.textDim)
        .multilineTextAlignment(.center).frame(maxWidth: 460)
      HStack(spacing: 9) {
        if controller.state == .needsPermission {
          Button("Open Input Monitoring Settings") {
            NSWorkspace.shared.open(
              URL(
                string:
                  "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
          }
          .buttonStyle(PlateButtonStyle(wide: false, accented: true))
        }
        Button("Try Again") { controller.connect() }.buttonStyle(PlateButtonStyle(wide: false))
      }
    }
    .padding(40)
  }
  private var title: String {
    switch controller.state {
    case .needsPermission: return "macOS is blocking access to the mouse"
    case .notFound, .searching: return "No mouse detected"
    case .failed: return "Could not read the mouse"
    case .connected: return "Connected"
    }
  }
  private var detail: String {
    switch controller.state {
    case .needsPermission:
      return
        "Enable GloriousCTL in System Settings › Privacy & Security › Input Monitoring, then reopen the app."
    case .failed: return controller.lastError ?? "Unknown error."
    default:
      return
        "Connect the Glorious Model O over USB. Some KVMs do not pass its vendor interface through."
    }
  }
}
