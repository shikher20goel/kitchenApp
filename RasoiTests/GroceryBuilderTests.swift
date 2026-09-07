import XCTest
@testable import Rasoi

final class GroceryBuilderTests: XCTestCase {
    // MARK: - Fixtures

    private let index = IngredientIndex(facts: [
        Fixtures.facts("Onion", category: .vegetable),
        Fixtures.facts("Toor dal", aliases: ["arhar dal"], category: .legume, isStaple: true, storeKind: .indian),
        Fixtures.facts("Basmati rice", category: .grain, isStaple: true),
        Fixtures.facts("Milk", category: .dairy, unit: .millilitre, isStaple: true),
        Fixtures.facts("Paneer", category: .dairy, isStaple: false),
        Fixtures.facts("Spinach", aliases: ["palak"], category: .leafyGreen),
        Fixtures.facts("Garam masala", category: .spice, isStaple: true, storeKind: .indian),
        Fixtures.facts("Tomato", category: .vegetable),
    ])

    private let stores = [
        StoreSnapshot(id: "Walmart", name: "Walmart", kind: .supermarket, isPreferred: true,
                      sortOrder: 0, affinities: Set(IngredientCategory.allCases)),
        StoreSnapshot(id: "Indian grocery", name: "Indian grocery", kind: .indian, isPreferred: true,
                      sortOrder: 3, affinities: [.legume, .spice, .flourBread, .dairy]),
    ]

    private func meal(
        _ title: String,
        _ ingredients: [(String, Double, MeasurementUnit)],
        recipeServings: Int = 4,
        servings: Int = 4
    ) -> PlannedRecipe {
        PlannedRecipe(
            recipeID: title,
            title: title,
            ingredients: ingredients.map {
                RecipeIngredient(ingredientName: $0.0, quantity: $0.1, unit: $0.2)
            },
            recipeServings: recipeServings,
            servings: servings
        )
    }

    private func build(
        meals: [PlannedRecipe],
        pantry: PantrySnapshot = PantrySnapshot(items: []),
        includeStaples: Bool = false
    ) -> [GroceryLine] {
        GroceryBuilder.build(
            meals: meals,
            pantry: pantry,
            index: index,
            stores: stores,
            includeStaples: includeStaples
        )
    }

    private func line(_ lines: [GroceryLine], _ name: String) -> GroceryLine? {
        lines.first { Ingredient.fold($0.ingredientName) == Ingredient.fold(name) }
    }

    // MARK: - Aggregation

    func testTwoRecipesSharingAnIngredientBecomeOneLine() {
        let lines = build(meals: [
            meal("Dal", [("Onion", 1, .count), ("Toor dal", 200, .gram)]),
            meal("Curry", [("Onion", 2, .count), ("Paneer", 200, .gram)]),
        ])
        let onion = try? XCTUnwrap(line(lines, "Onion"))
        XCTAssertEqual(onion?.quantity ?? 0, 3, accuracy: 0.0001)
        XCTAssertEqual(onion?.neededFor, ["Curry", "Dal"], "Both recipes are named, in a stable order.")
        XCTAssertEqual(lines.filter { $0.ingredientName == "Onion" }.count, 1)
    }

    func testQuantitiesScaleWithTheServingsCooked() {
        let lines = build(meals: [meal("Dal", [("Toor dal", 200, .gram)], recipeServings: 4, servings: 6)])
        XCTAssertEqual(line(lines, "Toor dal")?.quantity ?? 0, 300, accuracy: 0.0001)
    }

    func testDifferentUnitsAreNormalisedBeforeAdding() {
        let lines = build(meals: [
            meal("A", [("Basmati rice", 500, .gram)]),
            meal("B", [("Basmati rice", 1, .kilogram)]),
        ])
        let rice = line(lines, "Basmati rice")
        XCTAssertEqual(rice?.quantity ?? 0, 1500, accuracy: 0.0001)
        XCTAssertEqual(rice?.unit, .gram, "Everything is summed in the canonical unit.")
    }

    func testAliasesResolveToOneCatalogLine() {
        let lines = build(meals: [
            meal("A", [("palak", 200, .gram)]),
            meal("B", [("Spinach", 100, .gram)]),
        ])
        XCTAssertEqual(lines.filter { $0.ingredientName == "Spinach" }.count, 1)
        XCTAssertEqual(line(lines, "Spinach")?.quantity ?? 0, 300, accuracy: 0.0001)
    }

