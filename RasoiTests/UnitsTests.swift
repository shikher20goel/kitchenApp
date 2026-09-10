import XCTest
@testable import Rasoi

final class UnitsTests: XCTestCase {
    func testMassConversions() {
        XCTAssertEqual(Units.convert(1, from: .kilogram, to: .gram) ?? 0, 1000, accuracy: 0.0001)
        XCTAssertEqual(Units.convert(250, from: .gram, to: .kilogram) ?? 0, 0.25, accuracy: 0.0001)
    }

    func testVolumeConversions() {
        XCTAssertEqual(Units.convert(1, from: .litre, to: .millilitre) ?? 0, 1000, accuracy: 0.0001)
        XCTAssertEqual(Units.convert(1, from: .cup, to: .millilitre) ?? 0, 240, accuracy: 0.0001)
        XCTAssertEqual(Units.convert(1, from: .tablespoon, to: .millilitre) ?? 0, 15, accuracy: 0.0001)
        XCTAssertEqual(Units.convert(1, from: .teaspoon, to: .millilitre) ?? 0, 5, accuracy: 0.0001)
        XCTAssertEqual(Units.convert(480, from: .millilitre, to: .cup) ?? 0, 2, accuracy: 0.0001)
    }

    func testCountsOnlyConvertToThemselves() {
        XCTAssertEqual(Units.convert(3, from: .count, to: .count) ?? 0, 3, accuracy: 0.0001)
        XCTAssertNil(Units.convert(1, from: .bunch, to: .count), "A bunch is not a number of things.")
    }

    func testDimensionsNeverMix() {
        XCTAssertNil(Units.convert(100, from: .gram, to: .millilitre))
        XCTAssertNil(Units.convert(2, from: .count, to: .gram))
    }

    func testAddingAndSubtracting() {
        XCTAssertEqual(Units.add(Quantity(200, .gram), Quantity(1, .kilogram))?.amount ?? 0, 1200, accuracy: 0.0001)
        XCTAssertEqual(Units.subtract(Quantity(1, .kilogram), Quantity(250, .gram))?.amount ?? 0, 0.75, accuracy: 0.0001)
        XCTAssertNil(Units.add(Quantity(200, .gram), Quantity(1, .litre)))
    }

    func testSubtractingMoreThanThereIsFloorsAtZero() {
        XCTAssertEqual(Units.subtract(Quantity(100, .gram), Quantity(1, .kilogram))?.amount ?? -1, 0, accuracy: 0.0001)
    }

    func testSummingGroupsByDimension() {
        let totals = Units.sum([
            Quantity(200, .gram), Quantity(1, .kilogram),
            Quantity(2, .cup), Quantity(100, .millilitre),
            Quantity(3, .count),
        ])
        XCTAssertEqual(totals.count, 3)
        XCTAssertEqual(totals[0].unit, .gram)
        XCTAssertEqual(totals[0].amount, 1200, accuracy: 0.0001)
        XCTAssertEqual(totals[1].unit, .millilitre)
        XCTAssertEqual(totals[1].amount, 580, accuracy: 0.0001)
        XCTAssertEqual(totals[2].unit, .count)
        XCTAssertEqual(totals[2].amount, 3, accuracy: 0.0001)
    }

    func testDisplayReadsLikeAShoppingList() {
        XCTAssertEqual(Units.display(Quantity(1200, .gram)), "1.2 kg")
        XCTAssertEqual(Units.display(Quantity(250, .gram)), "250 g")
        XCTAssertEqual(Units.display(Quantity(1, .litre)), "1 l")
        XCTAssertEqual(Units.display(Quantity(500, .millilitre)), "500 ml")
        XCTAssertEqual(Units.display(Quantity(3, .count)), "×3")
        XCTAssertEqual(Units.display(Quantity(1, .bunch)), "1 bunch")
        XCTAssertEqual(Units.display(Quantity(2, .cup)), "480 ml")
    }
}

/// Spoons and grams have to meet: recipes measure salt and spices in teaspoons, the pantry and
/// the shop deal in grams.
final class UnitDensityTests: XCTestCase {
    /// A level teaspoon of fine salt weighs about six grams.
    private let saltDensity = 6.0

