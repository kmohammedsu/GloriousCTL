import Foundation

public struct MouseConfig: Equatable, Sendable {

  public private(set) var settings: [UInt8]
  public private(set) var buttons: [UInt8]

  public init(settings: [UInt8], buttons: [UInt8]) {
    self.settings = Self.normalise(settings, to: ConfigBlock.settings)
    self.buttons = Self.normalise(buttons, to: ConfigBlock.buttons)
  }

  private static func normalise(_ bytes: [UInt8], to block: ConfigBlock) -> [UInt8] {
    var buffer = bytes
    if buffer.count < block.length {
      buffer += [UInt8](repeating: 0, count: block.length - buffer.count)
    }
    return Array(buffer.prefix(block.length))
  }

  private func settingsByte(_ offset: Int) -> UInt8 {
    offset >= 0 && offset < settings.count ? settings[offset] : 0
  }

  private mutating func setSettingsByte(_ offset: Int, _ value: UInt8) {
    guard offset >= 0 && offset < settings.count else { return }
    settings[offset] = value
  }

  public struct DPIStage: Equatable, Codable, Sendable, Identifiable {
    public var id: Int
    public var dpi: Int
    public var color: RGBColor
    public init(id: Int, dpi: Int, color: RGBColor) {
      self.id = id
      self.dpi = dpi
      self.color = color
    }
  }

  public var dpiStageCount: Int {
    get {
      max(
        1,
        min(
          Int(settingsByte(ConfigLayout.dpiStageCount)),
          ConfigLayout.dpiStageCountMax))
    }
    set {
      setSettingsByte(
        ConfigLayout.dpiStageCount,
        UInt8(max(1, min(newValue, ConfigLayout.dpiStageCountMax))))
    }
  }

  public var activeDPIStage: Int {
    get {
      max(
        1,
        min(
          Int(settingsByte(ConfigLayout.activeDPIStage)),
          ConfigLayout.dpiStageCountMax))
    }
    set {
      setSettingsByte(
        ConfigLayout.activeDPIStage,
        UInt8(max(1, min(newValue, ConfigLayout.dpiStageCountMax))))
    }
  }

  public func dpi(atStage index: Int) -> Int {
    ConfigLayout.decodeDPI(settingsByte(ConfigLayout.dpiValues + index))
  }

  public mutating func setDPI(_ dpi: Int, atStage index: Int) {
    setSettingsByte(ConfigLayout.dpiValues + index, ConfigLayout.encodeDPI(dpi))
  }

  public func color(atStage index: Int) -> RGBColor {
    let offset = ConfigLayout.dpiColors + index * ConfigLayout.dpiColorBytesPerStage
    guard offset + 2 < settings.count else { return .white }
    return RGBColor(bytes: settings[offset...(offset + 2)])
  }

  public mutating func setColor(_ color: RGBColor, atStage index: Int) {
    let offset = ConfigLayout.dpiColors + index * ConfigLayout.dpiColorBytesPerStage
    for (i, value) in color.bytes.enumerated() { setSettingsByte(offset + i, value) }
  }

  public var dpiStages: [DPIStage] {
    (0..<ConfigLayout.dpiStageCountMax).map {
      DPIStage(id: $0, dpi: dpi(atStage: $0), color: color(atStage: $0))
    }
  }

  public var lightingEffect: LightingEffect {
    get { LightingEffect(rawValue: settingsByte(ConfigLayout.lightingEffect)) ?? .off }
    set { setSettingsByte(ConfigLayout.lightingEffect, newValue.rawValue) }
  }

  public var brightness: Brightness {
    get { Brightness(rawValue: (settingsByte(activeLightingModeOffset) >> 4) & 0x0F) ?? .max }
    set {
      let current = settingsByte(activeLightingModeOffset)
      setSettingsByte(
        activeLightingModeOffset,
        (newValue.rawValue << 4) | (current & 0x0F))
    }
  }

  public var effectSpeed: EffectSpeed {
    get { EffectSpeed(rawValue: settingsByte(activeLightingModeOffset) & 0x0F) ?? .medium }
    set {
      let current = settingsByte(activeLightingModeOffset)
      setSettingsByte(
        activeLightingModeOffset,
        (current & 0xF0) | (newValue.rawValue & 0x0F))
    }
  }

