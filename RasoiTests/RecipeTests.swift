import SwiftData
import XCTest
@testable import Rasoi

final class RecipeTests: XCTestCase {
    @MainActor
    private func dalRecipe(seedID: String? = "dn-toor-dal") -> Recipe {
        Recipe(
            title: "Everyday toor dal",
            cuisine: "Indian",
            mealTypes: [.lunch, .dinner],
            appliances: [.instantPot],
            prepMinutes: 10,
            cookMinutes: 20,
            servings: 4,
            minAgeYears: 2,
            ingredients: [
                RecipeIngredient(ingredientName: "Toor dal", quantity: 200, unit: .gram),
                RecipeIngredient(ingredientName: "Tomato", quantity: 2, unit: .count),
                RecipeIngredient(ingredientName: "Coriander", quantity: 1, unit: .bunch,
                                 isOptional: true, note: "to finish"),
            ],
            steps: ["Rinse the dal.", "Pressure cook 8 minutes.", "Temper and stir in."],
            nutritionTags: ["protein", "iron"],
            kidBaseline: 4,
            kidFriendlyNote: "Keep the chilli out and serve with rice.",
            seedID: seedID
        )
    }

    @MainActor
    func testInsertWithThreeIngredients() throws {
        let stack = try TestContainer.makeStack()
        stack.context.insert(dalRecipe())
        try stack.context.save()

        let recipe = try XCTUnwrap(try stack.context.fetch(FetchDescriptor<Recipe>()).first)
        XCTAssertEqual(recipe.ingredients.count, 3)
        XCTAssertEqual(recipe.ingredients.map(\.ingredientName), ["Toor dal", "Tomato", "Coriander"])
        XCTAssertEqual(recipe.ingredients.last?.unit, .bunch)
        XCTAssertTrue(recipe.ingredients.last?.isOptional == true)
        XCTAssertEqual(recipe.requiredIngredients.count, 2, "Optional ingredients are not required.")
        XCTAssertEqual(recipe.steps.count, 3)
        XCTAssertEqual(recipe.mealTypes, [.lunch, .dinner])
        XCTAssertEqual(recipe.applianceSet, [.instantPot])
        XCTAssertEqual(recipe.source, .seed)
    }

    @MainActor
    func testTotalMinutesSumsPrepAndCook() throws {
        let recipe = dalRecipe()
        XCTAssertEqual(recipe.totalMinutes, 30)
    }

    @MainActor
    func testIsQuickBoundaryAtFifteenMinutes() throws {
        let recipe = dalRecipe()
        recipe.prepMinutes = 5
        recipe.cookMinutes = 10
        XCTAssertTrue(recipe.isQuick, "15 minutes total still counts as quick.")
        recipe.cookMinutes = 11
        XCTAssertFalse(recipe.isQuick, "16 minutes does not.")
    }

    @MainActor
    func testSeedIDIsUnique() throws {
        let stack = try TestContainer.makeStack()
        stack.context.insert(dalRecipe())
        try stack.context.save()

        let duplicate = dalRecipe()
        duplicate.title = "Toor dal, again"
        stack.context.insert(duplicate)
        try stack.context.save()

        let recipes = try stack.context.fetch(FetchDescriptor<Recipe>())
        XCTAssertEqual(recipes.count, 1, "A seedID identifies one catalog recipe.")
        XCTAssertEqual(recipes.first?.title, "Toor dal, again")
    }

    @MainActor
    func testUserRecipesWithoutASeedIDCoexist() throws {
        let stack = try TestContainer.makeStack()
        let first = dalRecipe(seedID: nil)
        first.title = "Ira's pasta"
        first.source = .user
        let second = dalRecipe(seedID: nil)
        second.title = "Weekend khichdi"
        second.source = .user
        stack.context.insert(first)
        stack.context.insert(second)
        try stack.context.save()

        XCTAssertEqual(try stack.context.fetch(FetchDescriptor<Recipe>()).count, 2,
                       "User recipes have no seedID and must not collide.")
    }

    @MainActor
    func testScaledIngredientsForMoreServings() throws {
        let recipe = dalRecipe()
        let scaled = recipe.scaledIngredients(toServings: 6)
        XCTAssertEqual(scaled.count, 3)
        XCTAssertEqual(scaled[0].quantity, 300, accuracy: 0.0001, "200 g for 4 becomes 300 g for 6.")
        XCTAssertEqual(scaled[1].quantity, 3, accuracy: 0.0001)
    }

    @MainActor
    func testFavouriteAndHiddenDefaultOff() throws {
        let recipe = dalRecipe()
        XCTAssertFalse(recipe.isFavorite)
        XCTAssertFalse(recipe.isHidden)
        XCTAssertFalse(recipe.lunchboxOK)
        XCTAssertEqual(recipe.kidBaseline, 4)
        XCTAssertEqual(recipe.kidFriendlyNote, "Keep the chilli out and serve with rice.")
    }

    @MainActor
    func testUsesIngredientMatchesByNameIgnoringCase() throws {
        let recipe = dalRecipe()
        XCTAssertTrue(recipe.uses(ingredientNamed: "toor dal"))
        XCTAssertTrue(recipe.uses(ingredientNamed: "Coriander"))
        XCTAssertFalse(recipe.uses(ingredientNamed: "Paneer"))
    }
}
