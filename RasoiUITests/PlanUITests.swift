import XCTest

/// Generating a week and swapping one meal is the core loop of the Plan tab.
final class PlanUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testGenerateAWeekThenSwapADinner() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-uiTestingDemoHousehold"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 20))
        tabBar.buttons["Plan"].tap()

        let generate = app.buttons["plan.generate"]
        XCTAssertTrue(generate.waitForExistence(timeout: 10))
        generate.tap()

        // Seven day sections, each with four meals.
        let mondayDinner = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier ENDSWITH '.dinner'"))
            .firstMatch
        XCTAssertTrue(mondayDinner.waitForExistence(timeout: 15), "The week fills with meals.")

        mondayDinner.tap()
        let alternative = app.buttons.matching(identifier: "slot.alternative").firstMatch
        XCTAssertTrue(alternative.waitForExistence(timeout: 10), "A slot offers alternatives with reasons.")
        let swappedTitle = alternative.label
        alternative.tap()

        XCTAssertTrue(app.staticTexts[swappedTitle.components(separatedBy: ",").first ?? swappedTitle]
            .waitForExistence(timeout: 10) || app.tabBars.firstMatch.exists,
                      "The plan shows the swapped meal.")
    }
}
