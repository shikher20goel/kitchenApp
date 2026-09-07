import XCTest

/// The evening loop: cook tonight's dinner, then say how it went for each child.
final class TodayUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testCookTonightsDinnerAndRecordFeedback() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-uiTestingDemoHousehold", "-uiTestingTab", "today"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 25))

        // Plan the week first — Today shows what the plan says.
        tabBar.buttons["Plan"].waitAndTap("The Plan tab")
        app.buttons["plan.generate"].waitAndTap("Generate week")
        tabBar.buttons["Today"].waitAndTap("The Today tab")
        app.buttons["today.cook"].waitAndTap("Cook")
        app.buttons["cook.done"].waitAndTap("Done in cook mode")

        // The card now offers feedback for the meal that was just cooked. Give cook mode a
        // moment to finish sliding away: a presentation requested during another one's dismissal
        // is dropped by SwiftUI.
        app.buttons["today.feedback"].waitAndTap("How did it go?")

        let list = app.collectionViews.firstMatch
        let aaravAteSome = app.buttons["feedback.Aarav.ateSome"]
        XCTAssertTrue(aaravAteSome.scrollUntilHittable(in: list), "Feedback asks about each person.")
        aaravAteSome.tap()

        let iraAteAll = app.buttons["feedback.Ira.ateAll"]
        XCTAssertTrue(iraAteAll.scrollUntilHittable(in: list))
        iraAteAll.tap()

        app.buttons["feedback.save"].waitAndTap("Save the feedback")

        XCTAssertTrue(app.buttons["today.feedback"].waitForExistence(timeout: 25),
                      "Back on Today, the meal reads as cooked.")
    }
}
