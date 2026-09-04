import Foundation

public enum Messages {

  public static let maxLength = 150

  public static let writeRejected =
    "The mouse accepted the write but kept its previous values. Nothing on the device changed."

  public static let writeRejectedDetail = """
    The device acknowledged the HID report and then discarded it. Writes normally require \
    the payload length in header byte 3 and the full 520-byte report; if those are correct \
    and the write is still refused, the mouse may have been unplugged mid-write or another \
    application may be holding the configuration interface. Nothing on the mouse was changed \
    — use Restore Original Config if anything looks wrong.
    """

  public static func partialWrite(landed: Int, rejected: Int, collateral: Int) -> String {
    "Partial write: \(landed) applied, \(rejected) rejected, \(collateral) unexpected. "
      + "Restore Original Config if anything looks wrong."
  }

  public static func readBackMismatch(count: Int, block: String, offset: Int) -> String {
    String(
      format: "%d byte(s) read back differently, first in %@ at 0x%02X.",
      count, block, offset)
  }
}
