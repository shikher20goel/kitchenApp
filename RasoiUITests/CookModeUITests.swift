import XCTest

/// Cook mode has to be reachable in a couple of taps from a recipe, and readable once open.
final class CookModeUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testCookModeOpensFromARecipe() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-uiTestingDemoHousehold"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 20))
        tabBar.buttons["More"].tap()
        app.staticTexts["Recipes"].tap()

        let firstRecipe = app.cells.element(boundBy: 1)
        XCTAssertTrue(firstRecipe.waitForExistence(timeout: 10))
        firstRecipe.tap()

        let cook = app.buttons["recipe.cook"]
        XCTAssertTrue(cook.waitForExistence(timeout: 10))
        cook.tap()

        XCTAssertTrue(app.buttons["cook.next"].waitForExistence(timeout: 10),
                      "Cook mode opens on the ingredients page with a way forward.")
        app.buttons["cook.next"].tap()
        XCTAssertTrue(app.staticTexts["Step 1 of \(app.staticTexts.count)"].exists
                      || app.buttons["cook.done"].exists,
                      "The first step is on screen.")
        app.buttons["cook.done"].tap()
    }
}
