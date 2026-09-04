import Combine
import XCTest

@testable import GloriousCore

@MainActor
final class ObservationTests: XCTestCase {

  private var cancellables: Set<AnyCancellable> = []

  func testGestureEngineChangesReachTheController() {
    let controller = DeviceController(store: ProfileStore(directory: scratchDirectory()))
    let notified = expectation(description: "controller published")
    notified.assertForOverFulfill = false

    controller.objectWillChange.sink { notified.fulfill() }.store(in: &cancellables)
    controller.gestures.bindings[.back] = GestureBinding.defaultBinding(for: .back)

    wait(for: [notified], timeout: 1.0)
  }

  func testAppSwitcherChangesReachTheController() {
    let controller = DeviceController(store: ProfileStore(directory: scratchDirectory()))
    let notified = expectation(description: "controller published")
    notified.assertForOverFulfill = false

    controller.objectWillChange.sink { notified.fulfill() }.store(in: &cancellables)
    controller.appSwitcher.isEnabled = true

    wait(for: [notified], timeout: 1.0)
  }

  private func scratchDirectory() -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("gloriousctl-tests-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }
}
