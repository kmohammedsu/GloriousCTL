import AppKit
import Combine
import Foundation

public struct ProfileMatcher: Sendable {

  public init() {}

  public func profile(for bundleID: String?, in profiles: [Profile]) -> Profile? {
    if let bundleID {
      if let exact = profiles.first(where: {
        $0.autoSwitchBundleID?.caseInsensitiveCompare(bundleID) == .orderedSame
      }) {
        return exact
      }
    }
    return profiles.first { $0.autoSwitchBundleID == nil }
  }
}

@MainActor
public final class AppProfileSwitcher: ObservableObject {

  @Published public var isEnabled = false
  @Published public private(set) var currentBundleID: String?
  @Published public private(set) var lastApplied: String?

  private let matcher = ProfileMatcher()
  private var observer: NSObjectProtocol?
  private var pendingWork: DispatchWorkItem?

  public var debounceInterval: TimeInterval = 0.6

  public var profilesProvider: () -> [Profile] = { [] }
  public var applyProfile: (Profile) -> Void = { _ in }
  public var isAlreadyActive: (Profile) -> Bool = { _ in false }

  public init() {}

  public func start() {
    guard observer == nil else { return }
    observer = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification,
      object: nil, queue: .main
    ) { [weak self] note in
      let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
      MainActor.assumeIsolated {
        self?.frontmostChanged(to: app?.bundleIdentifier)
      }
    }
    frontmostChanged(to: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
  }

  public func stop() {
    if let observer {
      NSWorkspace.shared.notificationCenter.removeObserver(observer)
    }
    observer = nil
    pendingWork?.cancel()
    pendingWork = nil
  }

  func frontmostChanged(to bundleID: String?) {
    currentBundleID = bundleID
    guard isEnabled else { return }

    pendingWork?.cancel()
    let work = DispatchWorkItem { [weak self] in
      MainActor.assumeIsolated { self?.applyIfNeeded(for: bundleID) }
    }
    pendingWork = work
    DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: work)
  }

  private func applyIfNeeded(for bundleID: String?) {
    guard let profile = matcher.profile(for: bundleID, in: profilesProvider()) else { return }
    guard !isAlreadyActive(profile) else { return }
    applyProfile(profile)
    lastApplied = profile.name
  }
}
