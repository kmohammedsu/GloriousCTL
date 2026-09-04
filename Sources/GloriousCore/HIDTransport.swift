import Foundation
import IOKit
import IOKit.hid

public enum HIDError: Error, LocalizedError, Equatable {
  case deviceNotFound
  case permissionDenied
  case openFailed(IOReturn)
  case setReportFailed(IOReturn)
  case getReportFailed(IOReturn)
  case shortRead(expected: Int, got: Int)
  case blockMismatch(expected: UInt8, got: UInt8)
  case notConnected

  public var errorDescription: String? {
    switch self {
    case .deviceNotFound:
      return "No Glorious mouse found. Plug it in over USB (not through a KVM) and try again."
    case .permissionDenied:
      return
        "macOS blocked access to the mouse. Grant GloriousCTL permission under System Settings › Privacy & Security › Input Monitoring, then relaunch."
    case .openFailed(let r):
      return "Could not open the device: \(IOReturnNames.describe(r))."
    case .setReportFailed(let r):
      return "Writing to the mouse failed: \(IOReturnNames.describe(r))."
    case .getReportFailed(let r):
      return "Reading from the mouse failed: \(IOReturnNames.describe(r))."
    case .shortRead(let e, let g):
      return "Short read from the mouse: expected \(e) bytes, got \(g)."
    case .blockMismatch(let expected, let got):
      return String(
        format: "The mouse returned config block 0x%02X when 0x%02X was requested.", got, expected)
    case .notConnected:
      return "The mouse is not connected."
    }
  }
}

private let kIOReturnNotPermittedValue: IOReturn = IOReturn(bitPattern: 0xE000_02E2)
private let kIOReturnNotPrivilegedValue: IOReturn = IOReturn(bitPattern: 0xE000_02C1)

public struct HIDInterfaceInfo: Sendable, Equatable {
  public let vendorID: Int
  public let productID: Int
  public let usagePage: Int
  public let usage: Int
  public let maxFeatureReportSize: Int
  public let maxInputReportSize: Int
  public let product: String
  public let manufacturer: String
  public let locationID: Int
}

public final class HIDTransport {

  public static let vendorIDSinowealth = 0x258A

  private var manager: IOHIDManager?
  private var device: IOHIDDevice?
  private var opened = false
  public private(set) var info: HIDInterfaceInfo?

  public init() {}

  deinit { close() }

