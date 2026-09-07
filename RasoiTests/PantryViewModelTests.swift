import SwiftData
import XCTest
@testable import Rasoi

final class PantryViewModelTests: XCTestCase {
    /// Holds the container alongside the view model — a model whose container has gone traps.
    private struct Harness {
        let stack: TestStack
        let model: PantryViewModel
    }

    @MainActor
    private func makeHarness(today: Date = D.date(2026, 9, 6)) throws -> Harness {
        let stack = try TestContainer.makeStack()
        try SeedImporter.reimport(in: stack.context)
        let model = PantryViewModel(context: stack.context, now: { today })
        return Harness(stack: stack, model: model)
    }

    @MainActor
    private func ingredient(_ name: String, in harness: Harness) throws -> Ingredient {
        try XCTUnwrap(Ingredient.named(name, in: harness.stack.context))
    }

    // MARK: - Search

    @MainActor
    func testSearchFindsAnIngredientByAPartialNameAndByAlias() throws {
        let harness = try makeHarness()
        XCTAssertEqual(harness.model.searchCatalog("toor").first?.name, "Toor dal")
        XCTAssertEqual(harness.model.searchCatalog("arhar").first?.name, "Toor dal")
        XCTAssertEqual(harness.model.searchCatalog("palak").first?.name, "Spinach")
        XCTAssertTrue(harness.model.searchCatalog("").isEmpty)
    }

    @MainActor
    func testSearchSkipsIngredientsTheHouseholdExcluded() throws {
        let harness = try makeHarness()
        let profile = DietProfile.current(in: harness.stack.context)
        profile.excludedIngredients = ["Spinach"]
        try harness.stack.context.save()

        XCTAssertFalse(harness.model.searchCatalog("spin").contains { $0.name == "Spinach" })
    }

    // MARK: - Adding

    @MainActor
    func testAddSetsExpiryFromTheCatalogShelfLife() throws {
        let harness = try makeHarness(today: D.date(2026, 9, 6))
        let spinach = try ingredient("Spinach", in: harness)
        harness.model.add(spinach, quantity: 200, unit: .gram, location: .fridge)

        let item = try XCTUnwrap(harness.model.items.first)
        XCTAssertEqual(item.quantity, 200)
        XCTAssertEqual(
            item.expiresAt,
            ShelfLife.expiry(shelfLifeDays: spinach.typicalShelfLifeDays,
                             addedAt: D.date(2026, 9, 6), location: .fridge)
        )
    }

    @MainActor
    func testAddingTheSameIngredientAndLocationIncrements() throws {
        let harness = try makeHarness()
        let spinach = try ingredient("Spinach", in: harness)
        harness.model.add(spinach, quantity: 200, unit: .gram, location: .fridge)
        harness.model.add(spinach, quantity: 100, unit: .gram, location: .fridge)

        XCTAssertEqual(harness.model.items.count, 1)
        XCTAssertEqual(harness.model.items.first?.quantity, 300)
    }

    @MainActor
    func testTheSameIngredientInAnotherLocationIsItsOwnRow() throws {
        let harness = try makeHarness()
        let peas = try ingredient("Frozen peas", in: harness)
        harness.model.add(peas, quantity: 500, unit: .gram, location: .freezer)
        harness.model.add(peas, quantity: 200, unit: .gram, location: .fridge)

        harness.model.location = .freezer
        XCTAssertEqual(harness.model.items.map(\.quantity), [500])
        harness.model.location = .fridge
        XCTAssertEqual(harness.model.items.map(\.quantity), [200])
    }

    // MARK: - Using things up

    @MainActor
    func testMarkUsedTakesAnAmountAway() throws {
        let harness = try makeHarness()
        let rice = try ingredient("Basmati rice", in: harness)
        harness.model.add(rice, quantity: 1000, unit: .gram, location: .pantry)
        harness.model.location = .pantry

        let item = try XCTUnwrap(harness.model.items.first)
        harness.model.markUsed(item, quantity: 250)
        XCTAssertEqual(harness.model.items.first?.quantity, 750)
    }