    func testOptionalIngredientsAreStillBought() {
        let optional = PlannedRecipe(
            recipeID: "A", title: "A",
            ingredients: [RecipeIngredient(ingredientName: "Tomato", quantity: 2, unit: .count, isOptional: true)],
            recipeServings: 4, servings: 4
        )
        XCTAssertNotNil(line(build(meals: [optional]), "Tomato"),
                        "A garnish you meant to make is still on the list.")
    }

    // MARK: - Pantry subtraction

    func testWhatIsAlreadyInThePantryIsSubtracted() {
        let pantry = PantrySnapshot(items: [
            PantryStock(name: "Toor dal", quantity: 150, unit: .gram, expiresAt: nil),
        ])
        let lines = build(meals: [meal("Dal", [("Toor dal", 200, .gram)])], pantry: pantry)
        XCTAssertEqual(line(lines, "Toor dal")?.quantity ?? 0, 50, accuracy: 0.0001)
    }

    func testAnIngredientYouHaveEnoughOfDropsOffTheList() {
        let pantry = PantrySnapshot(items: [
            PantryStock(name: "Toor dal", quantity: 1, unit: .kilogram, expiresAt: nil),
        ])
        let lines = build(meals: [meal("Dal", [("Toor dal", 200, .gram)])], pantry: pantry)
        XCTAssertNil(line(lines, "Toor dal"))
    }

    // MARK: - Staples

    func testStaplesYouAreOutOfAreToppedUp() {
        let lines = build(meals: [meal("Dal", [("Toor dal", 200, .gram)])], includeStaples: true)
        let milk = line(lines, "Milk")
        XCTAssertNotNil(milk, "Milk is a weekly staple, whether or not a recipe asks for it.")
        XCTAssertTrue(milk?.isStapleTopUp == true)
        XCTAssertTrue(milk?.neededFor.isEmpty == true)
        XCTAssertGreaterThan(milk?.quantity ?? 0, 0)
    }

    func testAStapleYouHavePlentyOfIsNotToppedUp() {
        let pantry = PantrySnapshot(items: [
            PantryStock(name: "Milk", quantity: 2, unit: .litre, expiresAt: nil),
            PantryStock(name: "Basmati rice", quantity: 2, unit: .kilogram, expiresAt: nil),
            PantryStock(name: "Toor dal", quantity: 1, unit: .kilogram, expiresAt: nil),
            PantryStock(name: "Garam masala", quantity: 100, unit: .gram, expiresAt: nil),
        ])
        let lines = build(meals: [], pantry: pantry, includeStaples: true)
        XCTAssertTrue(lines.isEmpty, "Nothing to buy when the staples are all in.")
    }

    func testAStapleBelowItsThresholdIsToppedUp() {
        let pantry = PantrySnapshot(items: [
            PantryStock(name: "Milk", quantity: 200, unit: .millilitre, expiresAt: nil, lowThreshold: 500),
            PantryStock(name: "Basmati rice", quantity: 2, unit: .kilogram, expiresAt: nil),
            PantryStock(name: "Toor dal", quantity: 1, unit: .kilogram, expiresAt: nil),
            PantryStock(name: "Garam masala", quantity: 100, unit: .gram, expiresAt: nil),
        ])
        let lines = build(meals: [], pantry: pantry, includeStaples: true)
        XCTAssertEqual(lines.map(\.ingredientName), ["Milk"])
        XCTAssertTrue(line(lines, "Milk")?.isStapleTopUp == true)
    }

    // MARK: - Stores

    func testSpecialityStoresClaimTheirCategories() {
        let lines = build(meals: [
            meal("Dal", [("Toor dal", 200, .gram), ("Garam masala", 10, .gram), ("Onion", 2, .count)]),
        ])
        XCTAssertEqual(line(lines, "Toor dal")?.storeID, "Indian grocery")
        XCTAssertEqual(line(lines, "Garam masala")?.storeID, "Indian grocery")
        XCTAssertEqual(line(lines, "Onion")?.storeID, "Walmart", "Vegetables fall to the supermarket.")
    }

    func testWithoutAMatchingStoreTheFirstPreferredGeneralStoreIsUsed() {
        let onlySpeciality = [
            StoreSnapshot(id: "Indian grocery", name: "Indian grocery", kind: .indian, isPreferred: true,
                          sortOrder: 0, affinities: [.legume, .spice]),
        ]
        let lines = GroceryBuilder.build(
            meals: [meal("Salad", [("Tomato", 3, .count)])],
            pantry: PantrySnapshot(items: []),
            index: index,
            stores: onlySpeciality,
            includeStaples: false
        )
        XCTAssertNil(line(lines, "Tomato")?.storeID, "With nowhere obvious, the line says any store.")
    }

