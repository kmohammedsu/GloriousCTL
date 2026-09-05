import GloriousCore
import GloriousUI
import SwiftUI

struct DPISettingPanel: View {
  let config: MouseConfig
  @EnvironmentObject private var controller: DeviceController
  @State private var selectedStage = 0

  var body: some View {
    DPIStageTable(
      stages: (0..<ConfigLayout.dpiStageCountMax).map {
        DPIStageTable.Stage(
          id: $0, dpi: config.dpi(atStage: $0),
          color: config.color(atStage: $0))
      },
      enabledCount: config.dpiStageCount,
      activeStage: config.activeDPIStage,
      selectedStage: $selectedStage,
      onDPIChange: { stage, dpi in
        controller.edit { $0.setDPI(dpi, atStage: stage) }
      },
      onColorChange: { stage, color in
        controller.edit { $0.setColor(color, atStage: stage) }
      },
      onEnabledCountChange: { count in
        controller.edit { $0.dpiStageCount = count }
      })
  }
}

struct LightingPanel: View {
  let config: MouseConfig
  @EnvironmentObject private var controller: DeviceController

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Effect").font(.system(size: 9)).foregroundStyle(Theme.textDim)

      Picker(
        "",
        selection: Binding(
          get: { config.lightingEffect },
          set: { value in controller.edit { $0.lightingEffect = value } })
      ) {
        ForEach(LightingEffect.allCases) { Text($0.displayName).tag($0) }
      }
      .labelsHidden()
      .controlSize(.small)

      if config.lightingEffect == .singleColor
        || config.lightingEffect == .singleBreathing
      {
        singleColorEditor
      }

      if config.lightingEffect != .off {
        Text("Brightness").font(.system(size: 9)).foregroundStyle(Theme.textDim)
        HStack {
          AmberSlider(
            value: Binding(
              get: { Double(config.brightness.rawValue) },
              set: { value in
                controller.edit {
                  $0.brightness = Brightness(rawValue: UInt8(value)) ?? .max
                }
              }), range: 0...4)
          Text("\(config.brightness.percent)%")
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(Theme.accent).frame(width: 34)
        }

        if config.lightingEffect.supportsSpeed {
          Text("Speed").font(.system(size: 9)).foregroundStyle(Theme.textDim)
          HStack {
            AmberSlider(
              value: Binding(
                get: { Double(config.effectSpeed.rawValue) },
                set: { value in
                  controller.edit {
                    $0.effectSpeed = EffectSpeed(rawValue: UInt8(value)) ?? .medium
                  }
                }), range: 0...3)
            Text("\(config.effectSpeed.rawValue)")
              .font(.system(size: 10, design: .monospaced))
              .foregroundStyle(Theme.accent).frame(width: 34)
          }
        }
      }

      if config.lightingEffect.colorCount > 1 {
        Text(
          """
          This effect uses \(config.lightingEffect.colorCount) colour(s), but the \
          per-effect colour table has not been decoded yet, so it is left untouched.
          """
        )
        .font(.system(size: 9)).foregroundStyle(Theme.textDim)
        .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var selectedColor: GloriousCore.RGBColor {
    config.lightingEffect == .singleBreathing
      ? config.singleBreathingColor : config.singleColor
  }

  private var singleColorEditor: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Single colour").font(.system(size: 9)).foregroundStyle(Theme.textDim)
        Spacer()
        Text(selectedColor.hexString)
          .font(.system(size: 9, design: .monospaced)).foregroundStyle(Theme.textDim)
        ColorPicker(
          "",
          selection: Binding(
            get: { Color(rgbColor: selectedColor) },
            set: { setSelectedColor($0.asRGBColor) }), supportsOpacity: false
        )
        .labelsHidden().frame(width: 28)
      }

      HStack(spacing: 7) {
        ForEach(Self.colorPresets, id: \.hexString) { color in
          Button {
            setSelectedColor(color)
          } label: {
            Circle()
              .fill(Color(rgbColor: color))
              .frame(width: 22, height: 22)
              .overlay(
                Circle().strokeBorder(
                  color == selectedColor ? Color.white : Theme.border,
                  lineWidth: color == selectedColor ? 2 : 1))
          }
          .buttonStyle(.plain)
          .help(color.hexString)
        }
      }
    }
    .padding(10)
    .background(
      RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
        .fill(Theme.panelRaised))
  }

  private func setSelectedColor(_ color: GloriousCore.RGBColor) {
    controller.edit { working in
      if working.lightingEffect == .singleBreathing {
        working.singleBreathingColor = color
      } else {
        working.singleColor = color
      }
    }
  }

  private static let colorPresets: [GloriousCore.RGBColor] = [
    GloriousCore.RGBColor(red: 255, green: 55, blue: 55),
    GloriousCore.RGBColor(red: 255, green: 145, blue: 35),
    GloriousCore.RGBColor(red: 255, green: 225, blue: 45),
    GloriousCore.RGBColor(red: 60, green: 220, blue: 105),
    GloriousCore.RGBColor(red: 50, green: 205, blue: 235),
    GloriousCore.RGBColor(red: 65, green: 115, blue: 255),
    GloriousCore.RGBColor(red: 180, green: 75, blue: 255),
    GloriousCore.RGBColor(red: 255, green: 255, blue: 255),
  ]
}

