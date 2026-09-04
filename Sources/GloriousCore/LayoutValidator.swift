import Foundation

public struct LayoutValidator {

  public struct Check: Identifiable, Sendable {
    public let id = UUID()
    public let block: ConfigBlock
    public let field: String
    public let offset: Int
    public let rawValue: String
    public let interpretation: String
    public let passed: Bool
    public let note: String?
  }

  public let checks: [Check]

  public var passedCount: Int { checks.filter(\.passed).count }
  public var confidence: Double {
    checks.isEmpty ? 0 : Double(passedCount) / Double(checks.count)
  }
  public var allPassed: Bool { checks.allSatisfy(\.passed) }

  public init(config: MouseConfig) {
    var checks: [Check] = []
    let settings = config.raw(.settings)
    let buttons = config.raw(.buttons)

    func byte(_ bytes: [UInt8], _ offset: Int) -> UInt8 {
      offset < bytes.count ? bytes[offset] : 0
    }

    for (block, bytes) in [(ConfigBlock.settings, settings), (ConfigBlock.buttons, buttons)] {
      let echoed = byte(bytes, ConfigLayout.blockCommand)
      checks.append(
        Check(
          block: block,
          field: "Block header",
          offset: ConfigLayout.blockCommand,
          rawValue: String(format: "0x%02X", echoed),
          interpretation: "echoes command 0x\(String(block.rawValue, radix: 16))",
          passed: echoed == block.rawValue,
          note: echoed == block.rawValue
            ? nil
            : "The device returned a different block than requested."))
    }

    let stageCount = byte(settings, ConfigLayout.dpiStageCount)
    checks.append(
      Check(
        block: .settings, field: "DPI Stage Count",
        offset: ConfigLayout.dpiStageCount,
        rawValue: String(format: "0x%02X", stageCount),
        interpretation: "\(stageCount) stages",
        passed: (1...6).contains(Int(stageCount)),
        note: (1...6).contains(Int(stageCount)) ? nil : "Outside 1–6."))

    let active = byte(settings, ConfigLayout.activeDPIStage)
    checks.append(
      Check(
        block: .settings, field: "Active DPI Stage",
        offset: ConfigLayout.activeDPIStage,
        rawValue: String(format: "0x%02X", active),
        interpretation: "stage \(active)",
        passed: (1...6).contains(Int(active)) && active <= stageCount,
        note: (1...6).contains(Int(active)) ? nil : "Outside 1–6."))

    var previous = 0
    var ascending = true
    for stage in 0..<ConfigLayout.dpiStageCountMax {
      let offset = ConfigLayout.dpiValues + stage
      let dpi = ConfigLayout.decodeDPI(byte(settings, offset))
      let sane = dpi >= 100 && dpi <= 12000
      if dpi <= previous { ascending = false }
      previous = dpi
      checks.append(
        Check(
          block: .settings, field: "DPI Stage \(stage + 1)",
          offset: offset,
          rawValue: String(format: "0x%02X", byte(settings, offset)),
          interpretation: "\(dpi) DPI",
          passed: sane,
          note: sane ? nil : "Outside the PMW3360's 100–12000 range."))
    }
    checks.append(
      Check(
        block: .settings, field: "DPI ordering",
        offset: ConfigLayout.dpiValues,
        rawValue: "—",
        interpretation: ascending ? "stages ascend" : "stages do not ascend",
        passed: ascending,
        note: ascending ? nil : "Unusual, though not itself invalid."))

    let effect = byte(settings, ConfigLayout.lightingEffect)
    let parsedEffect = LightingEffect(rawValue: effect)
    checks.append(
      Check(
        block: .settings, field: "Lighting Effect",
        offset: ConfigLayout.lightingEffect,
        rawValue: String(format: "0x%02X", effect),
        interpretation: parsedEffect?.displayName ?? "unrecognised",
        passed: parsedEffect != nil,
        note: parsedEffect == nil ? "Not a known effect id (0x00–0x0A)." : nil))

    let bs = byte(settings, ConfigLayout.lightingBrightnessSpeed)
    let brightnessOK = (bs >> 4) <= 4
    let speedOK = (bs & 0x0F) <= 3
    checks.append(
      Check(
        block: .settings, field: "Brightness / Speed",
        offset: ConfigLayout.lightingBrightnessSpeed,
        rawValue: String(format: "0x%02X", bs),
        interpretation: "brightness \((bs >> 4) * 25)%, speed \(bs & 0x0F)",
        passed: brightnessOK && speedOK,
        note: (brightnessOK && speedOK) ? nil : "Nibbles outside their expected ranges."))

    let knownClasses: Set<UInt8> = [0x00, 0x11, 0x12, 0x21, 0x22, 0x41, 0x50]
    for button in PhysicalButton.allCases {
      let offset = ConfigLayout.buttonMap + button.rawValue * ConfigLayout.buttonEntrySize
      let cls = byte(buttons, offset)
      checks.append(
        Check(
          block: .buttons, field: button.displayName,
          offset: offset,
          rawValue: String(format: "0x%02X", cls),
          interpretation: config.action(for: button).displayName,
          passed: knownClasses.contains(cls),
          note: knownClasses.contains(cls) ? nil : "Unknown action class byte."))
    }

    self.checks = checks
  }
}
