import Foundation
import IOKit

public enum IOReturnNames {

  private static let names: [UInt32: (String, String)] = [
    0xE000_02BC: ("kIOReturnError", "general IOKit error"),
    0xE000_02BD: ("kIOReturnNoMemory", "out of memory"),
    0xE000_02BE: ("kIOReturnNoResources", "resource shortage"),
    0xE000_02C0: ("kIOReturnNoDevice", "the device went away"),
    0xE000_02C1: ("kIOReturnNotPrivileged", "missing privileges"),
    0xE000_02C2: ("kIOReturnBadArgument", "bad argument"),
    0xE000_02C5: ("kIOReturnExclusiveAccess", "another app has the device open exclusively"),
    0xE000_02C7: ("kIOReturnUnsupported", "the device does not support this request"),
    0xE000_02CA: ("kIOReturnIOError", "I/O error"),
    0xE000_02CC: ("kIOReturnCannotLock", "could not lock the device"),
    0xE000_02CD: ("kIOReturnNotOpen", "the device handle is not open"),
    0xE000_02CE: ("kIOReturnNotReadable", "not readable"),
    0xE000_02CF: ("kIOReturnNotWritable", "not writable"),
    0xE000_02D4: ("kIOReturnBadMedia", "bad media"),
    0xE000_02D6: ("kIOReturnRLDError", "RLD error"),
    0xE000_02D9: ("kIOReturnBusy", "the device is busy"),
    0xE000_02DA: ("kIOReturnTimeout", "the device did not respond in time"),
    0xE000_02DB: ("kIOReturnOffline", "the device is offline"),
    0xE000_02DC: ("kIOReturnNotReady", "the device is not ready"),
    0xE000_02DD: ("kIOReturnNotAttached", "the device is not attached"),
    0xE000_02E2: ("kIOReturnNotPermitted", "macOS denied access (Input Monitoring)"),
  ]

  public static func name(for code: IOReturn) -> String {
    let raw = UInt32(bitPattern: code)
    if let entry = names[raw] { return entry.0 }
    return String(format: "0x%08X", raw)
  }

  public static func describe(_ code: IOReturn) -> String {
    let raw = UInt32(bitPattern: code)
    if let entry = names[raw] {
      return String(format: "%@ (0x%08X) — %@", entry.0, raw, entry.1)
    }
    return String(format: "IOReturn 0x%08X", raw)
  }
}
