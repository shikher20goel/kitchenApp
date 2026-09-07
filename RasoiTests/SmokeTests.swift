import XCTest
@testable import Rasoi

/// Proves the test harness itself works: the bundle loads, the app module is importable,
/// and design tokens are reachable from tests.
final class SmokeTests: XCTestCase {
    func testHarnessIsAlive() {
        XCTAssertTrue(true, "The XCTest harness runs.")
    }

    func testThemeAppName() {
        XCTAssertEqual(Theme.appName, "Rasoi")
    }
}
