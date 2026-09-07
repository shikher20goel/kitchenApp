import XCTest

/// Building a list from the plan and ticking one item off is the Shop tab's whole job.
final class ShopUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testBuildTheListAndCheckAnItem() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-uiTestingDemoHousehold", "-uiTestingTab", "shop"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 20))

        tabBar.buttons["Plan"].tap()
        let generate = app.buttons["plan.generate"]
        XCTAssertTrue(generate.waitForExistence(timeout: 25))
        generate.tap()

        tabBar.buttons["Shop"].tap()
        let build = app.buttons["shop.build"]
        XCTAssertTrue(build.waitForExistence(timeout: 25))
        build.tap()

        let check = app.buttons.matching(identifier: "shop.check").firstMatch
        XCTAssertTrue(check.waitForExistence(timeout: 25), "The list fills from the plan.")
        let label = check.label
        check.tap()

        XCTAssertTrue(label.hasPrefix("Check"), "An unchecked item offers to be checked.")
    }
}
