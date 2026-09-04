import Foundation

public struct Profile: Codable, Identifiable, Hashable, Sendable {
  public var id: UUID
  public var name: String
  public var createdAt: Date
  public var modifiedAt: Date
  public var rawSettings: Data
  public var rawButtons: Data
  public var macros: [Macro]
  public var autoSwitchBundleID: String?

  public init(
    id: UUID = UUID(), name: String, config: MouseConfig,
    macros: [Macro] = [], autoSwitchBundleID: String? = nil
  ) {
    self.id = id
    self.name = name
    self.createdAt = Date()
    self.modifiedAt = Date()
    self.rawSettings = Data(config.raw(.settings))
    self.rawButtons = Data(config.raw(.buttons))
    self.macros = macros
    self.autoSwitchBundleID = autoSwitchBundleID
  }

  public var config: MouseConfig {
    MouseConfig(settings: [UInt8](rawSettings), buttons: [UInt8](rawButtons))
  }

  public mutating func update(config: MouseConfig) {
    rawSettings = Data(config.raw(.settings))
    rawButtons = Data(config.raw(.buttons))
    modifiedAt = Date()
  }
}

public final class ProfileStore {

  public static let shared = ProfileStore()

  private let directory: URL
  private let fileManager = FileManager.default

  public init(directory: URL? = nil) {
    if let directory {
      self.directory = directory
    } else {
      let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      self.directory = base.appendingPathComponent("GloriousCTL", isDirectory: true)
    }
    try? fileManager.createDirectory(at: self.directory, withIntermediateDirectories: true)
  }

  private var profilesURL: URL { directory.appendingPathComponent("profiles.json") }
  public var backupsDirectory: URL {
    directory.appendingPathComponent("backups", isDirectory: true)
  }

  public func load() -> [Profile] {
    guard let data = try? Data(contentsOf: profilesURL) else { return [] }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return (try? decoder.decode([Profile].self, from: data)) ?? []
  }

  public func save(_ profiles: [Profile]) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    try encoder.encode(profiles).write(to: profilesURL, options: .atomic)
  }

  public func writeOriginalBackupIfNeeded(_ config: MouseConfig) throws {
    try fileManager.createDirectory(at: backupsDirectory, withIntermediateDirectories: true)
    for block in ConfigBlock.allCases {
      let url =
        backupsDirectory
        .appendingPathComponent("original-\(block.filename).bin")
      guard !fileManager.fileExists(atPath: url.path) else { continue }
      try Data(config.raw(block)).write(to: url, options: .atomic)
    }
  }

  public func originalBackup() -> MouseConfig? {
    func read(_ block: ConfigBlock) -> [UInt8]? {
      let url = backupsDirectory.appendingPathComponent("original-\(block.filename).bin")
      guard let data = try? Data(contentsOf: url) else { return nil }
      return [UInt8](data)
    }
    guard let settings = read(.settings), let buttons = read(.buttons) else { return nil }
    return MouseConfig(settings: settings, buttons: buttons)
  }

  public func writeRollingBackup(_ config: MouseConfig) throws {
    try fileManager.createDirectory(at: backupsDirectory, withIntermediateDirectories: true)
    let stamp = ISO8601DateFormatter().string(from: Date())
      .replacingOccurrences(of: ":", with: "-")
    for block in ConfigBlock.allCases {
      let url =
        backupsDirectory
        .appendingPathComponent("config-\(stamp)-\(block.filename).bin")
      try Data(config.raw(block)).write(to: url, options: .atomic)
    }
    pruneRollingBackups(keeping: 20)
  }

  private func pruneRollingBackups(keeping limit: Int) {
    guard
      let items = try? fileManager.contentsOfDirectory(
        at: backupsDirectory, includingPropertiesForKeys: [.creationDateKey])
    else { return }
    let rolling =
      items
      .filter { $0.lastPathComponent.hasPrefix("config-") }
      .sorted { $0.lastPathComponent > $1.lastPathComponent }
    for url in rolling.dropFirst(limit) { try? fileManager.removeItem(at: url) }
  }
}
