import GloriousCore
import SwiftUI

public struct DPIStageTable: View {
  public struct Stage: Identifiable, Equatable {
    public let id: Int
    public let dpi: Int
    public let color: GloriousCore.RGBColor
    public init(id: Int, dpi: Int, color: GloriousCore.RGBColor) {
      self.id = id
      self.dpi = dpi
      self.color = color
    }
  }

  let stages: [Stage]
  let enabledCount: Int
  let activeStage: Int
  @Binding var selectedStage: Int
  let onDPIChange: (Int, Int) -> Void
  let onColorChange: (Int, GloriousCore.RGBColor) -> Void
  let onEnabledCountChange: (Int) -> Void

  public init(
    stages: [Stage], enabledCount: Int, activeStage: Int,
    selectedStage: Binding<Int>,
    onDPIChange: @escaping (Int, Int) -> Void = { _, _ in },
    onColorChange: @escaping (Int, GloriousCore.RGBColor) -> Void = { _, _ in },
    onEnabledCountChange: @escaping (Int) -> Void = { _ in }
  ) {
    self.stages = stages
    self.enabledCount = enabledCount
    self.activeStage = activeStage
    self._selectedStage = selectedStage
    self.onDPIChange = onDPIChange
    self.onColorChange = onColorChange
    self.onEnabledCountChange = onEnabledCountChange
  }

  var effectiveSelection: Int { max(0, min(selectedStage, stages.count - 1)) }

  public var body: some View {
    VStack(alignment: .leading, spacing: 9) {
      HStack(spacing: 0) {
        Text("ON").frame(width: 28, alignment: .leading)
        Text("DPI").frame(width: 68, alignment: .leading)
        Text("COLOR").frame(width: 46, alignment: .leading)
        Spacer()
      }
      .font(.system(size: 9)).foregroundStyle(Theme.textDim)

      VStack(spacing: 4) {
        ForEach(stages) { stage in row(stage) }
      }

      Divider().overlay(Theme.border)

      VStack(alignment: .leading, spacing: 5) {
        HStack {
          Text("Stage \(effectiveSelection + 1)")
            .font(.system(size: 10)).foregroundStyle(Theme.accent)
          Spacer()
          Text("\(stages[safe: effectiveSelection]?.dpi ?? 0) DPI")
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(Theme.text)
        }
        AmberSlider(
          value: Binding(
            get: { Double(stages[safe: effectiveSelection]?.dpi ?? 400) },
            set: { onDPIChange(effectiveSelection, Int($0.rounded())) }),
          range: 100...12000, step: 100)
      }

      AmberCheck(isOn: .constant(false), label: "XY Independent")
        .disabled(true)
        .help("This mouse reports its Y-axis values as zero, so the axes are locked together.")

      Text("Current DPI: \(stages[safe: activeStage - 1]?.dpi ?? 0)")
        .font(.system(size: 10)).foregroundStyle(Theme.accent)
    }
  }

  private func row(_ stage: Stage) -> some View {
    let isEnabled = stage.id < enabledCount
    let isSelected = stage.id == effectiveSelection
    return HStack(spacing: 0) {
      AmberCheck(
        isOn: Binding(
          get: { isEnabled },
          set: { _ in onEnabledCountChange(stage.id + 1) })
      )
      .frame(width: 28, alignment: .leading)
      .help("The DPI button cycles through stages 1–\(enabledCount)")

      TextField(
        "",
        value: Binding(
          get: { stage.dpi },
          set: { onDPIChange(stage.id, $0) }), format: .number
      )
      .textFieldStyle(.plain)
      .font(.system(size: 10, design: .monospaced))
      .foregroundStyle(isEnabled ? Theme.text : Theme.textDim)
      .padding(.horizontal, 5).padding(.vertical, 2)
      .background(RoundedRectangle(cornerRadius: 2).fill(Theme.background))
      .overlay(
        RoundedRectangle(cornerRadius: 2)
          .strokeBorder(isSelected ? Theme.accent : Theme.border, lineWidth: 1)
      )
      .frame(width: 62)

      ColorPicker(
        "",
        selection: Binding(
          get: { Color(rgbColor: stage.color) },
          set: { onColorChange(stage.id, $0.asRGBColor) }), supportsOpacity: false
      )
      .labelsHidden()
      .frame(width: 36)
      .padding(.leading, 10)

      Spacer()

      if stage.id == activeStage - 1 {
        Text("ACTIVE")
          .font(.system(size: 8, weight: .bold))
          .foregroundStyle(Theme.accent)
      }
    }
    .padding(.vertical, 1)
    .background(
      RoundedRectangle(cornerRadius: 2)
        .fill(isSelected ? Theme.accent.opacity(0.10) : .clear)
    )
    .opacity(isEnabled ? 1 : 0.45)
    .contentShape(Rectangle())
    .onTapGesture { selectedStage = stage.id }
  }
}

extension Array {
  subscript(safe index: Int) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}

extension Color {
  public init(rgbColor: GloriousCore.RGBColor) {
    self.init(
      .sRGB,
      red: Double(rgbColor.red) / 255,
      green: Double(rgbColor.green) / 255,
      blue: Double(rgbColor.blue) / 255)
  }

  public var asRGBColor: GloriousCore.RGBColor {
    let converted = NSColor(self).usingColorSpace(.sRGB) ?? .white
    return GloriousCore.RGBColor(
      red: UInt8((converted.redComponent * 255).rounded()),
      green: UInt8((converted.greenComponent * 255).rounded()),
      blue: UInt8((converted.blueComponent * 255).rounded()))
  }
}
