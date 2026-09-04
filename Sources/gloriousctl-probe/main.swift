import Foundation
import GloriousCore

print("gloriousctl-probe — Glorious / Sinowealth mouse diagnostic\n")

let interfaces = HIDTransport.enumerateInterfaces()
if interfaces.isEmpty {
  print("No device found on vendor ID 0x258A. Is the mouse plugged in over USB?")
  exit(1)
}

print("HID interfaces:")
for info in interfaces {
  print(
    String(
      format: "  pid=0x%04X  usagePage=0x%02X usage=0x%02X  feature=%d in=%d  %@",
      info.productID, info.usagePage, info.usage,
      info.maxFeatureReportSize, info.maxInputReportSize, info.product))
}

if let descriptor = HIDTransport.configInterfaceReportDescriptor() {
  print("\nReport descriptor of the config interface (\(descriptor.count) bytes):")
  print("  " + descriptor.map { String(format: "%02X", $0) }.joined(separator: " "))
}

let transport = HIDTransport()
do {
  let info = try transport.connect()
  print(String(format: "\nOpened config interface (pid 0x%04X).", info.productID))

  var blocks: [ConfigBlock: [UInt8]] = [:]
  for block in ConfigBlock.allCases {
    try transport.setFeatureReport(
      id: DeviceProtocol.commandReportID,
      payload: block.command)
    Thread.sleep(forTimeInterval: 0.02)
    let (buffer, actual) = try transport.getFeatureReport(
      id: DeviceProtocol.configReportID,
      length: DeviceProtocol.configReportSize)
    let usable = max(0, min(actual, block.length))
    blocks[block] = Array(buffer.prefix(usable))

    print(
      "\nblock 0x\(String(block.rawValue, radix: 16)) — \(block.displayName): "
        + "device returned \(actual) bytes, using \(usable)")
    print(MouseConfig.hexDump(Array(buffer.prefix(usable))))
  }

  let config = MouseConfig(
    settings: blocks[.settings] ?? [],
    buttons: blocks[.buttons] ?? [])

  print("\nDecoded:")
  print("  DPI stages   : \(config.dpiStageCount), active \(config.activeDPIStage)")
  for stage in 0..<config.dpiStageCount {
    print(
      String(
        format: "    stage %d: %5d DPI  %@",
        stage + 1, config.dpi(atStage: stage),
        config.color(atStage: stage).hexString))
  }
  print(
    "  Lighting     : \(config.lightingEffect.displayName), "
      + "brightness \(config.brightness.percent)%, speed \(config.effectSpeed.displayName)")
  print("  Buttons:")
  for button in PhysicalButton.allCases {
    print(
      String(
        format: "    %-14@ %@", button.displayName as NSString,
        config.action(for: button).displayName))
  }

  if CommandLine.arguments.count > 1 {
    let combined = ConfigBlock.allCases.flatMap { config.raw($0) }
    try Data(combined).write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
    print("\nRaw dump written to \(CommandLine.arguments[1])")
  }
  transport.close()
} catch let error as HIDError {
  print("\n\(error.localizedDescription)")
  if error == .permissionDenied {
    print(
      """

      macOS gates this device behind Input Monitoring, because its
      configuration interface also declares a keyboard usage. Grant access to
      whichever app runs this binary under:

        System Settings > Privacy & Security > Input Monitoring
      """)
  }
  exit(2)
}