    @MainActor
    func testRanOutRemovesANonStapleButKeepsAStapleAtZero() throws {
        let harness = try makeHarness()
        let broccoli = try ingredient("Broccoli", in: harness)
        let rice = try ingredient("Basmati rice", in: harness)
        XCTAssertFalse(broccoli.isStaple, "Broccoli is bought when a recipe needs it.")
        XCTAssertTrue(rice.isStaple, "Rice is a weekly staple in the catalog.")

        harness.model.add(broccoli, quantity: 300, unit: .gram, location: .fridge)
        harness.model.add(rice, quantity: 1000, unit: .gram, location: .fridge)

        let broccoliItem = try XCTUnwrap(harness.model.items.first { $0.ingredient?.name == "Broccoli" })
        let riceItem = try XCTUnwrap(harness.model.items.first { $0.ingredient?.name == "Basmati rice" })

        harness.model.ranOut(broccoliItem)
        harness.model.ranOut(riceItem)

        XCTAssertNil(harness.model.items.first { $0.ingredient?.name == "Broccoli" },
                     "Something that is gone leaves the pantry.")
        let staple = try XCTUnwrap(harness.model.items.first { $0.ingredient?.name == "Basmati rice" })
        XCTAssertEqual(staple.quantity, 0, "A staple stays visible at zero so the list tops it up.")
    }

    // MARK: - Sorting and filtering

    @MainActor
    func testExpiringSortPutsTheSoonestFirst() throws {
        let harness = try makeHarness(today: D.date(2026, 9, 6))
        let context = harness.stack.context
        let spinach = try ingredient("Spinach", in: harness)      // 5 days
        let milk = try ingredient("Milk", in: harness)
        let rice = try ingredient("Basmati rice", in: harness)    // 365 days

        harness.model.add(rice, quantity: 1000, unit: .gram, location: .fridge)
        harness.model.add(milk, quantity: 1000, unit: .millilitre, location: .fridge)
        harness.model.add(spinach, quantity: 200, unit: .gram, location: .fridge)
        try context.save()

        harness.model.sortOrder = .expiring
        let names = harness.model.items.compactMap { $0.ingredient?.name }
        let expiries = harness.model.items.compactMap(\.expiresAt)
        XCTAssertEqual(expiries, expiries.sorted(), "Soonest to expire comes first.")
        XCTAssertEqual(names.last, "Basmati rice")

        harness.model.sortOrder = .name
        XCTAssertEqual(harness.model.items.compactMap { $0.ingredient?.name },
                       ["Basmati rice", "Milk", "Spinach"])
    }

    @MainActor
    func testExpiringSoonListUsesTheTwoDayWindow() throws {
        let harness = try makeHarness(today: D.date(2026, 9, 6))
        let spinach = try ingredient("Spinach", in: harness)
        let rice = try ingredient("Basmati rice", in: harness)
        harness.model.add(spinach, quantity: 200, unit: .gram, location: .fridge)
        harness.model.add(rice, quantity: 500, unit: .gram, location: .pantry)

        XCTAssertTrue(harness.model.expiringSoon().isEmpty, "Fresh spinach is not urgent yet.")

        let laterModel = PantryViewModel(context: harness.stack.context, now: { D.date(2026, 9, 10) })
        XCTAssertEqual(laterModel.expiringSoon().compactMap { $0.ingredient?.name }, ["Spinach"])
    }

    @MainActor
    func testSearchTextFiltersTheVisibleList() throws {
        let harness = try makeHarness()
        let spinach = try ingredient("Spinach", in: harness)
        let milk = try ingredient("Milk", in: harness)
        harness.model.add(spinach, quantity: 200, unit: .gram, location: .fridge)
        harness.model.add(milk, quantity: 1000, unit: .millilitre, location: .fridge)

        harness.model.searchText = "spin"
        XCTAssertEqual(harness.model.items.compactMap { $0.ingredient?.name }, ["Spinach"])
        harness.model.searchText = "palak"
        XCTAssertEqual(harness.model.items.compactMap { $0.ingredient?.name }, ["Spinach"],
                       "Aliases work in the pantry list too.")
        harness.model.searchText = ""
        XCTAssertEqual(harness.model.items.count, 2)
    }

    @MainActor
    func testSettingAQuantityDirectly() throws {
        let harness = try makeHarness()
        let milk = try ingredient("Milk", in: harness)
        harness.model.add(milk, quantity: 1000, unit: .millilitre, location: .fridge)
        let item = try XCTUnwrap(harness.model.items.first)

        harness.model.setQuantity(500, for: item)
        XCTAssertEqual(harness.model.items.first?.quantity, 500)
        harness.model.setQuantity(-10, for: item)
        XCTAssertEqual(harness.model.items.first?.quantity, 0, "Quantities never go negative.")
    }
}
