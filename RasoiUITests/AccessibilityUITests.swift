import XCTest

/// Rasoi is used one-handed in a kitchen, often at a large text size. Every tab has to stay
/// usable at the accessibility sizes, and icon-only controls have to say what they are.
final class AccessibilityUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Launches straight onto one tab at an accessibility text size.
    private func launch(tab: String, size: String = "UICTContentSizeCategoryAccessibilityXL") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-uiTesting", "-uiTestingDemoHousehold", "-uiTestingTab", tab,
            "-UIPreferredContentSizeCategoryName", size,
        ]
        app.launch()
        return app
    }

    func testEveryTabRendersAtAccessibilityExtraLarge() {
        for tab in ["today", "plan", "pantry", "shop", "more"] {
            let app = launch(tab: tab)
            let navigationBar = app.navigationBars.firstMatch
            XCTAssertTrue(navigationBar.waitForExistence(timeout: 25),
                          "The \(tab) tab should render at accessibility XL")
            XCTAssertGreaterThan(app.staticTexts.count, 0, "The \(tab) tab shows text")
            XCTAssertTrue(app.tabBars.firstMatch.exists, "The tab bar survives large text")
            app.terminate()
        }
    }

    func testPrimaryActionsAreReachableAtLargeText() {
        let plan = launch(tab: "plan")
        XCTAssertTrue(plan.buttons["plan.generate"].waitUntilHittable(),
                      "Generate week stays reachable at accessibility XL")
        plan.terminate()

        let shop = launch(tab: "shop")
        XCTAssertTrue(shop.buttons["shop.build"].waitUntilHittable(),
                      "Build list stays reachable at accessibility XL")
        shop.terminate()
    }

    func testIconOnlyControlsAreLabelled() {
        let pantry = launch(tab: "pantry", size: "UICTContentSizeCategoryL")
        XCTAssertTrue(pantry.buttons["pantry.add"].waitForExistence(timeout: 25))
        XCTAssertEqual(pantry.buttons["pantry.add"].label, "Add to pantry",
                       "An icon-only button must say what it does")

        let sortButton = pantry.buttons["Sort and more"]
        XCTAssertTrue(sortButton.exists, "The sort menu is labelled for VoiceOver")
        pantry.terminate()

        let plan = launch(tab: "plan", size: "UICTContentSizeCategoryL")
        XCTAssertTrue(plan.buttons["Previous week"].waitForExistence(timeout: 25))
        XCTAssertTrue(plan.buttons["Next week"].exists)
        plan.terminate()
    }

    func testCoverageDotsAreDescribedInWords() {
        let today = launch(tab: "today", size: "UICTContentSizeCategoryL")
        XCTAssertTrue(today.navigationBars.firstMatch.waitForExistence(timeout: 25))

        // The dots are decorative shapes; VoiceOver has to hear the group and whether it is covered.
        let described = today.otherElements.allElementsBoundByIndex
            .contains { $0.label.contains("Fruit:") || $0.label.contains("Vegetables:") }
        XCTAssertTrue(described, "Each coverage dot reads as '<group>: covered / not yet'")
        today.terminate()
    }
}
