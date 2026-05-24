import AppKit
import XCTest
@testable import MacWhisper

final class AppActivationPolicyTests: XCTestCase {
    func testShowInDockUsesRegularActivationPolicy() {
        XCTAssertEqual(
            AppPresentation.desiredActivationPolicy(showInDock: true),
            .regular
        )
    }

    func testMenuBarOnlyUsesAccessoryActivationPolicy() {
        XCTAssertEqual(
            AppPresentation.desiredActivationPolicy(showInDock: false),
            .accessory
        )
    }
}
