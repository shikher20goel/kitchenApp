import XCTest
@testable import Rasoi

final class QuickSnacksTests: XCTestCase {
    private let today = D.date(2026, 9, 7)

    private let index = IngredientIndex(facts: [
        Fixtures.facts("Banana", category: .fruit, unit: .count, nutritionTags: ["fruit"], quickSnack: true),
        Fixtures.facts("Apple", category: .fruit, unit: .count, nutritionTags: ["fruit"], quickSnack: true),
        Fixtures.facts("Plain yogurt", category: .dairy, nutritionTags: ["calcium"], dairy: true, quickSnack: true),
        Fixtures.facts("Cucumber", category: .vegetable, nutritionTags: ["vegetable"], quickSnack: true),
        Fixtures.facts("Spinach", aliases: ["palak"], category: .leafyGreen, nutritionTags: ["vegetable"]),
        Fixtures.facts("Toor dal", category: .legume, nutritionTags: ["protein"]),
    ])

    private var smoothie: RecipeSummary {
        Fixtures.recipe(
            id: "sn-green-smoothie",
            title: "Green Monster Smoothie",
            mealTypes: [.snack],
            appliances: [.vitamix],
            prepMinutes: 5,
            cookMinutes: 0,
            ingredients: [("Spinach", 60, .gram, false), ("Banana", 2, .count, false),
                          ("Plain yogurt", 150, .gram, false)],
            nutritionTags: ["fruit", "vegetable", "calcium"]
        )
    }

    private func pantry(_ items: [(String, Double, MeasurementUnit, Date?)]) -> PantrySnapshot {
        PantrySnapshot(items: items.map {
            PantryStock(name: $0.0, quantity: $0.1, unit: $0.2, expiresAt: $0.3)
        })
    }

    func testFruitComesFirst() {
        let suggestions = QuickSnacks.suggestions(
            pantry: pantry([("Plain yogurt", 500, .gram, nil), ("Apple", 4, .count, nil)]),
            index: index, recipes: [], on: today
        )
        XCTAssertEqual(suggestions.first?.title, "Apple")
        XCTAssertEqual(suggestions.map(\.title), ["Apple", "Plain yogurt"])
    }

    func testASmoothieTheKitchenCanMakeIsOffered() {
        let suggestions = QuickSnacks.suggestions(
            pantry: pantry([
                ("Banana", 3, .count, nil),
                ("Spinach", 200, .gram, nil),
                ("Plain yogurt", 500, .gram, nil),
            ]),
            index: index, recipes: [smoothie], on: today
        )
        XCTAssertEqual(suggestions.map(\.title), ["Banana", "Green Monster Smoothie", "Plain yogurt"])
        XCTAssertEqual(suggestions[1].source, .recipe)
        XCTAssertEqual(suggestions[1].recipeID, "sn-green-smoothie")
    }

    func testARecipeMissingAnIngredientIsNotOffered() {
        let suggestions = QuickSnacks.suggestions(
            pantry: pantry([("Banana", 3, .count, nil), ("Plain yogurt", 500, .gram, nil)]),
            index: index, recipes: [smoothie], on: today
        )
        XCTAssertFalse(suggestions.contains { $0.source == .recipe }, "No spinach, no smoothie.")
    }

    func testAtMostThree() {
        let suggestions = QuickSnacks.suggestions(
            pantry: pantry([
                ("Apple", 4, .count, nil), ("Banana", 3, .count, nil),
                ("Cucumber", 2, .count, nil), ("Plain yogurt", 500, .gram, nil),
            ]),
            index: index, recipes: [], on: today
        )
        XCTAssertEqual(suggestions.count, QuickSnacks.defaultLimit)
    }

    func testWhatIsAboutToGoOffIsOfferedFirst() {
        let suggestions = QuickSnacks.suggestions(
            pantry: pantry([
                ("Apple", 4, .count, D.date(2026, 9, 30)),
                ("Banana", 3, .count, D.date(2026, 9, 8)),
            ]),
            index: index, recipes: [], on: today
        )
        XCTAssertEqual(suggestions.map(\.title), ["Banana", "Apple"])
        XCTAssertEqual(suggestions.first?.detail, "1 day left")
    }

    func testThingsThatAreNotSnacksAreNeverSuggested() {
        let suggestions = QuickSnacks.suggestions(
            pantry: pantry([("Toor dal", 500, .gram, nil), ("Spinach", 200, .gram, nil)]),
            index: index, recipes: [], on: today
        )
        XCTAssertTrue(suggestions.isEmpty, "Raw dal is not a snack.")
    }

    func testAnEmptyKitchenSuggestsNothing() {
        XCTAssertTrue(QuickSnacks.suggestions(pantry: pantry([]), index: index, recipes: [smoothie],
                                              on: today).isEmpty)
    }

    func testSuggestionsAreDeterministic() {
        let items: [(String, Double, MeasurementUnit, Date?)] = [
            ("Apple", 4, .count, nil), ("Banana", 3, .count, nil), ("Cucumber", 2, .count, nil),
        ]
        let first = QuickSnacks.suggestions(pantry: pantry(items), index: index, recipes: [], on: today)
        let second = QuickSnacks.suggestions(pantry: pantry(items.reversed()), index: index, recipes: [], on: today)
        XCTAssertEqual(first.map(\.title), second.map(\.title))
    }

    func testAnEmptyPantryRowIsNotOffered() {
        let suggestions = QuickSnacks.suggestions(
            pantry: pantry([("Apple", 0, .count, nil), ("Banana", 2, .count, nil)]),
            index: index, recipes: [], on: today
        )
        XCTAssertEqual(suggestions.map(\.title), ["Banana"])
    }
}
