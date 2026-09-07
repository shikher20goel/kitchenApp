import XCTest

/// Launches Rasoi and checks the five-tab shell is on screen (SPEC §4).
final class LaunchUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testAppLaunchesWithTabBar() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-uiTestingDemoHousehold"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 20), "The tab bar should exist after launch.")
        XCTAssertTrue(app.buttons["Today"].firstMatch.exists || tabBar.buttons["Today"].exists,
                      "The Today tab should be present.")
    }
}
