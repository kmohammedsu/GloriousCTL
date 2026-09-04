import XCTest

@testable import GloriousCore

final class GestureRecognizerTests: XCTestCase {

  private let recognizer = GestureRecognizer(threshold: 22, dominanceRatio: 1.3)

  func testNoMovementIsATap() {
    XCTAssertEqual(recognizer.classify(dx: 0, dy: 0), .tap)
  }

  func testSmallJitterIsStillATap() {
    XCTAssertEqual(recognizer.classify(dx: 4, dy: -6), .tap)
    XCTAssertEqual(recognizer.classify(dx: -21, dy: 0), .tap)
  }

  func testClearDragsClassifyByDirection() {
    XCTAssertEqual(recognizer.classify(dx: 0, dy: -80), .up)
    XCTAssertEqual(recognizer.classify(dx: 0, dy: 80), .down)
    XCTAssertEqual(recognizer.classify(dx: -80, dy: 0), .left)
    XCTAssertEqual(recognizer.classify(dx: 80, dy: 0), .right)
  }

  func testUpIsNegativeInScreenCoordinates() {
    XCTAssertEqual(recognizer.classify(dx: 0, dy: -100), .up)
  }

  func testDominantAxisWinsOnADiagonal() {
    XCTAssertEqual(recognizer.classify(dx: 100, dy: -30), .right)
    XCTAssertEqual(recognizer.classify(dx: 30, dy: -100), .up)
  }

  func testAmbiguousDiagonalDoesNothingRatherThanGuess() {
    XCTAssertEqual(recognizer.classify(dx: 60, dy: 60), .tap)
    XCTAssertEqual(recognizer.classify(dx: -60, dy: 60), .tap)
  }

  func testMovementExactlyAtThresholdCounts() {
    XCTAssertEqual(recognizer.classify(dx: 22, dy: 0), .right)
  }

  func testThresholdIsConfigurable() {
    let twitchy = GestureRecognizer(threshold: 5)
    XCTAssertEqual(twitchy.classify(dx: 6, dy: 0), .right)
    let sluggish = GestureRecognizer(threshold: 200)
    XCTAssertEqual(sluggish.classify(dx: 100, dy: 0), .tap)
  }
}

final class SeparateScrollingTests: XCTestCase {
  func testDiscreteMouseWheelIsReversedWhenEnabled() {
    XCTAssertTrue(
      GestureEngine.shouldReverseScroll(
        isContinuous: false, separateMouseScrolling: true))
  }

  func testContinuousTrackpadGestureIsNeverReversed() {
    XCTAssertFalse(
      GestureEngine.shouldReverseScroll(
        isContinuous: true, separateMouseScrolling: true))
  }

  func testSystemDirectionPassesEverythingThrough() {
    XCTAssertFalse(
      GestureEngine.shouldReverseScroll(
        isContinuous: false, separateMouseScrolling: false))
    XCTAssertFalse(
      GestureEngine.shouldReverseScroll(
        isContinuous: true, separateMouseScrolling: false))
  }
}

final class MacActionTests: XCTestCase {

  func testMissionControlUsesTheSystemHotkey() {
    let stroke = MacAction.missionControl.keystroke
    XCTAssertEqual(stroke?.key, 0x7E, "Mission Control is Control + Up Arrow")
    XCTAssertEqual(stroke?.flags, .maskControl)
  }

  func testSpaceSwitchingUsesLeftAndRightArrows() {
    XCTAssertEqual(MacAction.spaceLeft.keystroke?.key, 0x7B)
    XCTAssertEqual(MacAction.spaceRight.keystroke?.key, 0x7C)
    XCTAssertEqual(MacAction.spaceLeft.keystroke?.flags, .maskControl)
  }

  func testEveryActionExceptNoneCanActuallyBePerformed() {
    for action in MacAction.allCases where action != .none {
      XCTAssertTrue(
        action.isDispatchable,
        "\(action.displayName) has no way to be dispatched")
    }
  }

  func testNoneIsDeliberatelyNotDispatchable() {
    XCTAssertFalse(MacAction.none.isDispatchable)
  }

  func testMediaKeysAreDistinctFromKeystrokes() {
    XCTAssertNil(MacAction.volumeUp.keystroke)
    XCTAssertNotNil(MacAction.volumeUp.mediaKey)
    XCTAssertNil(MacAction.missionControl.mediaKey)
  }

  func testEveryActionHasAName() {
    for action in MacAction.allCases {
      XCTAssertFalse(action.displayName.isEmpty)
    }
  }
}

final class GestureBindingTests: XCTestCase {

  func testDefaultBindingCoversEveryDirection() {
    let binding = GestureBinding.defaultBinding(for: .back)
    for direction in GestureDirection.allCases {
      XCTAssertNotEqual(
        binding.action(for: direction), MacAction.none,
        "\(direction) has no default action")
    }
  }

  func testDefaultTapPreservesTheButtonsOrdinaryBehaviour() {
    XCTAssertEqual(GestureBinding.defaultBinding(for: .back).action(for: .tap), .backClick)
    XCTAssertEqual(GestureBinding.defaultBinding(for: .forward).action(for: .tap), .forwardClick)
    XCTAssertEqual(GestureBinding.defaultBinding(for: .middle).action(for: .tap), .middleClick)
  }

