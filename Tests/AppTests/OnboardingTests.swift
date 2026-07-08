import XCTest
@testable import dkey

final class OnboardingTests: XCTestCase {
    func testAutoOpenWhenNotCompleted() {
        XCTAssertTrue(Onboarding.shouldAutoOpen(completed: false))
        XCTAssertFalse(Onboarding.shouldAutoOpen(completed: true))
    }

    func testDeepLinkURL() {
        XCTAssertEqual(Onboarding.accessibilitySettingsURL.scheme, "x-apple.systempreferences")
        XCTAssertTrue(Onboarding.accessibilitySettingsURL.absoluteString.contains("Privacy_Accessibility"))
    }
}
