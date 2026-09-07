import XCTest

/// Drives the app the way a household would and saves a PNG of every screen.
///
/// Green tests are not the same as a working app: these screenshots are looked at by a person
/// (task 065, `docs/REVIEW.md`). Images are written into the runner's Documents directory;
/// `scripts/screenshots.sh` copies them out of the simulator into `docs/screenshots/`.
final class ScreenshotUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private var outputDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func launch(tab: String? = nil, onboarding: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting"]
        if !onboarding { app.launchArguments += ["-uiTestingDemoHousehold"] }
        if let tab { app.launchArguments += ["-uiTestingTab", tab] }
        app.launch()
        return app
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        // Let the screen settle: a shot taken mid-transition shows two labels on top of each other
        // and is useless for spotting real layout bugs.
        Thread.sleep(forTimeInterval: 0.8)
        let screenshot = app.screenshot()
        let url = outputDirectory.appendingPathComponent("\(name).png")
        do {
            try screenshot.pngRepresentation.write(to: url, options: .atomic)
        } catch {
            XCTFail("Could not write \(name).png: \(error)")
        }
        // Also attach, so the images are in the test report even without the script.
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func test01Onboarding() {
        let app = launch(onboarding: true)
        XCTAssertTrue(app.textFields["onboarding.name"].waitForExistence(timeout: 25))
        capture(app, "01-onboarding")

        app.textFields["onboarding.name"].tap()
        app.textFields["onboarding.name"].typeText("Shikher")
        app.buttons["onboarding.addMember"].tap()
        capture(app, "02-onboarding-family")
    }

    func test03PlanAndSlot() {
        let app = launch(tab: "plan")
        app.buttons["plan.generate"].waitAndTap("Generate week")

        let dinner = app.buttons["plan.slot.0.dinner"]
        XCTAssertTrue(dinner.waitUntilHittable())
        capture(app, "03-plan")

        dinner.tap()
        XCTAssertTrue(app.buttons.matching(identifier: "slot.alternative").firstMatch.waitUntilHittable())
        capture(app, "04-plan-slot")
        app.buttons["Done"].firstMatch.tap()
    }

    func test05TodayCookAndFeedback() {
        // One launch: `-uiTesting` uses an in-memory store, so a plan made in a previous launch
        // would not be there.
        let app = launch(tab: "plan")
        app.buttons["plan.generate"].waitAndTap("Generate week")
        app.tabBars.firstMatch.buttons["Today"].waitAndTap("The Today tab")
        XCTAssertTrue(app.buttons["today.cook"].waitUntilHittable())
        capture(app, "05-today")

        app.buttons["today.cook"].tap()
        XCTAssertTrue(app.buttons["cook.next"].waitUntilHittable())
        capture(app, "06-cook-ingredients")
        app.buttons["cook.next"].tap()
        capture(app, "07-cook-step")
        app.buttons["cook.done"].waitAndTap("Done in cook mode")

        app.buttons["today.feedback"].waitAndTap("How did it go?")
        XCTAssertTrue(app.buttons["feedback.Shikher.ateAll"].waitUntilHittable())
        capture(app, "08-feedback")
    }

    func test09Pantry() {
        let app = launch(tab: "pantry")
        XCTAssertTrue(app.buttons["pantry.add"].waitUntilHittable())
        capture(app, "09-pantry-empty")

        app.buttons["pantry.add"].tap()
        let search = app.textFields["pantry.search"]
        XCTAssertTrue(search.waitUntilHittable())
        search.tap()
        search.typeText("spin")
        XCTAssertTrue(app.buttons["pantry.result.Spinach"].waitUntilHittable())
        app.buttons["pantry.result.Spinach"].tap()
        capture(app, "10-pantry-add")
        app.buttons["pantry.confirmAdd"].tap()
        XCTAssertTrue(app.staticTexts["Spinach"].waitForExistence(timeout: 25))
        capture(app, "11-pantry")
    }

    func test12Shop() {
        let app = launch(tab: "plan")
        app.buttons["plan.generate"].waitAndTap("Generate week")
        app.tabBars.firstMatch.buttons["Shop"].waitAndTap("The Shop tab")
        app.buttons["shop.build"].waitAndTap("Build list")
        let check = app.buttons.matching(identifier: "shop.check").firstMatch
        XCTAssertTrue(check.waitUntilHittable())
        capture(app, "12-shop")

        check.tap()
        app.buttons.matching(identifier: "shop.check").element(boundBy: 1).tap()
        capture(app, "13-shop-checked")
    }

    func test14MoreScreens() {
        let app = launch(tab: "more")
        XCTAssertTrue(app.staticTexts["Family"].waitUntilHittable())
        capture(app, "14-more")

        let list = app.collectionViews.firstMatch

        app.staticTexts["Family"].tap()
        XCTAssertTrue(app.navigationBars["Family"].waitForExistence(timeout: 25))
        capture(app, "15-family")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.staticTexts["Diet & Kitchen"].waitAndTap("Diet & Kitchen")
        XCTAssertTrue(app.navigationBars["Diet & Kitchen"].waitForExistence(timeout: 25))
        capture(app, "16-diet")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.staticTexts["Stores"].waitAndTap("Stores")
        XCTAssertTrue(app.navigationBars["Stores"].waitForExistence(timeout: 25))
        capture(app, "17-stores")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.staticTexts["Recipes"].waitAndTap("Recipes")
        XCTAssertTrue(app.navigationBars["Recipes"].waitForExistence(timeout: 25))
        capture(app, "18-recipes")
        app.cells.element(boundBy: 1).tap()
        XCTAssertTrue(app.buttons["recipe.cook"].waitUntilHittable())
        capture(app, "19-recipe-detail")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let insights = app.staticTexts["Insights"]
        XCTAssertTrue(insights.scrollUntilHittable(in: list))
        insights.tap()
        XCTAssertTrue(app.navigationBars["Insights"].waitForExistence(timeout: 25))
        capture(app, "20-insights")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let notifications = app.staticTexts["Notifications"]
        XCTAssertTrue(notifications.scrollUntilHittable(in: list))
        notifications.tap()
        XCTAssertTrue(app.navigationBars["Notifications"].waitForExistence(timeout: 25))
        capture(app, "21-notifications")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let about = app.staticTexts["About"]
        XCTAssertTrue(about.scrollUntilHittable(in: list))
        about.tap()
        XCTAssertTrue(app.navigationBars["About"].waitForExistence(timeout: 25))
        capture(app, "22-about")
    }
}