    func testATeaspoonBecomesGramsWhenTheDensityIsKnown() {
        XCTAssertEqual(Units.convert(1, from: .teaspoon, to: .gram, gramsPerTeaspoon: saltDensity) ?? 0,
                       6, accuracy: 0.0001)
        XCTAssertEqual(Units.convert(1, from: .tablespoon, to: .gram, gramsPerTeaspoon: saltDensity) ?? 0,
                       18, accuracy: 0.0001, "A tablespoon is three teaspoons.")
    }

    func testGramsBecomeTeaspoons() {
        XCTAssertEqual(Units.convert(30, from: .gram, to: .teaspoon, gramsPerTeaspoon: saltDensity) ?? 0,
                       5, accuracy: 0.0001)
    }

    func testWithoutADensityTheDimensionsStayApart() {
        XCTAssertNil(Units.convert(1, from: .teaspoon, to: .gram))
        XCTAssertNil(Units.convert(1, from: .teaspoon, to: .gram, gramsPerTeaspoon: 0))
    }

    func testSubtractingSpoonsFromAJarMeasuredInGrams() {
        let jar = Quantity(500, .gram)
        let used = Quantity(2, .teaspoon)
        XCTAssertEqual(Units.subtract(jar, used, gramsPerTeaspoon: saltDensity)?.amount ?? 0,
                       488, accuracy: 0.0001)
    }

    func testAddingSpoonsToGrams() {
        let total = Units.add(Quantity(10, .gram), Quantity(1, .teaspoon), gramsPerTeaspoon: saltDensity)
        XCTAssertEqual(total?.amount ?? 0, 16, accuracy: 0.0001)
    }

    func testCountsStillNeverConvert() {
        XCTAssertNil(Units.convert(2, from: .count, to: .gram, gramsPerTeaspoon: saltDensity))
    }
}

/// The end of the story: a recipe asking for spoons of a spice you already have does not put that
/// spice back on the shopping list.
final class SpoonMeasuredShoppingTests: XCTestCase {
    private let index = IngredientIndex(facts: [
        IngredientFacts(name: "Salt", category: .spice, defaultUnit: .gram, typicalShelfLifeDays: 3650,
                        isStaple: true, gramsPerTeaspoon: 6),
        IngredientFacts(name: "Turmeric", category: .spice, defaultUnit: .gram, typicalShelfLifeDays: 730,
                        gramsPerTeaspoon: 3),
    ])

    private let stores = [
        StoreSnapshot(id: "Walmart", name: "Walmart", kind: .supermarket, isPreferred: true,
                      sortOrder: 0, affinities: Set(IngredientCategory.allCases)),
    ]

    @MainActor
    func testSpiceYouAlreadyHaveIsNotRebought() {
        let meal = PlannedRecipe(
            recipeID: "dal", title: "Dal",
            ingredients: [
                RecipeIngredient(ingredientName: "Salt", quantity: 1.25, unit: .teaspoon),
                RecipeIngredient(ingredientName: "Turmeric", quantity: 0.5, unit: .teaspoon),
            ],
            recipeServings: 4, servings: 4
        )
        let pantry = PantrySnapshot(items: [
            PantryStock(name: "Salt", quantity: 500, unit: .gram, expiresAt: nil),
            PantryStock(name: "Turmeric", quantity: 100, unit: .gram, expiresAt: nil),
        ])

        let lines = GroceryBuilder.build(meals: [meal], pantry: pantry, index: index,
                                         stores: stores, includeStaples: false)
        XCTAssertTrue(lines.isEmpty, "A jar of salt covers a teaspoon of salt: \(lines)")
    }

    @MainActor
    func testAnEmptyJarStillLandsOnTheList() {
        let meal = PlannedRecipe(
            recipeID: "dal", title: "Dal",
            ingredients: [RecipeIngredient(ingredientName: "Turmeric", quantity: 2, unit: .teaspoon)],
            recipeServings: 4, servings: 4
        )
        let lines = GroceryBuilder.build(meals: [meal], pantry: PantrySnapshot(items: []),
                                         index: index, stores: stores, includeStaples: false)
        XCTAssertEqual(lines.map(\.ingredientName), ["Turmeric"])
    }
}
