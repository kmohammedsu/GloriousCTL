import Foundation

public enum WriteCheck {

  public struct Result: Equatable, Sendable {
    public let landed: [Int]
    public let rejected: [Int]
    public let collateral: [Int]

    public var passed: Bool { rejected.isEmpty && collateral.isEmpty }

    public var summary: String {
      if passed {
        return landed.isEmpty
          ? "no change intended; device unchanged"
          : "\(landed.count) byte(s) landed exactly"
      }
      var parts: [String] = []
      if !landed.isEmpty { parts.append("\(landed.count) landed") }
      if !rejected.isEmpty {
        parts.append(
          "\(rejected.count) rejected ("
            + rejected.prefix(4).map { String(format: "0x%02X", $0) }
            .joined(separator: ", ") + ")")
      }
      if !collateral.isEmpty {
        parts.append(
          "\(collateral.count) collateral ("
            + collateral.prefix(4).map { String(format: "0x%02X", $0) }
            .joined(separator: ", ") + ")")
      }
      return parts.joined(separator: ", ")
    }
  }

  public static let deviceManagedOffsets: Set<Int> = [
    ConfigLayout.reportID, ConfigLayout.blockCommand,
  ]

  public static func compare(before: [UInt8], intended: [UInt8], after: [UInt8]) -> Result {
    var landed: [Int] = []
    var rejected: [Int] = []
    var collateral: [Int] = []
    let count = min(before.count, min(intended.count, after.count))

    for offset in 0..<count where !deviceManagedOffsets.contains(offset) {
      let wasIntendedToChange = intended[offset] != before[offset]
      let actuallyChanged = after[offset] != before[offset]

      if wasIntendedToChange {
        if after[offset] == intended[offset] {
          landed.append(offset)
        } else {
          rejected.append(offset)
        }
      } else if actuallyChanged {
        collateral.append(offset)
      }
    }
    return Result(landed: landed, rejected: rejected, collateral: collateral)
  }
}
