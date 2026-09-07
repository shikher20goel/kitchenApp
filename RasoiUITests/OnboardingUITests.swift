import XCTest

/// Walks the first-launch flow the way a household would (SPEC §4.6).
final class OnboardingUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchFresh() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting"]
        app.launch()
        return app
    }

    func testCompletingOnboardingLandsOnTheTabBar() {
        let app = launchFresh()

        let name = app.textFields["onboarding.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 20), "Onboarding should be the first thing shown.")

        // One adult…
        name.tap()
        name.typeText("Shikher")
        app.buttons["onboarding.addMember"].tap()

        // …and one child.
        app.buttons["Child"].tap()
        name.tap()
        name.typeText("Ira")
        app.buttons["onboarding.addMember"].tap()

        let next = app.buttons["onboarding.next"]
        XCTAssertTrue(next.isEnabled, "With a family added, the flow can move on.")
        next.tap()
        app.buttons["onboarding.next"].tap()
        app.buttons["onboarding.next"].tap()

        let finish = app.buttons["onboarding.finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        finish.tap()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "Finishing onboarding opens the app.")
    }

    func testTheFlowCannotBeSkippedWithoutAFamily() {
        let app = launchFresh()
        XCTAssertTrue(app.textFields["onboarding.name"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.buttons["onboarding.next"].isEnabled,
                       "Rasoi needs at least one person before it can plan anything.")
    }
}
