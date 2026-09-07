import XCTest

/// Adds something to the pantry the way a household would, and checks it lands in the list.
final class PantryUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testAddingAnIngredientShowsItInTheList() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-uiTestingDemoHousehold", "-uiTestingTab", "pantry"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 20))
        tabBar.buttons["Pantry"].tap()

        app.buttons["pantry.add"].tap()

        let search = app.textFields["pantry.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 25))
        search.tap()
        search.typeText("palak")

        let result = app.buttons["pantry.result.Spinach"]
        XCTAssertTrue(result.waitForExistence(timeout: 25), "An alias search finds the catalog name.")
        result.tap()

        app.buttons["pantry.confirmAdd"].tap()

        XCTAssertTrue(app.staticTexts["Spinach"].waitForExistence(timeout: 25),
                      "The new item appears in the pantry list.")
    }
}
