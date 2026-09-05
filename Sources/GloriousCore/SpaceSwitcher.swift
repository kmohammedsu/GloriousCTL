import ColorSync
import CoreGraphics
import Foundation

/// Moves between desktops by asking the window server directly.
///
/// The obvious route — synthesising the Ctrl+arrow that macOS binds to "move left a
/// space" — proved unreliable: the keystroke is constructed correctly and posted, but
/// the window server frequently ignores it, and whether it lands is not something the
/// app can detect or influence. It also breaks entirely if the user has unbound or
/// remapped that shortcut, which is a setting the app has no business depending on.
///
/// SkyLight is private, so every symbol is resolved at runtime and any failure leaves
/// `isAvailable` false, letting the caller fall back to the keystroke. Nothing here
/// can crash the app if Apple changes or removes these functions.
public enum SpaceSwitcher {

  public enum Direction: Equatable, Sendable {
    case left, right

    var step: Int { self == .left ? -1 : 1 }
  }

  private typealias MainConnectionID = @convention(c) () -> Int32
  private typealias CopyManagedDisplaySpaces = @convention(c) (Int32) -> Unmanaged<CFArray>?
  private typealias SetCurrentSpace = @convention(c) (Int32, CFString, UInt64) -> Void

  private struct Symbols {
    let connection: MainConnectionID
    let copySpaces: CopyManagedDisplaySpaces
    let setSpace: SetCurrentSpace
  }

  private nonisolated(unsafe) static let symbols: Symbols? = {
    let path =
      "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight"
    guard let handle = dlopen(path, RTLD_LAZY),
      let connection = dlsym(handle, "SLSMainConnectionID"),
      let copySpaces = dlsym(handle, "SLSCopyManagedDisplaySpaces"),
      let setSpace = dlsym(handle, "SLSManagedDisplaySetCurrentSpace")
    else { return nil }
    return Symbols(
      connection: unsafeBitCast(connection, to: MainConnectionID.self),
      copySpaces: unsafeBitCast(copySpaces, to: CopyManagedDisplaySpaces.self),
      setSpace: unsafeBitCast(setSpace, to: SetCurrentSpace.self))
  }()

  public static var isAvailable: Bool { symbols != nil }

  /// Index of the desktop to move to, or nil at either end. Kept separate from the
  /// private API so the wrapping behaviour is testable.
  public static func targetIndex(current: Int, count: Int, step: Int) -> Int? {
    guard count > 1, current >= 0, current < count else { return nil }
    let target = current + step
    guard target >= 0, target < count else { return nil }
    return target
  }

  /// Switches the desktop on the display under the pointer, so on a multi-display
  /// setup the gesture acts where the user is looking rather than on all of them.
  @discardableResult
  public static func move(_ direction: Direction) -> Bool {
    guard let symbols else { return false }
    let cid = symbols.connection()
    guard let displays = symbols.copySpaces(cid)?.takeRetainedValue() as? [[String: Any]]
    else { return false }

    let preferred = displayUUIDUnderPointer()
    let ordered =
      displays.sorted { lhs, _ in
        (lhs["Display Identifier"] as? String) == preferred
      }

    for display in ordered {
      guard let identifier = display["Display Identifier"] as? String,
        let spaces = display["Spaces"] as? [[String: Any]],
        let current = display["Current Space"] as? [String: Any],
        let currentID = current["ManagedSpaceID"] as? UInt64
      else { continue }

      let ids = spaces.compactMap { $0["ManagedSpaceID"] as? UInt64 }
      guard let index = ids.firstIndex(of: currentID),
        let target = targetIndex(current: index, count: ids.count, step: direction.step)
      else { continue }

      symbols.setSpace(cid, identifier as CFString, ids[target])
      return true
    }
    return false
  }

  /// The window server identifies displays by UUID string; map the pointer's screen
  /// to one so the right display is switched.
  private static func displayUUIDUnderPointer() -> String? {
    guard let location = CGEvent(source: nil)?.location else { return nil }
    var displayID = CGDirectDisplayID()
    var count: UInt32 = 0
    guard CGGetDisplaysWithPoint(location, 1, &displayID, &count) == .success,
      count > 0,
      let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue()
    else { return nil }
    return CFUUIDCreateString(nil, uuid) as String?
  }
}