    func testStoresTheHouseholdDoesNotShopAtAreIgnored() {
        let notPreferred = stores.map { store -> StoreSnapshot in
            var copy = store
            if copy.id == "Indian grocery" { copy.isPreferred = false }
            return copy
        }
        let lines = GroceryBuilder.build(
            meals: [meal("Dal", [("Toor dal", 200, .gram)])],
            pantry: PantrySnapshot(items: []),
            index: index,
            stores: notPreferred,
            includeStaples: false
        )
        XCTAssertEqual(line(lines, "Toor dal")?.storeID, "Walmart")
    }

    // MARK: - Ordering and determinism

    func testLinesComeBackInAStableOrder() {
        let first = build(meals: [
            meal("Dal", [("Toor dal", 200, .gram), ("Onion", 2, .count)]),
            meal("Curry", [("Paneer", 200, .gram), ("Spinach", 300, .gram)]),
        ])
        let second = build(meals: [
            meal("Curry", [("Spinach", 300, .gram), ("Paneer", 200, .gram)]),
            meal("Dal", [("Onion", 2, .count), ("Toor dal", 200, .gram)]),
        ])
        XCTAssertEqual(first.map(\.ingredientName), second.map(\.ingredientName))
        XCTAssertEqual(first.map(\.quantity), second.map(\.quantity))
    }

    // MARK: - Merging into an existing list

    func testMergeAddsWhatIsNewAndUpdatesWhatChanged() {
        let built = build(meals: [meal("Dal", [("Toor dal", 300, .gram), ("Onion", 2, .count)])])
        let existing = [
            ExistingGroceryLine(ingredientName: "Toor dal", quantity: 200, unit: .gram,
                                isChecked: false, addedManually: false),
        ]
        let plan = GroceryBuilder.merge(built, into: existing)

        XCTAssertEqual(plan.inserts.map(\.ingredientName), ["Onion"])
        XCTAssertEqual(plan.updates.count, 1)
        XCTAssertEqual(plan.updates.first?.ingredientName, "Toor dal")
        XCTAssertEqual(plan.updates.first?.quantity ?? 0, 300, accuracy: 0.0001)
        XCTAssertTrue(plan.removals.isEmpty)
    }

    func testMergeLeavesCheckedItemsAlone() {
        let built = build(meals: [meal("Dal", [("Toor dal", 500, .gram)])])
        let existing = [
            ExistingGroceryLine(ingredientName: "Toor dal", quantity: 200, unit: .gram,
                                isChecked: true, addedManually: false),
        ]
        let plan = GroceryBuilder.merge(built, into: existing)

        XCTAssertTrue(plan.inserts.isEmpty)
        XCTAssertTrue(plan.updates.isEmpty, "It is already in the trolley — do not change it.")
        XCTAssertTrue(plan.removals.isEmpty)
    }

    func testMergeDropsLinesThatAreNoLongerNeeded() {
        let built = build(meals: [meal("Dal", [("Toor dal", 200, .gram)])])
        let existing = [
            ExistingGroceryLine(ingredientName: "Toor dal", quantity: 200, unit: .gram,
                                isChecked: false, addedManually: false),
            ExistingGroceryLine(ingredientName: "Paneer", quantity: 200, unit: .gram,
                                isChecked: false, addedManually: false),
        ]
        let plan = GroceryBuilder.merge(built, into: existing)
        XCTAssertEqual(plan.removals, ["Paneer"])
    }

    func testMergeKeepsManualAndCheckedLinesEvenWhenUnplanned() {
        let built = build(meals: [meal("Dal", [("Toor dal", 200, .gram)])])
        let existing = [
            ExistingGroceryLine(ingredientName: "Paper towels", quantity: 1, unit: .count,
                                isChecked: false, addedManually: true),
            ExistingGroceryLine(ingredientName: "Paneer", quantity: 200, unit: .gram,
                                isChecked: true, addedManually: false),
        ]
        let plan = GroceryBuilder.merge(built, into: existing)
        XCTAssertTrue(plan.removals.isEmpty, "Nothing the household added or already bought is taken away.")
    }

    func testMergingTwiceChangesNothingTheSecondTime() {
        let built = build(meals: [meal("Dal", [("Toor dal", 200, .gram), ("Onion", 2, .count)])])
        let existing = built.map {
            ExistingGroceryLine(ingredientName: $0.ingredientName, quantity: $0.quantity,
                                unit: $0.unit, isChecked: false, addedManually: false)
        }
        let plan = GroceryBuilder.merge(built, into: existing)
        XCTAssertTrue(plan.inserts.isEmpty)
        XCTAssertTrue(plan.updates.isEmpty)
        XCTAssertTrue(plan.removals.isEmpty)
    }
}
