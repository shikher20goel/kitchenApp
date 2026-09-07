import XCTest

/// Generating a week and swapping one meal is the core loop of the Plan tab.
final class PlanUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testGenerateAWeekThenSwapADinner() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-uiTestingDemoHousehold", "-uiTestingTab", "plan"]
        app.launch()

        app.buttons["plan.generate"].waitAndTap("Generate week")

        // Seven day sections, each with four meals.
        let mondayDinner = app.buttons["plan.slot.0.dinner"]
        XCTAssertTrue(mondayDinner.waitUntilHittable(), "The week fills with meals.")
        let plannedTitle = mondayDinner.label
        mondayDinner.tap()

        let alternative = app.buttons.matching(identifier: "slot.alternative").firstMatch
        XCTAssertTrue(alternative.waitUntilHittable(), "A slot offers alternatives with reasons.")
        alternative.tap()

        // Back on the plan, the slot shows something else.
        XCTAssertTrue(mondayDinner.waitUntilHittable())
        XCTAssertNotEqual(mondayDinner.label, plannedTitle, "The swapped meal replaces the old one.")
    }
}
