import Foundation

@testable import GloriousCore

enum Fixtures {

  static func bytes(_ hex: String) -> [UInt8] {
    hex.split(whereSeparator: { $0 == " " || $0 == "\n" })
      .compactMap { UInt8($0, radix: 16) }
  }

  static let settingsBlock = bytes(
    """
    04 11 00 00 00 00 00 00 64 06 04 44 F0 03 07 0F
    1F 31 63 00 00 00 00 00 00 00 00 00 00 FF FF 00
    00 00 FF FF 00 00 00 FF 00 FF 00 FF FF FF FF 00
    00 00 00 00 00 01 43 00 40 FF 00 00 42 07 FF 00
    00 00 FF 00 00 00 FF 00 FF FF FF FF 00 FF 00 FF
    FF FF FF 42 42 00 FF 00 00 00 FF 00 00 00 FF FF
    FF 00 00 FF FF FF FF FF FA 00 FF FF 00 00 FF 00
    00 FF 00 00 42 FF 00 00 00 FF 00 02 42 02 FF 00
    00 01 00
    """)

  static let buttonsBlock = bytes(
    """
    04 12 00 00 00 00 00 00 11 01 00 00 11 02 00 00
    11 04 00 00 21 01 19 00 21 01 06 00 41 00 00 00
    50 01 00 00 50 01 00 00 50 01 00 00 50 01 00 00
    50 01 00 00 50 01 00 00 50 01 00 00 50 01 00 00
    50 01 00 00 50 01 00 00 50 01 00 00 50 01 00 00
    50 01 00 00 50 01 00 00
    """)

  static var config: MouseConfig {
    MouseConfig(settings: settingsBlock, buttons: buttonsBlock)
  }
}