  private var activeLightingModeOffset: Int {
    switch lightingEffect {
    case .off, .glorious: return ConfigLayout.gloriousMode
    case .singleColor: return ConfigLayout.singleColorMode
    case .breathing: return ConfigLayout.breathingSevenMode
    case .tail: return ConfigLayout.tailMode
    case .seamlessBreathing: return ConfigLayout.seamlessBreathingMode
    case .constantRGB: return ConfigLayout.constantRGBMode
    case .rave: return ConfigLayout.raveMode
    case .random: return ConfigLayout.randomMode
    case .wave: return ConfigLayout.waveMode
    case .singleBreathing: return ConfigLayout.singleBreathingMode
    }
  }

  public var singleColor: RGBColor {
    get { rbgColor(at: ConfigLayout.singleColor) }
    set { setRBGColor(newValue, at: ConfigLayout.singleColor) }
  }

  public var singleBreathingColor: RGBColor {
    get { rbgColor(at: ConfigLayout.singleBreathingColor) }
    set { setRBGColor(newValue, at: ConfigLayout.singleBreathingColor) }
  }

  private func rbgColor(at offset: Int) -> RGBColor {
    RGBColor(
      red: settingsByte(offset), green: settingsByte(offset + 2),
      blue: settingsByte(offset + 1))
  }

  private mutating func setRBGColor(_ color: RGBColor, at offset: Int) {
    setSettingsByte(offset, color.red)
    setSettingsByte(offset + 1, color.blue)
    setSettingsByte(offset + 2, color.green)
  }

  public var pollingRate: PollingRate? { nil }

  public func action(for button: PhysicalButton) -> ButtonAction {
    let offset = ConfigLayout.buttonMap + button.rawValue * ConfigLayout.buttonEntrySize
    guard offset + 3 < buttons.count else { return .disabled }
    return ButtonAction(encoded: buttons[offset...(offset + 3)])
  }

  public mutating func setAction(_ action: ButtonAction, for button: PhysicalButton) {
    let offset = ConfigLayout.buttonMap + button.rawValue * ConfigLayout.buttonEntrySize
    guard offset + 3 < buttons.count else { return }
    for (i, value) in action.encoded.enumerated() { buttons[offset + i] = value }
  }

  public var buttonMap: [PhysicalButton: ButtonAction] {
    Dictionary(uniqueKeysWithValues: PhysicalButton.allCases.map { ($0, action(for: $0)) })
  }

  public func bufferForWrite(_ block: ConfigBlock) -> [UInt8] {
    var out = block == .settings ? settings : buttons
    guard out.count > ConfigLayout.blockDataLength else { return out }

    out[ConfigLayout.reportID] = DeviceProtocol.configReportID
    out[ConfigLayout.blockCommand] = block.rawValue
    out[ConfigLayout.blockDataLength] = UInt8(block.dataLength)

    if out.count < DeviceProtocol.configReportSize {
      out += [UInt8](
        repeating: 0,
        count: DeviceProtocol.configReportSize - out.count)
    }
    return out
  }

  public func raw(_ block: ConfigBlock) -> [UInt8] {
    block == .settings ? settings : buttons
  }

  public func changedOffsets(
    comparedTo other: MouseConfig,
    in block: ConfigBlock
  ) -> [Int] {
    let a = raw(block)
    let b = other.raw(block)
    return (0..<min(a.count, b.count)).filter { a[$0] != b[$0] }
  }

  public var totalChangedByteCount: Int { 0 }

  public func hexDump(_ block: ConfigBlock) -> String {
    Self.hexDump(raw(block))
  }

  public static func hexDump(_ bytes: [UInt8]) -> String {
    var lines: [String] = []
    for row in stride(from: 0, to: bytes.count, by: 16) {
      let end = min(row + 16, bytes.count)
      let slice = bytes[row..<end]
      let hex = slice.map { String(format: "%02X", $0) }.joined(separator: " ")
      let ascii = slice.map { $0 >= 32 && $0 < 127 ? String(UnicodeScalar($0)) : "." }.joined()
      lines.append(String(format: "%04X  %-47@  %@", row, hex as NSString, ascii))
    }
    return lines.joined(separator: "\n")
  }
}
