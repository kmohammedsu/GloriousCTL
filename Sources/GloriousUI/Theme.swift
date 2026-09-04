import SwiftUI

public enum Theme {
  public static let background = Color(red: 0.055, green: 0.060, blue: 0.070)
  public static let panel = Color(red: 0.092, green: 0.100, blue: 0.116)
  public static let panelRaised = Color(red: 0.125, green: 0.135, blue: 0.154)
  public static let plate = Color(red: 0.142, green: 0.152, blue: 0.172)
  public static let border = Color.white.opacity(0.105)
  public static let accent = Color(red: 0.980, green: 0.690, blue: 0.235)
  public static let accentDim = Color(red: 0.980, green: 0.690, blue: 0.235).opacity(0.42)
  public static let text = Color(red: 0.955, green: 0.960, blue: 0.975)
  public static let textDim = Color(red: 0.605, green: 0.630, blue: 0.680)
  public static let danger = Color(red: 0.90, green: 0.35, blue: 0.30)

  public static let corner: CGFloat = 10
}

public struct PlateButtonStyle: ButtonStyle {
  public init(wide: Bool = true, accented: Bool = false) {
    self.wide = wide
    self.accented = accented
  }
  var wide: Bool
  var accented: Bool

  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 11, weight: .medium))
      .foregroundStyle(accented ? Theme.accent : Theme.text)
      .frame(maxWidth: wide ? .infinity : nil)
      .padding(.horizontal, wide ? 8 : 14)
      .padding(.vertical, 7)
      .background(
        RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
          .fill(configuration.isPressed ? Theme.panelRaised : Theme.plate)
      )
      .overlay(
        RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
          .strokeBorder(accented ? Theme.accentDim : Theme.border, lineWidth: 1)
      )
      .contentShape(Rectangle())
  }
}

public struct AmberSlider: View {
  public init(value: Binding<Double>, range: ClosedRange<Double>, step: Double = 1) {
    self._value = value
    self.range = range
    self.step = step
  }
  @Binding var value: Double
  let range: ClosedRange<Double>
  var step: Double = 1

  public var body: some View {
    Slider(value: $value, in: range, step: step)
      .tint(Theme.accent)
      .controlSize(.small)
  }
}

public struct AmberCheck: View {
  public init(isOn: Binding<Bool>, label: String? = nil) {
    self._isOn = isOn
    self.label = label
  }
  @Binding var isOn: Bool
  var label: String? = nil

  public var body: some View {
    Button {
      isOn.toggle()
    } label: {
      HStack(spacing: 6) {
        ZStack {
          RoundedRectangle(cornerRadius: 2)
            .strokeBorder(isOn ? Theme.accent : Theme.border, lineWidth: 1)
            .frame(width: 12, height: 12)
          if isOn {
            Image(systemName: "checkmark")
              .font(.system(size: 8, weight: .bold))
              .foregroundStyle(Theme.accent)
          }
        }
        if let label {
          Text(label).font(.system(size: 10)).foregroundStyle(Theme.textDim)
        }
      }
    }
    .buttonStyle(.plain)
  }
}
