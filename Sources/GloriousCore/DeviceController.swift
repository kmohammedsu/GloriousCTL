import Combine
import Foundation

@MainActor
public final class DeviceController: ObservableObject {

  public enum ConnectionState: Equatable {
    case searching
    case connected(HIDInterfaceInfo)
    case needsPermission
    case notFound
    case failed(String)

    public var isConnected: Bool {
      if case .connected = self { return true }
      return false
    }
  }

  @Published public private(set) var state: ConnectionState = .searching
  @Published public private(set) var deviceConfig: MouseConfig?
  @Published public var workingConfig: MouseConfig?
  @Published public private(set) var validator: LayoutValidator?
  @Published public private(set) var lastError: String?
  @Published public private(set) var lastErrorDetail: String?
  @Published public private(set) var isBusy = false
  @Published public var profiles: [Profile] = []
  @Published public var macros: [Macro] = []
  @Published public private(set) var interfaces: [HIDInterfaceInfo] = []
  @Published public private(set) var lastReadLength: Int = 0
  @Published public private(set) var diagnosticsPath: String?

  public var hasUnsavedChanges: Bool {
    guard let deviceConfig, let workingConfig else { return false }
    return deviceConfig != workingConfig
  }

  public var pendingChanges: [(block: ConfigBlock, offsets: [Int])] {
    guard let deviceConfig, let workingConfig else { return [] }
    return ConfigBlock.allCases.compactMap { block in
      let offsets = workingConfig.changedOffsets(comparedTo: deviceConfig, in: block)
      return offsets.isEmpty ? nil : (block, offsets)
    }
  }

  public var pendingChangeCount: Int {
    pendingChanges.reduce(0) { $0 + $1.offsets.count }
  }

  private let transport = HIDTransport()
  private let store: ProfileStore
  private var pollTimer: Timer?
  private var ringSaveWork: DispatchWorkItem?

  public let gestures = GestureEngine()
  public let appSwitcher = AppProfileSwitcher()

  private static let gestureDefaultsKey = "GestureBindings"
  private static let ringDefaultsKey = "ActionRingConfigurations"
  private static let separateMouseScrollingKey = "SeparateMouseScrolling"
  private static let scrollSpeedKey = "ScrollSpeed"

  private var childObservers: [AnyCancellable] = []

  public init(store: ProfileStore = .shared) {
    self.store = store
    self.profiles = store.load()
    loadGestureBindings()
    loadActionRings()
    gestures.separateMouseScrolling = UserDefaults.standard.bool(
      forKey: Self.separateMouseScrollingKey)
    // Absent means never set, which must read as 1 (leave macOS alone) rather than
    // the 0 that `double(forKey:)` returns for a missing key.
    let storedSpeed = UserDefaults.standard.double(forKey: Self.scrollSpeedKey)
    gestures.scrollSpeed = storedSpeed > 0 ? storedSpeed : 1
    wireAppSwitcher()
    forwardChildChanges()
  }

  private func forwardChildChanges() {
    childObservers = [
      gestures.objectWillChange.sink { [weak self] in
        self?.objectWillChange.send()
      },
      appSwitcher.objectWillChange.sink { [weak self] in
        self?.objectWillChange.send()
      },
    ]
  }

  private func loadGestureBindings() {
    if let data = UserDefaults.standard.data(forKey: Self.gestureDefaultsKey),
      let stored = try? JSONDecoder().decode([GestureBinding].self, from: data),
      !stored.isEmpty
    {
      gestures.bindings = Dictionary(uniqueKeysWithValues: stored.map { ($0.button, $0) })
    } else {
      gestures.bindings = Dictionary(
        uniqueKeysWithValues: [PhysicalButton.back, .forward, .middle].map {
          ($0, GestureBinding.defaultBinding(for: $0))
        })
    }
  }

  private func loadActionRings() {
    if let data = UserDefaults.standard.data(forKey: Self.ringDefaultsKey),
      let stored = try? JSONDecoder().decode([ActionRingConfiguration].self, from: data),
      !stored.isEmpty
    {
      gestures.rings = Dictionary(uniqueKeysWithValues: stored.map { ($0.button, $0) })
    } else {
      gestures.rings = Dictionary(
        uniqueKeysWithValues: [PhysicalButton.back, .forward, .middle].map {
          ($0, ActionRingConfiguration.defaultConfiguration(for: $0))
        })
    }
  }