  func testEveryGestureCapableButtonHasAPassthroughTap() {
    for button in [PhysicalButton.back, .forward, .middle] {
      let tap = GestureBinding.defaultBinding(for: button).action(for: .tap)
      XCTAssertEqual(
        tap.mouseButton != nil, true,
        "\(button.displayName) tap must re-emit a real mouse button")
    }
  }

  func testGesturesAreOffUntilDeliberatelyEnabled() {
    XCTAssertFalse(GestureBinding.defaultBinding(for: .back).enabled)
  }

  func testUnmappedDirectionIsNone() {
    let binding = GestureBinding(button: .back, enabled: true, actions: [.up: .launchpad])
    XCTAssertEqual(binding.action(for: .up), .launchpad)
    XCTAssertEqual(binding.action(for: .down), .none)
  }

  func testBindingSurvivesEncoding() throws {
    let binding = GestureBinding.defaultBinding(for: .forward)
    let data = try JSONEncoder().encode(binding)
    XCTAssertEqual(try JSONDecoder().decode(GestureBinding.self, from: data), binding)
  }
}

final class ActionRingTests: XCTestCase {

  func testMiddleRingIsReadyByDefault() {
    let ring = ActionRingConfiguration.defaultConfiguration(for: .middle)
    XCTAssertTrue(ring.enabled)
    XCTAssertEqual(ring.items.count, 8)
    XCTAssertTrue(ring.items.allSatisfy { $0.action.isConfigured })
  }

  func testSideRingsAreAvailableButOptIn() {
    XCTAssertFalse(ActionRingConfiguration.defaultConfiguration(for: .back).enabled)
    XCTAssertFalse(ActionRingConfiguration.defaultConfiguration(for: .forward).enabled)
  }

  func testRingSelectionStartsAtTopAndRunsClockwise() {
    XCTAssertEqual(ActionRingSelection.index(dx: 0, dy: -100, itemCount: 4), 0)
    XCTAssertEqual(ActionRingSelection.index(dx: 100, dy: 0, itemCount: 4), 1)
    XCTAssertEqual(ActionRingSelection.index(dx: 0, dy: 100, itemCount: 4), 2)
    XCTAssertEqual(ActionRingSelection.index(dx: -100, dy: 0, itemCount: 4), 3)
  }

  func testRingCentreCancelsSelection() {
    XCTAssertNil(ActionRingSelection.index(dx: 4, dy: -8, itemCount: 6))
  }

  func testCustomRingActionsSurviveEncoding() throws {
    let ring = ActionRingConfiguration(
      button: .middle, enabled: true,
      items: [
        ActionRingItem(title: "Browser", action: .open(path: "/Applications/Safari.app")),
        ActionRingItem(title: "Morning", action: .runShortcut(name: "Morning routine")),
        ActionRingItem(title: "Site", action: .openURL("https://openai.com")),
      ])
    let data = try JSONEncoder().encode(ring)
    XCTAssertEqual(try JSONDecoder().decode(ActionRingConfiguration.self, from: data), ring)
  }
}

final class ActionReliabilityTests: XCTestCase {

  func testMissionControlDoesNotDependOnAKeyboardShortcut() {
    XCTAssertEqual(
      MacAction.missionControl.launchesApplication,
      "/System/Applications/Mission Control.app")
    XCTAssertFalse(MacAction.missionControl.requiresSystemShortcut)
  }

  func testDockActionsDoNotDependOnUserShortcuts() {
    let actions: [MacAction] = [
      .missionControl, .applicationWindows, .showDesktop, .launchpad,
    ]
    XCTAssertTrue(actions.allSatisfy { $0.dockNotification != nil })
    XCTAssertTrue(actions.allSatisfy { !$0.requiresSystemShortcut })
  }

  func testSpotlightAndScreenshotHaveDirectLaunchPaths() {
    XCTAssertEqual(
      MacAction.spotlight.launchesApplication,
      "/System/Library/CoreServices/Spotlight.app")
    XCTAssertEqual(
      MacAction.screenshotRegion.executableAction?.path,
      "/usr/sbin/screencapture")
    XCTAssertFalse(MacAction.spotlight.requiresSystemShortcut)
    XCTAssertFalse(MacAction.screenshotRegion.requiresSystemShortcut)
  }

  func testShortcutDependentActionsAreIdentified() {
    XCTAssertTrue(MacAction.spaceLeft.requiresSystemShortcut)
    XCTAssertTrue(MacAction.spaceRight.requiresSystemShortcut)
    XCTAssertFalse(MacAction.applicationWindows.requiresSystemShortcut)
  }

  func testActionsThatNeedNoShortcutAreNotFlagged() {
    XCTAssertFalse(MacAction.volumeUp.requiresSystemShortcut)
    XCTAssertFalse(MacAction.backClick.requiresSystemShortcut)
    XCTAssertFalse(MacAction.none.requiresSystemShortcut)
  }

  func testShortcutDependentActionsExposeTheirHotkeyID() {
    for action in MacAction.allCases where action.requiresSystemShortcut {
      XCTAssertNotNil(
        action.symbolicHotkeyID,
        "\(action.displayName) needs an id to be checkable")
    }
  }

  func testEveryActionIsStillDispatchable() {
    for action in MacAction.allCases where action != .none {
      XCTAssertTrue(action.isDispatchable)
    }
  }
}
