import SwiftData
import XCTest
@testable import Rasoi

final class DietSettingsViewModelTests: XCTestCase {
    /// Keeps the container alive alongside the view model: a model object whose container has
    /// deallocated traps the moment it is touched.
    private struct Harness {
        let stack: TestStack
        let model: DietSettingsViewModel
    }

    @MainActor
    private func makeHarness() throws -> Harness {
        let stack = try TestContainer.makeStack()
        try SeedImporter.reimport(in: stack.context)
        return Harness(stack: stack, model: DietSettingsViewModel(context: stack.context))
    }

    // MARK: - Zip

    @MainActor
    func testZipCodeAcceptsFiveDigits() throws {
        let harness = try makeHarness()
        let model = harness.model
        XCTAssertTrue(model.setZipCode("07030"))
        XCTAssertEqual(model.profile.zipCode, "07030")
        XCTAssertNil(model.zipCodeError)
    }

    @MainActor
    func testZipCodeRejectsAnythingElse() throws {
        let harness = try makeHarness()
        let model = harness.model
        for bad in ["7030", "070300", "0703a", "", "abcde"] {
            XCTAssertFalse(model.setZipCode(bad), "\(bad) should be rejected")
        }
        XCTAssertEqual(model.profile.zipCode, "07302", "The old zip stays until a valid one arrives.")
        XCTAssertNotNil(model.zipCodeError)

        XCTAssertTrue(model.setZipCode(" 07030 "), "Surrounding spaces are trimmed.")
        XCTAssertNil(model.zipCodeError)
    }

    // MARK: - Exclusions

    @MainActor
    func testAddingAnExclusionStoresTheCatalogName() throws {
        let harness = try makeHarness()
        let model = harness.model
        model.addExclusion("palak")
        XCTAssertEqual(model.profile.excludedIngredients, ["Spinach"],
                       "An alias is stored as the catalog name so every screen agrees.")
        XCTAssertTrue(model.profile.excludes(ingredientNamed: "spinach"))
    }

    @MainActor
    func testAddingTheSameExclusionTwiceDoesNothing() throws {
        let harness = try makeHarness()
        let model = harness.model
        model.addExclusion("Spinach")
        model.addExclusion("palak")
        model.addExclusion("spinach")
        XCTAssertEqual(model.profile.excludedIngredients, ["Spinach"])
    }

    @MainActor
    func testUnknownExclusionsAreKeptAsTyped() throws {
        let harness = try makeHarness()
        let model = harness.model
        model.addExclusion("Grandma's masala")
        XCTAssertEqual(model.profile.excludedIngredients, ["Grandma's masala"])
    }

    @MainActor
    func testRemovingAnExclusionIgnoresCase() throws {
        let harness = try makeHarness()
        let model = harness.model
        model.addExclusion("Spinach")
        model.removeExclusion("spinach")
        XCTAssertTrue(model.profile.excludedIngredients.isEmpty)
    }

    @MainActor
    func testExclusionSuggestionsComeFromTheCatalogAndSkipWhatIsAlreadyExcluded() throws {
        let harness = try makeHarness()
        let model = harness.model
        XCTAssertTrue(model.exclusionSuggestions(for: "p").isEmpty, "One letter is not enough to search.")
        XCTAssertTrue(model.exclusionSuggestions(for: "pane").contains("Paneer"))

        model.addExclusion("Paneer")
        XCTAssertFalse(model.exclusionSuggestions(for: "pane").contains("Paneer"))
    }

    // MARK: - Kitchen

    @MainActor
    func testTogglingAnAppliance() throws {
        let harness = try makeHarness()
        let model = harness.model
        XCTAssertTrue(model.has(.instantPot))
        model.toggleAppliance(.instantPot)
        XCTAssertFalse(model.has(.instantPot))
        model.toggleAppliance(.airFryer)
        XCTAssertTrue(model.has(.airFryer))
        XCTAssertEqual(model.profile.appliances, ["vitamix", "stovetop", "oven", "airFryer"])
    }

    @MainActor
    func testCuisinesComeFromTheCatalog() throws {
        let harness = try makeHarness()
        let model = harness.model
        XCTAssertTrue(model.availableCuisines.contains("Mediterranean"),
                      "A cuisine that only exists in the catalog is still offered.")
        XCTAssertTrue(model.prefers("Indian"))
        model.toggleCuisine("Indian")
        XCTAssertFalse(model.prefers("Indian"))
        model.toggleCuisine("Indian")
        XCTAssertTrue(model.prefers("Indian"))
    }

    @MainActor
    func testWeekdayCookMinutesAreClamped() throws {
        let harness = try makeHarness()
        let model = harness.model
        model.setWeekdayMaxCookMinutes(5)
        XCTAssertEqual(model.profile.weekdayMaxCookMinutes, 15)
        model.setWeekdayMaxCookMinutes(240)
        XCTAssertEqual(model.profile.weekdayMaxCookMinutes, 90)
        model.setWeekdayMaxCookMinutes(45)
        XCTAssertEqual(model.profile.weekdayMaxCookMinutes, 45)
    }

    @MainActor
    func testShoppingWeekdayStaysInRange() throws {
        let harness = try makeHarness()
        let model = harness.model
        model.setShoppingWeekday(7)
        XCTAssertEqual(model.profile.shoppingWeekday, 7)
        model.setShoppingWeekday(9)
        XCTAssertEqual(model.profile.shoppingWeekday, 7, "An out-of-range weekday is ignored.")
        XCTAssertEqual(1.weekdayName, "Sunday")
        XCTAssertEqual(7.weekdayName, "Saturday")
    }

    @MainActor
    func testDietTogglesPersist() throws {
        let harness = try makeHarness()
        let model = harness.model
        let stack = harness.stack
        model.setEggsOK(false)
        model.setNutFree(true)

        let reloaded = DietProfile.current(in: stack.context)
        XCTAssertFalse(reloaded.eggsOK)
        XCTAssertTrue(reloaded.nutFree)
        XCTAssertTrue(reloaded.isVegetarian, "Vegetarian stays on in v1 (R4).")
    }
}
