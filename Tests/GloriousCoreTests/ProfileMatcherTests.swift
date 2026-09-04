import XCTest

@testable import GloriousCore

final class ProfileMatcherTests: XCTestCase {

  private let matcher = ProfileMatcher()

  private func profile(_ name: String, _ bundle: String?) -> Profile {
    Profile(name: name, config: Fixtures.config, autoSwitchBundleID: bundle)
  }

  func testExactBundleMatchWins() {
    let profiles = [profile("Default", nil), profile("Gaming", "com.valvesoftware.steam")]
    XCTAssertEqual(matcher.profile(for: "com.valvesoftware.steam", in: profiles)?.name, "Gaming")
  }

  func testUnmatchedAppFallsBackToTheProfileWithoutABundleID() {
    let profiles = [profile("Default", nil), profile("Gaming", "com.valvesoftware.steam")]
    XCTAssertEqual(matcher.profile(for: "com.apple.Safari", in: profiles)?.name, "Default")
  }

  func testMatchingIsCaseInsensitive() {
    let profiles = [profile("Design", "com.figma.Desktop")]
    XCTAssertEqual(matcher.profile(for: "com.figma.desktop", in: profiles)?.name, "Design")
  }

  func testNoFallbackMeansNoSwitch() {
    let profiles = [profile("Gaming", "com.valvesoftware.steam")]
    XCTAssertNil(matcher.profile(for: "com.apple.Safari", in: profiles))
  }

  func testNilBundleIDStillGetsTheFallback() {
    let profiles = [profile("Default", nil)]
    XCTAssertEqual(matcher.profile(for: nil, in: profiles)?.name, "Default")
  }

  func testEmptyProfileListIsHandled() {
    XCTAssertNil(matcher.profile(for: "com.apple.Safari", in: []))
  }

  func testFirstMatchWinsWhenTwoProfilesClaimTheSameApp() {
    let profiles = [profile("A", "com.example.app"), profile("B", "com.example.app")]
    XCTAssertEqual(matcher.profile(for: "com.example.app", in: profiles)?.name, "A")
  }
}

final class GestureButtonMappingTests: XCTestCase {

  func testEventTapButtonNumbersMapToTheRightPhysicalButtons() {
    XCTAssertEqual(GestureEngine.button(forEventNumber: 2), .middle)
    XCTAssertEqual(GestureEngine.button(forEventNumber: 3), .back)
    XCTAssertEqual(GestureEngine.button(forEventNumber: 4), .forward)
  }

  func testLeftAndRightAreNeverClaimedForGestures() {
    XCTAssertNil(GestureEngine.button(forEventNumber: 0))
    XCTAssertNil(GestureEngine.button(forEventNumber: 1))
  }

  func testUnknownButtonNumbersAreIgnored() {
    XCTAssertNil(GestureEngine.button(forEventNumber: 9))
    XCTAssertNil(GestureEngine.button(forEventNumber: -1))
  }
}