  public static func enumerateInterfaces() -> [HIDInterfaceInfo] {
    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: vendorIDSinowealth] as CFDictionary)
    IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    defer { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }

    guard let set = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return [] }
    return set.compactMap { Self.describe($0) }
      .sorted { $0.maxFeatureReportSize > $1.maxFeatureReportSize }
  }

  private static func describe(_ device: IOHIDDevice) -> HIDInterfaceInfo? {
    func intProp(_ key: String) -> Int {
      (IOHIDDeviceGetProperty(device, key as CFString) as? Int) ?? 0
    }
    func strProp(_ key: String) -> String {
      (IOHIDDeviceGetProperty(device, key as CFString) as? String) ?? ""
    }
    return HIDInterfaceInfo(
      vendorID: intProp(kIOHIDVendorIDKey),
      productID: intProp(kIOHIDProductIDKey),
      usagePage: intProp(kIOHIDPrimaryUsagePageKey),
      usage: intProp(kIOHIDPrimaryUsageKey),
      maxFeatureReportSize: intProp(kIOHIDMaxFeatureReportSizeKey),
      maxInputReportSize: intProp(kIOHIDMaxInputReportSizeKey),
      product: strProp(kIOHIDProductKey),
      manufacturer: strProp(kIOHIDManufacturerKey),
      locationID: intProp(kIOHIDLocationIDKey)
    )
  }

  public static func configInterfaceReportDescriptor() -> Data? {
    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: vendorIDSinowealth] as CFDictionary)
    IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    defer { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }
    guard let set = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return nil }
    for device in set {
      let size =
        (IOHIDDeviceGetProperty(device, kIOHIDMaxFeatureReportSizeKey as CFString) as? Int) ?? 0
      if size == DeviceProtocol.configReportSize {
        return IOHIDDeviceGetProperty(device, "ReportDescriptor" as CFString) as? Data
      }
    }
    return nil
  }

  public var isConnected: Bool { device != nil && opened }

  @discardableResult
  public func connect() throws -> HIDInterfaceInfo {
    close()

    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    IOHIDManagerSetDeviceMatching(
      manager, [kIOHIDVendorIDKey: Self.vendorIDSinowealth] as CFDictionary)
    IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    self.manager = manager

    guard let set = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>, !set.isEmpty else {
      throw HIDError.deviceNotFound
    }

    let candidate = set.first { device in
      let size =
        (IOHIDDeviceGetProperty(device, kIOHIDMaxFeatureReportSizeKey as CFString) as? Int) ?? 0
      return size == DeviceProtocol.configReportSize
    }

    guard let target = candidate else { throw HIDError.deviceNotFound }

    let result = IOHIDDeviceOpen(target, IOOptionBits(kIOHIDOptionsTypeNone))
    guard result == kIOReturnSuccess else {
      if result == kIOReturnNotPermittedValue || result == kIOReturnNotPrivilegedValue {
        throw HIDError.permissionDenied
      }
      throw HIDError.openFailed(result)
    }

    IOHIDDeviceScheduleWithRunLoop(target, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

    device = target
    opened = true
    info = Self.describe(target)
    return info!
  }

  public func close() {
    if let device, opened {
      IOHIDDeviceUnscheduleFromRunLoop(
        device, CFRunLoopGetMain(),
        CFRunLoopMode.defaultMode.rawValue)
      IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
    }
    if let manager {
      IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }
    manager = nil
    device = nil
    opened = false
    info = nil
  }

  private func recoverStaleHandle() -> Bool {
    guard (try? connect()) != nil else { return false }
    return true
  }

  public func setFeatureReport(id: UInt8, payload: [UInt8]) throws {
    guard let device, opened else { throw HIDError.notConnected }
    var buffer = [id] + payload
    var result = IOHIDDeviceSetReport(
      device, kIOHIDReportTypeFeature,
      CFIndex(id), &buffer, buffer.count)

    if result == IOReturn(bitPattern: 0xE000_02CD), recoverStaleHandle(),
      let retryDevice = self.device
    {
      var retryBuffer = [id] + payload
      result = IOHIDDeviceSetReport(
        retryDevice, kIOHIDReportTypeFeature,
        CFIndex(id), &retryBuffer, retryBuffer.count)
    }

    guard result == kIOReturnSuccess else { throw HIDError.setReportFailed(result) }
  }

  public func rawGetFeatureReport(id: UInt8, length: Int) -> (
    status: IOReturn, buffer: [UInt8], actual: Int
  ) {
    guard let device, opened else {
      return (IOReturn(bitPattern: 0xE000_02CD), [], 0)
    }
    var buffer = [UInt8](repeating: 0, count: length)
    buffer[0] = id
    var actual = length
    let status = IOHIDDeviceGetReport(
      device, kIOHIDReportTypeFeature,
      CFIndex(id), &buffer, &actual)
    return (status, buffer, actual)
  }

  public func getFeatureReport(id: UInt8, length: Int) throws -> (buffer: [UInt8], actual: Int) {
    guard let device, opened else { throw HIDError.notConnected }
    var buffer = [UInt8](repeating: 0, count: length)
    buffer[0] = id
    var actual = length
    var result = IOHIDDeviceGetReport(
      device, kIOHIDReportTypeFeature,
      CFIndex(id), &buffer, &actual)

    if result == IOReturn(bitPattern: 0xE000_02CD), recoverStaleHandle(),
      let retryDevice = self.device
    {
      buffer = [UInt8](repeating: 0, count: length)
      buffer[0] = id
      actual = length
      result = IOHIDDeviceGetReport(
        retryDevice, kIOHIDReportTypeFeature,
        CFIndex(id), &buffer, &actual)
    }

    guard result == kIOReturnSuccess else { throw HIDError.getReportFailed(result) }
    return (buffer, actual)
  }
}