  public func saveGestureBindings() {
    let list = Array(gestures.bindings.values).sorted { $0.button.rawValue < $1.button.rawValue }
    if let data = try? JSONEncoder().encode(list) {
      UserDefaults.standard.set(data, forKey: Self.gestureDefaultsKey)
    }
    let rings = Array(gestures.rings.values).sorted { $0.button.rawValue < $1.button.rawValue }
    if let data = try? JSONEncoder().encode(rings) {
      UserDefaults.standard.set(data, forKey: Self.ringDefaultsKey)
    }
    if list.contains(where: \.enabled) || rings.contains(where: \.enabled)
      || gestures.separateMouseScrolling
    {
      gestures.start()
    } else {
      gestures.stop()
    }
  }

  public func updateGesture(_ binding: GestureBinding) {
    gestures.bindings[binding.button] = binding
    saveGestureBindings()
  }

  public func updateActionRing(_ configuration: ActionRingConfiguration) {
    gestures.rings[configuration.button] = configuration
    ringSaveWork?.cancel()
    let work = DispatchWorkItem { [weak self] in
      Task { @MainActor in self?.saveGestureBindings() }
    }
    ringSaveWork = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16, execute: work)
  }

  public func setSeparateMouseScrolling(_ enabled: Bool) {
    gestures.separateMouseScrolling = enabled
    UserDefaults.standard.set(enabled, forKey: Self.separateMouseScrollingKey)
  }

  public func setScrollSpeed(_ speed: Double) {
    gestures.scrollSpeed = speed
    UserDefaults.standard.set(speed, forKey: Self.scrollSpeedKey)
    objectWillChange.send()
    saveGestureBindings()
  }

  public func gestureNeedsDeviceRemap(_ button: PhysicalButton) -> Bool {
    guard let config = workingConfig else { return false }
    if case .mouseButton = config.action(for: button) { return false }
    return true
  }

  public func prepareButtonForGestures(_ button: PhysicalButton) {
    let code: MouseButtonCode
    switch button {
    case .back: code = .back
    case .forward: code = .forward
    case .middle: code = .middle
    default: return
    }
    edit { $0.setAction(.mouseButton(code), for: button) }
  }

  private func wireAppSwitcher() {
    appSwitcher.profilesProvider = { [weak self] in self?.profiles ?? [] }
    appSwitcher.isAlreadyActive = { [weak self] profile in
      guard let self, let current = self.deviceConfig else { return false }
      return profile.config == current
    }
    appSwitcher.applyProfile = { [weak self] profile in
      guard let self else { return }
      self.apply(profile: profile)
      self.applyToDevice()
    }
  }

  public func setAutoSwitchBundleID(_ bundleID: String?, for profile: Profile) {
    guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
    profiles[index].autoSwitchBundleID = bundleID
    profiles[index].modifiedAt = Date()
    persistProfiles()
  }

  public func refreshInterfaces() {
    interfaces = HIDTransport.enumerateInterfaces()
  }

  public func preparePreviewState() {
    var settings = [UInt8](repeating: 0, count: ConfigBlock.settings.length)
    var buttons = [UInt8](repeating: 0, count: ConfigBlock.buttons.length)
    settings[ConfigLayout.blockCommand] = ConfigBlock.settings.rawValue
    buttons[ConfigLayout.blockCommand] = ConfigBlock.buttons.rawValue
    var preview = MouseConfig(settings: settings, buttons: buttons)
    preview.dpiStageCount = 4
    preview.activeDPIStage = 2
    for (index, dpi) in [400, 800, 1600, 3200, 6400, 12000].enumerated() {
      preview.setDPI(dpi, atStage: index)
    }
    let colors: [RGBColor] = [
      .init(red: 255, green: 75, blue: 95), .init(red: 255, green: 185, blue: 40),
      .init(red: 55, green: 210, blue: 135), .init(red: 45, green: 155, blue: 255),
      .init(red: 145, green: 90, blue: 255), .init(red: 255, green: 75, blue: 205),
    ]
    for (index, color) in colors.enumerated() { preview.setColor(color, atStage: index) }
    preview.lightingEffect = .glorious
    preview.brightness = .max
    for button in PhysicalButton.allCases {
      preview.setAction(button.factoryDefault, for: button)
    }
    deviceConfig = preview
    workingConfig = preview
    state = .connected(
      HIDInterfaceInfo(
        vendorID: HIDTransport.vendorIDSinowealth, productID: 0x2011,
        usagePage: 0xFF00, usage: 1, maxFeatureReportSize: 520,
        maxInputReportSize: 0, product: "Glorious Model O",
        manufacturer: "Glorious", locationID: 0))
    lastError = nil
  }

  public func connect() {
    refreshInterfaces()
    do {
      let info = try transport.connect()
      state = .connected(info)
      lastError = nil
      do {
        try readConfig()
      } catch {
        lastError = error.localizedDescription
      }
    } catch HIDError.permissionDenied {
      state = .needsPermission
    } catch HIDError.deviceNotFound {
      state = .notFound
    } catch {
      state = .failed(error.localizedDescription)
      lastError = error.localizedDescription
    }
  }

  public func disconnect() {
    transport.close()
    state = .searching
  }

  public func startMonitoring() {
    pollTimer?.invalidate()
    pollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
      Task { @MainActor in
        guard let self else { return }
        if !self.state.isConnected { self.connect() }
      }
    }
  }

  public func stopMonitoring() {
    pollTimer?.invalidate()
    pollTimer = nil
  }

  public func readConfig() throws {
    isBusy = true
    defer { isBusy = false }

    var blocks: [ConfigBlock: [UInt8]] = [:]
    var totalRead = 0

    for block in ConfigBlock.allCases {
      try transport.setFeatureReport(
        id: DeviceProtocol.commandReportID,
        payload: block.command)
      Thread.sleep(forTimeInterval: 0.02)

      let (buffer, actual) = try transport.getFeatureReport(
        id: DeviceProtocol.configReportID,
        length: DeviceProtocol.configReportSize)

      let usable = max(0, min(actual, block.length))
      guard usable > ConfigLayout.blockCommand,
        buffer[ConfigLayout.blockCommand] == block.rawValue
      else {
        throw HIDError.blockMismatch(
          expected: block.rawValue,
          got: usable > ConfigLayout.blockCommand ? buffer[ConfigLayout.blockCommand] : 0)
      }
      blocks[block] = Array(buffer.prefix(usable))
      totalRead += usable
    }

    lastReadLength = totalRead
    let config = MouseConfig(
      settings: blocks[.settings] ?? [],
      buttons: blocks[.buttons] ?? [])

    deviceConfig = config
    if workingConfig == nil { workingConfig = config }
    validator = LayoutValidator(config: config)

    try? store.writeOriginalBackupIfNeeded(config)
    lastError = nil
  }

  public func reloadFromDevice() {
    do {
      workingConfig = nil
      try readConfig()
    } catch {
      lastError = error.localizedDescription
    }
  }

  @discardableResult
  public func applyToDevice() -> Bool {
    guard let working = workingConfig else { return false }
    guard state.isConnected else {
      lastError = HIDError.notConnected.localizedDescription
      return false
    }

    isBusy = true
    defer { isBusy = false }

    do {
      if let current = deviceConfig {
        try? store.writeRollingBackup(current)
      }

      let before = deviceConfig
      let changed = pendingChanges.map(\.block)
      for block in changed {
        let payload = working.bufferForWrite(block)
        try transport.setFeatureReport(
          id: DeviceProtocol.configReportID,
          payload: Array(payload.dropFirst()))
        Thread.sleep(forTimeInterval: 0.05)
      }

      try readConfig()

      if let readBack = deviceConfig {
        var rejected = 0
        var collateral = 0
        var landed = 0
        for block in changed {
          let result = WriteCheck.compare(
            before: before?.raw(block) ?? [],
            intended: working.raw(block),
            after: readBack.raw(block))
          rejected += result.rejected.count
          collateral += result.collateral.count
          landed += result.landed.count
        }

        if rejected > 0 && landed == 0 {
          lastError = Messages.writeRejected
          lastErrorDetail = Messages.writeRejectedDetail
          return false
        }
        if rejected > 0 || collateral > 0 {
          lastError = Messages.partialWrite(
            landed: landed, rejected: rejected,
            collateral: collateral)
          lastErrorDetail = nil
          return false
        }
      }

      lastError = nil
      lastErrorDetail = nil
      return true
    } catch {
      lastError = error.localizedDescription
      return false
    }
  }

  @discardableResult
  public func restoreOriginal() -> Bool {
    guard let original = store.originalBackup() else {
      lastError = "No original backup was found."
      return false
    }
    workingConfig = original
    return applyToDevice()
  }

  public func edit(_ mutate: (inout MouseConfig) -> Void) {
    guard var config = workingConfig else { return }
    mutate(&config)
    workingConfig = config
  }

  public func discardChanges() {
    workingConfig = deviceConfig
  }

  public func saveCurrentAsProfile(named name: String) {
    guard let config = workingConfig else { return }
    let profile = Profile(name: name, config: config, macros: macros)
    profiles.append(profile)
    persistProfiles()
  }

  public func apply(profile: Profile) {
    workingConfig = profile.config
    macros = profile.macros
  }

  public func deleteProfile(_ profile: Profile) {
    profiles.removeAll { $0.id == profile.id }
    persistProfiles()
  }

  public func renameProfile(_ profile: Profile, to name: String) {
    guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
    profiles[index].name = name
    profiles[index].modifiedAt = Date()
    persistProfiles()
  }

  public func updateProfileFromCurrent(_ profile: Profile) {
    guard let index = profiles.firstIndex(where: { $0.id == profile.id }),
      let config = workingConfig
    else { return }
    profiles[index].update(config: config)
    profiles[index].macros = macros
    persistProfiles()
  }

  private func persistProfiles() {
    do { try store.save(profiles) } catch {
      lastError = "Could not save profiles: \(error.localizedDescription)"
    }
  }

  @discardableResult
  public func scanForBlocks() -> String? {
    guard state.isConnected else {
      lastError = "Connect the mouse before scanning."
      return nil
    }
    isBusy = true
    defer { isBusy = false }

    var text = "Block scan — latch cmd 0x05 [NN], then read report 0x04\n"
    text += "Captured: \(ISO8601DateFormatter().string(from: Date()))\n\n"

    for command in UInt8(0x10)...UInt8(0x20) {
      try? transport.setFeatureReport(
        id: DeviceProtocol.commandReportID,
        payload: [command, 0, 0, 0, 0])
      Thread.sleep(forTimeInterval: 0.02)
      let result = transport.rawGetFeatureReport(
        id: DeviceProtocol.configReportID,
        length: DeviceProtocol.configReportSize)
      let known = ConfigBlock(rawValue: command) != nil ? "  [known]" : ""
      guard result.status == kIOReturnSuccess, result.actual > 0 else {
        text += String(
          format: "cmd 0x%02X -> no data (%@)\n",
          command, IOReturnNames.name(for: result.status))
        continue
      }
      let bytes = Array(result.buffer.prefix(result.actual))
      let echo = bytes.count > 1 ? bytes[1] : 0
      text += String(
        format: "cmd 0x%02X -> %3d bytes, echoes 0x%02X%@\n",
        command, result.actual, echo, known)
      text += MouseConfig.hexDump(bytes) + "\n\n"
    }

    try? transport.setFeatureReport(
      id: DeviceProtocol.commandReportID,
      payload: ConfigBlock.settings.command)
    Thread.sleep(forTimeInterval: 0.02)
    try? readConfig()

    if let base = try? FileManager.default.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil, create: true)
    {
      let url = base.appendingPathComponent("GloriousCTL/block-scan.txt")
      try? text.write(to: url, atomically: true, encoding: .utf8)
      diagnosticsPath = url.path
    }
    lastDiff = text
    return text
  }

  @Published public private(set) var snapshot: MouseConfig?
  @Published public private(set) var snapshotTakenAt: Date?
  @Published public private(set) var lastDiff: String?

  public func captureSnapshot() {
    guard state.isConnected else {
      lastError = "Connect the mouse before taking a snapshot."
      return
    }
    do {
      try readConfig()
      snapshot = deviceConfig
      snapshotTakenAt = Date()
      lastDiff = nil
      lastError = nil
    } catch {
      lastError = error.localizedDescription
    }
  }

  @discardableResult
  public func diffAgainstSnapshot() -> String? {
    guard let baseline = snapshot else {
      lastError = "Take a snapshot first."
      return nil
    }
    do {
      try readConfig()
    } catch {
      lastError = error.localizedDescription
      return nil
    }
    guard let current = deviceConfig else { return nil }

    var text = "Snapshot diff\n"
    if let snapshotTakenAt {
      text += "Baseline: \(ISO8601DateFormatter().string(from: snapshotTakenAt))\n"
    }
    text += "Now:      \(ISO8601DateFormatter().string(from: Date()))\n\n"

    var anyChange = false
    for block in ConfigBlock.allCases {
      let offsets = current.changedOffsets(comparedTo: baseline, in: block)
        .filter { $0 != ConfigLayout.reportID && $0 != ConfigLayout.blockCommand }
      if offsets.isEmpty { continue }
      anyChange = true
      text += "block 0x\(String(block.rawValue, radix: 16)) (\(block.displayName)):\n"
      let before = baseline.raw(block)
      let after = current.raw(block)
      for offset in offsets {
        text += String(
          format: "  0x%02X  %02X -> %02X   %@\n",
          offset, before[offset], after[offset],
          Self.fieldName(block: block, offset: offset))
      }
    }
    if !anyChange { text += "No bytes changed.\n" }

    lastDiff = text
    if let base = try? FileManager.default.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil, create: true)
    {
      let url = base.appendingPathComponent("GloriousCTL/snapshot-diff.txt")
      try? text.write(to: url, atomically: true, encoding: .utf8)
      diagnosticsPath = url.path
    }
    return text
  }

  private static func fieldName(block: ConfigBlock, offset: Int) -> String {
    if block == .buttons {
      let index = (offset - ConfigLayout.buttonMap) / ConfigLayout.buttonEntrySize
      if index >= 0, index < PhysicalButton.allCases.count {
        return "(\(PhysicalButton.allCases[index].displayName))"
      }
      return "(spare button entry \(index + 1))"
    }
    switch offset {
    case ConfigLayout.dpiStageCount: return "(DPI stage count)"
    case ConfigLayout.activeDPIStage: return "(active DPI stage)"
    case ConfigLayout.lightingEffect: return "(lighting effect)"
    case ConfigLayout.lightingBrightnessSpeed: return "(brightness / speed)"
    case ConfigLayout.dpiValues..<(ConfigLayout.dpiValues + ConfigLayout.dpiStageCountMax):
      return "(DPI stage \(offset - ConfigLayout.dpiValues + 1))"
    case ConfigLayout.dpiColors..<(ConfigLayout.dpiColors + 18):
      return "(DPI colour, stage \((offset - ConfigLayout.dpiColors) / 3 + 1))"
    default: return "*** UNMAPPED ***"
    }
  }

  public func runCommandWindowProbe() -> String {
    var log = "GloriousCTL — command window probe (read-only)\n"
    log += "Started: \(ISO8601DateFormatter().string(from: Date()))\n\n"

    guard state.isConnected else { return log + "FAIL: not connected\n" }
    do { try readConfig() } catch { return log + "FAIL: initial read failed\n" }
    guard let original = deviceConfig else { return log + "FAIL: no config\n" }

    let settings = original.raw(.settings)
    log += "settings 0x09-0x0D for reference: "
    log += settings[0x09...0x0D].map { String(format: "%02X", $0) }.joined(separator: " ")
    log += "\n\n"

    for command in [ConfigBlock.settings.rawValue, ConfigBlock.buttons.rawValue] {
      log += "=== latch command 0x\(String(command, radix: 16)) ===\n"
      for page in UInt8(0)...UInt8(7) {
        try? transport.setFeatureReport(
          id: DeviceProtocol.commandReportID,
          payload: [command, page, 0x00, 0x00, 0x00])
        Thread.sleep(forTimeInterval: 0.02)

        let window = transport.rawGetFeatureReport(
          id: DeviceProtocol.commandReportID,
          length: DeviceProtocol.commandReportSize)
        let block = transport.rawGetFeatureReport(
          id: DeviceProtocol.configReportID,
          length: DeviceProtocol.configReportSize)

        let windowBytes = Array(window.buffer.prefix(max(0, window.actual)))
        log += String(
          format: "  param=%02X  window(0x05)=[%@]  block(0x04)=%d bytes",
          page,
          windowBytes.map { String(format: "%02X", $0) }
            .joined(separator: " ") as NSString,
          block.actual)

        if windowBytes.count >= 6 {
          let payload = Array(windowBytes[1...5])
          if let match = (0...(settings.count - 5)).first(where: {
            Array(settings[$0..<($0 + 5)]) == payload
          }) {
            log += String(format: "  <- matches settings 0x%02X", match)
          }
        }
        log += "\n"
      }
      log += "\n"
    }

    try? transport.setFeatureReport(
      id: DeviceProtocol.commandReportID,
      payload: ConfigBlock.settings.command)
    Thread.sleep(forTimeInterval: 0.02)
    try? readConfig()

    if let final = deviceConfig {
      let drift = ConfigBlock.allCases.flatMap { block in
        final.changedOffsets(comparedTo: original, in: block)
          .filter { !WriteCheck.deviceManagedOffsets.contains($0) }
      }
      log +=
        drift.isEmpty
        ? "Configuration unchanged, as expected for a read-only probe.\n"
        : "WARNING: \(drift.count) byte(s) changed during a read-only probe.\n"
    }

    if let base = try? FileManager.default.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil, create: true)
    {
      let url = base.appendingPathComponent("GloriousCTL/command-window.txt")
      try? log.write(to: url, atomically: true, encoding: .utf8)
    }
    return log
  }

  public func runWriteStrategyProbe() -> String {
    var log = "GloriousCTL — write strategy probe\n"
    log += "Started: \(ISO8601DateFormatter().string(from: Date()))\n\n"

    guard state.isConnected else { return log + "FAIL: not connected\n" }
    do { try readConfig() } catch { return log + "FAIL: initial read failed\n" }
    guard let original = deviceConfig else { return log + "FAIL: no config\n" }
    try? store.writeRollingBackup(original)

    let stage = ConfigLayout.dpiStageCountMax - 1
    let targetOffset = ConfigLayout.dpiValues + stage
    let originalByte = original.raw(.settings)[targetOffset]
    let probeByte: UInt8 = originalByte == 0x62 ? 0x61 : 0x62

    log += String(
      format: "Target: settings block offset 0x%02X (DPI stage %d), %02X -> %02X\n\n",
      targetOffset, stage + 1, originalByte, probeByte)

    func probeBlock() -> [UInt8] {
      var bytes = original.raw(.settings)
      bytes[ConfigLayout.reportID] = DeviceProtocol.configReportID
      bytes[ConfigLayout.blockCommand] = ConfigBlock.settings.rawValue
      bytes[targetOffset] = probeByte
      return bytes
    }

    func padded(_ bytes: [UInt8]) -> [UInt8] {
      bytes + [UInt8](repeating: 0, count: max(0, DeviceProtocol.configReportSize - bytes.count))
    }

    func latch() {
      try? transport.setFeatureReport(
        id: DeviceProtocol.commandReportID,
        payload: ConfigBlock.settings.command)
      Thread.sleep(forTimeInterval: 0.02)
    }

    var winner: String?

    func strategy(_ name: String, _ perform: () throws -> Void) {
      guard winner == nil else { return }
      log += "[\(name)]\n"
      do { try perform() } catch {
        log += "  transport error: \(error.localizedDescription)\n\n"
        return
      }
      Thread.sleep(forTimeInterval: 0.08)
      try? readConfig()

      let after = deviceConfig?.raw(.settings)[targetOffset] ?? 0
      if after == probeByte {
        log += String(format: "  LANDED — byte is now %02X\n", after)
        winner = name
        var restore = original.raw(.settings)
        restore[ConfigLayout.reportID] = DeviceProtocol.configReportID
        restore[ConfigLayout.blockCommand] = ConfigBlock.settings.rawValue
        let payload = name.contains("520") ? padded(restore) : restore
        try? transport.setFeatureReport(
          id: DeviceProtocol.configReportID,
          payload: Array(payload.dropFirst()))
        Thread.sleep(forTimeInterval: 0.08)
        try? readConfig()
        let reverted = deviceConfig?.raw(.settings)[targetOffset] ?? 0
        log +=
          reverted == originalByte
          ? "  reverted cleanly\n\n"
          : String(format: "  WARNING: revert left %02X\n\n", reverted)
      } else {
        log += String(format: "  rejected — byte still %02X\n\n", after)
      }
    }

    strategy("A: plain write, 131 bytes") {
      try transport.setFeatureReport(
        id: DeviceProtocol.configReportID,
        payload: Array(probeBlock().dropFirst()))
    }

    strategy("B: zero-padded write, 520 bytes") {
      try transport.setFeatureReport(
        id: DeviceProtocol.configReportID,
        payload: Array(padded(probeBlock()).dropFirst()))
    }

    strategy("C: latch 0x11, then 131 bytes") {
      latch()
      try transport.setFeatureReport(
        id: DeviceProtocol.configReportID,
        payload: Array(probeBlock().dropFirst()))
    }

    strategy("D: latch 0x11, then 520 bytes") {
      latch()
      try transport.setFeatureReport(
        id: DeviceProtocol.configReportID,
        payload: Array(padded(probeBlock()).dropFirst()))
    }

    strategy("E: 131 bytes, then latch 0x11 as commit") {
      try transport.setFeatureReport(
        id: DeviceProtocol.configReportID,
        payload: Array(probeBlock().dropFirst()))
      Thread.sleep(forTimeInterval: 0.03)
      latch()
    }

    strategy("F: 520 bytes, then latch 0x11 as commit") {
      try transport.setFeatureReport(
        id: DeviceProtocol.configReportID,
        payload: Array(padded(probeBlock()).dropFirst()))
      Thread.sleep(forTimeInterval: 0.03)
      latch()
    }

    for block in ConfigBlock.allCases {
      var bytes = original.raw(block)
      bytes[ConfigLayout.reportID] = DeviceProtocol.configReportID
      bytes[ConfigLayout.blockCommand] = block.rawValue
      try? transport.setFeatureReport(
        id: DeviceProtocol.configReportID,
        payload: Array(padded(bytes).dropFirst()))
      Thread.sleep(forTimeInterval: 0.05)
    }
    try? readConfig()
    workingConfig = deviceConfig

    if let final = deviceConfig {
      let drift = ConfigBlock.allCases.flatMap { block in
        final.changedOffsets(comparedTo: original, in: block)
          .filter { !WriteCheck.deviceManagedOffsets.contains($0) }
      }
      log +=
        drift.isEmpty
        ? "Device matches its original state.\n"
        : "WARNING: \(drift.count) byte(s) differ from original.\n"
    }

    log +=
      winner.map { "\nWorking strategy: \($0)\n" }
      ?? "\nNo strategy landed. The device is refusing writes at this framing.\n"

    if let base = try? FileManager.default.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil, create: true)
    {
      let url = base.appendingPathComponent("GloriousCTL/write-probe.txt")
      try? log.write(to: url, atomically: true, encoding: .utf8)
    }
    return log
  }

  public func runWriteSelfTest() -> String {
    var log = "GloriousCTL — write self-test\n"
    log += "Started: \(ISO8601DateFormatter().string(from: Date()))\n\n"

    guard state.isConnected else {
      return log + "FAIL: not connected (\(lastError ?? "unknown"))\n"
    }
    do { try readConfig() } catch {
      return log + "FAIL: could not read initial config — \(error.localizedDescription)\n"
    }
    guard let original = deviceConfig else { return log + "FAIL: no config after read\n" }

    try? store.writeOriginalBackupIfNeeded(original)
    try? store.writeRollingBackup(original)
    log += "Backed up both blocks before touching anything.\n\n"

    var passed = 0
    var failed = 0

    func attempt(
      _ name: String, _ block: ConfigBlock,
      _ mutate: (inout MouseConfig) -> Void
    ) -> Bool {
      guard let before = deviceConfig else { return false }
      var intended = before
      mutate(&intended)

      log += "[\(name)]\n"
      let plannedChanges = intended.changedOffsets(comparedTo: before, in: block)
      log +=
        "  intended: "
        + (plannedChanges.isEmpty
          ? "no byte changes (idempotent write)"
          : plannedChanges.map { offset in
            String(
              format: "0x%02X %02X->%02X", offset,
              before.raw(block)[offset], intended.raw(block)[offset])
          }.joined(separator: ", ")) + "\n"

      do {
        try transport.setFeatureReport(
          id: DeviceProtocol.configReportID,
          payload: Array(intended.bufferForWrite(block).dropFirst()))
        Thread.sleep(forTimeInterval: 0.06)
        try readConfig()
      } catch {
        log += "  FAIL: \(error.localizedDescription)\n\n"
        failed += 1
        return false
      }

      guard let after = deviceConfig else {
        failed += 1
        return false
      }
      let result = WriteCheck.compare(
        before: before.raw(block),
        intended: intended.raw(block),
        after: after.raw(block))
      log += "  result:   \(result.summary)\n"

      let otherBlock: ConfigBlock = block == .settings ? .buttons : .settings
      let bled = after.changedOffsets(comparedTo: before, in: otherBlock)
        .filter { !WriteCheck.deviceManagedOffsets.contains($0) }
      if !bled.isEmpty {
        log += "  WARNING: writing \(block.displayName) also changed "
        log += "\(bled.count) byte(s) in \(otherBlock.displayName)\n"
      }

      log += result.passed && bled.isEmpty ? "  PASS\n\n" : "  FAIL\n\n"
      if result.passed && bled.isEmpty { passed += 1 } else { failed += 1 }
      return result.passed && bled.isEmpty
    }

    _ = attempt("idempotent write — settings block", .settings) { _ in }
    _ = attempt("idempotent write — buttons block", .buttons) { _ in }

    let stage = ConfigLayout.dpiStageCountMax - 1
    let originalDPI = original.dpi(atStage: stage)
    let probeDPI = originalDPI == 9900 ? 9800 : 9900
    _ = attempt("single byte — DPI stage \(stage + 1) -> \(probeDPI)", .settings) {
      $0.setDPI(probeDPI, atStage: stage)
    }
    _ = attempt("revert — DPI stage \(stage + 1) -> \(originalDPI)", .settings) {
      $0.setDPI(originalDPI, atStage: stage)
    }

    let originalBrightness = original.brightness
    let probeBrightness: Brightness = originalBrightness == .medium ? .low : .medium
    if original.lightingEffect != .off {
      log += "Dimming the LEDs to \(probeBrightness.percent)% for two seconds — "
      log += "watch the mouse.\n"
      _ = attempt("visible — brightness -> \(probeBrightness.percent)%", .settings) {
        $0.brightness = probeBrightness
      }
      Thread.sleep(forTimeInterval: 2.0)
      _ = attempt("revert — brightness -> \(originalBrightness.percent)%", .settings) {
        $0.brightness = originalBrightness
      }
    }

    log += "[final restore]\n"
    for block in ConfigBlock.allCases {
      try? transport.setFeatureReport(
        id: DeviceProtocol.configReportID,
        payload: Array(original.bufferForWrite(block).dropFirst()))
      Thread.sleep(forTimeInterval: 0.06)
    }
    try? readConfig()

    if let final = deviceConfig {
      var drift: [String] = []
      for block in ConfigBlock.allCases {
        let changed = final.changedOffsets(comparedTo: original, in: block)
          .filter { !WriteCheck.deviceManagedOffsets.contains($0) }
        if !changed.isEmpty {
          drift.append(
            "\(block.displayName): "
              + changed.map {
                String(format: "0x%02X", $0)
              }.joined(separator: ", "))
        }
      }
      if drift.isEmpty {
        log += "  Device matches its original state exactly. PASS\n"
        passed += 1
      } else {
        log += "  Device differs from original — " + drift.joined(separator: "; ") + "\n"
        log += "  Use Profiles > Restore Original Config to recover. FAIL\n"
        failed += 1
      }
    }
    workingConfig = deviceConfig

    log += "\n\(passed) passed, \(failed) failed\n"

    if let base = try? FileManager.default.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil, create: true)
    {
      let url = base.appendingPathComponent("GloriousCTL/write-selftest.txt")
      try? log.write(to: url, atomically: true, encoding: .utf8)
      diagnosticsPath = url.path
    }
    return log
  }

  @discardableResult
  public func runReadDiagnostics() -> String? {
    guard state.isConnected else {
      lastError = "Connect the mouse before running diagnostics."
      return nil
    }
    isBusy = true
    defer { isBusy = false }

    let diagnostics = ReadDiagnostics(transport: transport)
    let text = diagnostics.report(
      interfaces: HIDTransport.enumerateInterfaces(),
      descriptor: HIDTransport.configInterfaceReportDescriptor())

    let base = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask)[0]
      .appendingPathComponent("GloriousCTL", isDirectory: true)
    try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    let url = base.appendingPathComponent("read-diagnostics.txt")

    do {
      try text.write(to: url, atomically: true, encoding: .utf8)
      diagnosticsPath = url.path
      lastError = nil
    } catch {
      lastError = "Could not write diagnostics: \(error.localizedDescription)"
      return nil
    }

    try? readConfig()
    return url.path
  }

  public func exportConfigDump(to url: URL) throws {
    guard let config = deviceConfig else { return }
    var text = "Glorious Model O — configuration dump\n"
    text += "Captured: \(ISO8601DateFormatter().string(from: Date()))\n"
    if case .connected(let info) = state {
      text += String(
        format: "Device: VID 0x%04X PID 0x%04X — %@\n",
        info.vendorID, info.productID, info.product)
      text += "Interface: usagePage 0x\(String(info.usagePage, radix: 16)), "
      text += "usage 0x\(String(info.usage, radix: 16)), "
      text += "maxFeatureReport \(info.maxFeatureReportSize)\n"
    }
    for block in ConfigBlock.allCases {
      text += "\n--- block 0x\(String(block.rawValue, radix: 16)) "
      text += "(\(block.length) bytes) ---\n"
      text += config.hexDump(block) + "\n"
    }
    if let validator {
      text +=
        "\nLayout validation: \(validator.passedCount)/\(validator.checks.count) checks passed\n"
      for check in validator.checks {
        let mark = check.passed ? "ok  " : "WARN"
        text += String(
          format: "  [%@] 0x%03X %-22@ %@ -> %@\n",
          mark, check.offset, check.field as NSString,
          check.rawValue, check.interpretation)
      }
    }
    try text.write(to: url, atomically: true, encoding: .utf8)
  }
}