struct ScrollingPanel: View {
  @EnvironmentObject private var controller: DeviceController

  /// A multiplier is easier to judge as a word than as a number.
  private func scrollSpeedName(_ speed: Double) -> String {
    switch speed {
    case ..<1.25: return "macOS default"
    case ..<2: return "A bit faster"
    case ..<3: return "Faster"
    case ..<4.5: return "Much faster"
    default: return "Fastest"
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Toggle(
        isOn: Binding(
          get: { controller.gestures.separateMouseScrolling },
          set: { controller.setSeparateMouseScrolling($0) })
      ) {
        VStack(alignment: .leading, spacing: 3) {
          Text("Fix mouse wheel direction")
            .font(.system(size: 11, weight: .semibold))
          Text("Keep the trackpad natural")
            .font(.system(size: 9)).foregroundStyle(Theme.textDim)
        }
      }
      .toggleStyle(.switch)
      .controlSize(.small)

      VStack(alignment: .leading, spacing: 4) {
        Text("Scroll speed")
          .font(.system(size: 11, weight: .semibold))
        Text("How far one wheel step moves the page")
          .font(.system(size: 9)).foregroundStyle(Theme.textDim)
        HStack(spacing: 8) {
          Slider(
            value: Binding(
              get: { controller.gestures.scrollSpeed },
              set: { controller.setScrollSpeed($0) }),
            in: 1...6, step: 0.5)
          Text(scrollSpeedName(controller.gestures.scrollSpeed))
            .font(.system(size: 10)).foregroundStyle(Theme.text)
            .frame(width: 64, alignment: .trailing)
            .help(String(format: "%.1f× the macOS default", controller.gestures.scrollSpeed))
        }
      }

      HStack(alignment: .top, spacing: 9) {
        Image(systemName: "hand.draw")
          .foregroundStyle(Theme.accent)
        Text(
          "Trackpad gestures are continuous and pass through unchanged. Only discrete mouse-wheel steps are reversed, including horizontal wheel input."
        )
        .font(.system(size: 10)).foregroundStyle(Theme.textDim)
        .fixedSize(horizontal: false, vertical: true)
      }
      .padding(11)
      .background(
        RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
          .fill(Theme.panelRaised))

      if !controller.gestures.hasAccessibilityPermission {
        Text("Accessibility permission is required to separate mouse and trackpad scrolling.")
          .font(.system(size: 9)).foregroundStyle(Theme.accent)
        HStack {
          Button("Grant permission…") { controller.gestures.requestPermission() }
            .buttonStyle(PlateButtonStyle(wide: false, accented: true))
          Button("Recheck") {
            if controller.gestures.refreshPermission() {
              controller.saveGestureBindings()
            }
          }
          .buttonStyle(PlateButtonStyle(wide: false))
        }
      }
    }
  }
}

struct UnmappedPanel: View {
  let fields: [String]
  let note: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(fields, id: \.self) { field in
        HStack(spacing: 7) {
          Image(systemName: "questionmark.circle")
            .font(.system(size: 10)).foregroundStyle(Theme.textDim)
          Text(field).font(.system(size: 10)).foregroundStyle(Theme.textDim)
          Spacer()
        }
      }
      Divider().overlay(Theme.border)
      Text(note)
        .font(.system(size: 9)).foregroundStyle(Theme.textDim)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

struct InspectorSheet: View {
  @EnvironmentObject private var controller: DeviceController
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Protocol Inspector").font(.headline)
        Spacer()
        Button("Done") { dismiss() }.buttonStyle(PlateButtonStyle(wide: false))
      }
      .padding(14)
      Divider()
      InspectorView().environmentObject(controller)
    }
    .frame(width: 940, height: 700)
    .preferredColorScheme(.dark)
  }
}

struct MacroEditorSheet: View {
  @EnvironmentObject private var controller: DeviceController
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Macro Editor").font(.headline)
        Spacer()
        Button("Done") { dismiss() }.buttonStyle(PlateButtonStyle(wide: false))
      }
      .padding(14)
      Divider()
      MacrosView().environmentObject(controller)
    }
    .frame(width: 780, height: 520)
    .preferredColorScheme(.dark)
  }
}

struct ProfilesSheet: View {
  @EnvironmentObject private var controller: DeviceController
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Profiles").font(.headline)
        Spacer()
        Button("Done") { dismiss() }.buttonStyle(PlateButtonStyle(wide: false))
      }
      .padding(14)
      Divider()
      ProfilesView().environmentObject(controller)
    }
    .frame(width: 640, height: 460)
    .preferredColorScheme(.dark)
  }
}
