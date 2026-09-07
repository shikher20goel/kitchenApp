import SwiftData
import XCTest
@testable import Rasoi

final class RecipesViewModelTests: XCTestCase {
    private struct Harness {
        let stack: TestStack
        let model: RecipesViewModel
    }

    @MainActor
    private func makeHarness(youngest: Date = D.youngChildDOB) throws -> Harness {
        let stack = try TestContainer.makeStack()
        try SeedImporter.reimport(in: stack.context)
        stack.context.insert(HouseholdMember(name: "Shikher", dateOfBirth: D.adultDOB, role: .adult))
        stack.context.insert(HouseholdMember(name: "Ira", dateOfBirth: youngest, role: .child))
        try stack.context.save()
        return Harness(stack: stack, model: RecipesViewModel(context: stack.context, now: { D.date(2026, 9, 6) }))
    }

    @MainActor
    func testDefaultListIsTheWholeEligibleCatalogInTitleOrder() throws {
        let harness = try makeHarness()
        let titles = harness.model.results.map(\.title)
        XCTAssertGreaterThan(titles.count, 30)
        XCTAssertEqual(titles, titles.sorted(), "Deterministic order — the list never shuffles.")
    }

    @MainActor
    func testMealTypeAndQuickFiltersCombine() throws {
        let harness = try makeHarness()
        harness.model.mealType = .breakfast
        let breakfasts = harness.model.results
        XCTAssertFalse(breakfasts.isEmpty)
        XCTAssertTrue(breakfasts.allSatisfy { $0.serves(.breakfast) })

        harness.model.quickOnly = true
        let quickBreakfasts = harness.model.results
        XCTAssertTrue(quickBreakfasts.allSatisfy { $0.serves(.breakfast) && $0.isQuick })
        XCTAssertLessThanOrEqual(quickBreakfasts.count, breakfasts.count)
    }

    @MainActor
    func testCuisineAndApplianceFiltersCombine() throws {
        let harness = try makeHarness()
        harness.model.cuisine = "Indian"
        harness.model.appliance = .instantPot
        let results = harness.model.results
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.allSatisfy { $0.cuisine == "Indian" && $0.applianceSet.contains(.instantPot) })
    }

    @MainActor
    func testSearchMatchesTitleAndIngredientAndAlias() throws {
        let harness = try makeHarness()
        harness.model.searchText = "khichdi"
        XCTAssertTrue(harness.model.results.contains { $0.title.localizedCaseInsensitiveContains("khichdi") })

        harness.model.searchText = "paneer"
        XCTAssertTrue(harness.model.results.allSatisfy { recipe in
            recipe.title.localizedCaseInsensitiveContains("paneer")
                || recipe.uses(ingredientNamed: "Paneer")
        })

        harness.model.searchText = "palak"
        let names = harness.model.results.map(\.title)
        XCTAssertTrue(names.contains { $0.localizedCaseInsensitiveContains("Palak") },
                      "An alias search finds the spinach dishes.")
    }

    @MainActor
    func testIneligibleRecipesAreHiddenUntilShowEverything() throws {
        let harness = try makeHarness()
        let profile = DietProfile.current(in: harness.stack.context)
        profile.eggsOK = false
        try harness.stack.context.save()
        harness.model.load()

        XCTAssertFalse(harness.model.results.contains { $0.containsEgg })

        harness.model.showsEverything = true
        let egg = try XCTUnwrap(harness.model.results.first { $0.containsEgg })
        XCTAssertEqual(harness.model.unavailableReason(for: egg), "Has egg")
    }

    @MainActor
    func testHiddenRecipesAreOutOfTheDefaultListWithTheirOwnReason() throws {
        let harness = try makeHarness()
        let recipe = try XCTUnwrap(harness.model.results.first)
        harness.model.toggleHidden(recipe)

        XCTAssertFalse(harness.model.results.contains { $0.persistentModelID == recipe.persistentModelID })
        harness.model.showsEverything = true
        XCTAssertEqual(harness.model.unavailableReason(for: recipe), "Hidden by you")
    }

    @MainActor
    func testMinimumAgeUsesTheYoungestChild() throws {
        let harness = try makeHarness(youngest: D.date(2024, 1, 1)) // two years old on the test date
        harness.model.showsEverything = true
        let gated = harness.model.allRecipes.filter { $0.minAgeYears > 2 }
        XCTAssertFalse(gated.isEmpty, "The catalog has age-gated recipes to test with.")
        for recipe in gated {
            XCTAssertEqual(harness.model.unavailableReason(for: recipe), "Better from age \(recipe.minAgeYears)")
        }
    }

    @MainActor
    func testFavouriteTogglesAndPersists() throws {
        let harness = try makeHarness()
        let recipe = try XCTUnwrap(harness.model.results.first)
        harness.model.toggleFavorite(recipe)
        XCTAssertTrue(recipe.isFavorite)

        harness.model.favouritesOnly = true
        XCTAssertEqual(harness.model.results.map(\.title), [recipe.title])

        let reloaded = RecipesViewModel(context: harness.stack.context, now: { D.date(2026, 9, 6) })
        reloaded.favouritesOnly = true
        XCTAssertEqual(reloaded.results.map(\.title), [recipe.title], "A favourite survives a reload.")
    }

    @MainActor
    func testClearFiltersResetsEverything() throws {
        let harness = try makeHarness()
        harness.model.mealType = .dinner
        harness.model.quickOnly = true
        harness.model.searchText = "dal"
        XCTAssertTrue(harness.model.hasActiveFilters)

        harness.model.clearFilters()
        XCTAssertFalse(harness.model.hasActiveFilters)
        XCTAssertEqual(harness.model.results.count, harness.model.allRecipes.filter { harness.model.isAvailable($0) }.count)
    }

    @MainActor
    func testPantryCoverageMarksWhatIsAlreadyIn() throws {
        let harness = try makeHarness()
        let spinach = try XCTUnwrap(Ingredient.named("Spinach", in: harness.stack.context))
        PantryItem.add(spinach, quantity: 200, unit: .gram, location: .fridge,
                       on: D.date(2026, 9, 6), in: harness.stack.context)
        try harness.stack.context.save()

        let recipe = try XCTUnwrap(harness.model.allRecipes.first { $0.uses(ingredientNamed: "Spinach") })
        XCTAssertTrue(harness.model.pantryCoverage(for: recipe).contains(Ingredient.fold("Spinach")))
        XCTAssertFalse(harness.model.pantryCoverage(for: recipe).contains(Ingredient.fold("Paneer")))
    }
}
