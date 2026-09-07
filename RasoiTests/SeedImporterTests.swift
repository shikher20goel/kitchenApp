import SwiftData
import XCTest
@testable import Rasoi

final class SeedImporterTests: XCTestCase {
    @MainActor
    func testImportLoadsTheWholeCatalog() throws {
        let stack = try TestContainer.makeStack()
        let result = try SeedImporter.reimport(in: stack.context)

        XCTAssertGreaterThanOrEqual(result.ingredientsInserted, 180)
        XCTAssertGreaterThanOrEqual(result.recipesInserted, 50)
        XCTAssertEqual(try stack.context.fetch(FetchDescriptor<Ingredient>()).count, result.ingredientsInserted)
        XCTAssertEqual(try stack.context.fetch(FetchDescriptor<Recipe>()).count, result.recipesInserted)
    }

    @MainActor
    func testImportingTwiceChangesNothing() throws {
        let stack = try TestContainer.makeStack()
        try SeedImporter.reimport(in: stack.context)
        let ingredientCount = try stack.context.fetch(FetchDescriptor<Ingredient>()).count
        let recipeCount = try stack.context.fetch(FetchDescriptor<Recipe>()).count

        let second = try SeedImporter.reimport(in: stack.context)
        XCTAssertEqual(second.ingredientsInserted, 0)
        XCTAssertEqual(second.recipesInserted, 0)
        XCTAssertEqual(try stack.context.fetch(FetchDescriptor<Ingredient>()).count, ingredientCount)
        XCTAssertEqual(try stack.context.fetch(FetchDescriptor<Recipe>()).count, recipeCount)
    }

    @MainActor
    func testImportIfNeededSkipsOnceTheVersionIsRecorded() throws {
        let stack = try TestContainer.makeStack()
        let first = try SeedImporter.importIfNeeded(in: stack.context)
        XCTAssertFalse(first.skipped)
        XCTAssertGreaterThan(DietProfile.current(in: stack.context).seedVersion, 0)

        let second = try SeedImporter.importIfNeeded(in: stack.context)
        XCTAssertTrue(second.skipped, "A second launch does no work.")
    }

    @MainActor
    func testFavouriteAndHiddenSurviveAReimport() throws {
        let stack = try TestContainer.makeStack()
        try SeedImporter.reimport(in: stack.context)

        let recipe = try XCTUnwrap(try stack.context.fetch(FetchDescriptor<Recipe>()).first)
        let seedID = try XCTUnwrap(recipe.seedID)
        recipe.isFavorite = true
        recipe.isHidden = true
        try stack.context.save()

        try SeedImporter.reimport(in: stack.context)
        let reloaded = try XCTUnwrap(
            try stack.context.fetch(FetchDescriptor<Recipe>()).first { $0.seedID == seedID }
        )
        XCTAssertTrue(reloaded.isFavorite, "A favourite is the household's, not the catalog's.")
        XCTAssertTrue(reloaded.isHidden)
    }

    @MainActor
    func testUserRecipesSurviveAReimport() throws {
        let stack = try TestContainer.makeStack()
        try SeedImporter.reimport(in: stack.context)

        let mine = Recipe(
            title: "Ira's birthday pancakes",
            cuisine: "American",
            mealTypes: [.breakfast],
            appliances: [.stovetop],
            prepMinutes: 10,
            cookMinutes: 10,
            servings: 4,
            minAgeYears: 2,
            ingredients: [RecipeIngredient(ingredientName: "Milk", quantity: 200, unit: .millilitre)],
            steps: ["Mix", "Cook"],
            source: .user
        )
        stack.context.insert(mine)
        try stack.context.save()

        try SeedImporter.reimport(in: stack.context)
        let userRecipes = try stack.context.fetch(FetchDescriptor<Recipe>()).filter { $0.source == .user }
        XCTAssertEqual(userRecipes.map(\.title), ["Ira's birthday pancakes"])
    }

    @MainActor
    func testCatalogEditsAreRefreshedFromTheSeed() throws {
        let stack = try TestContainer.makeStack()
        try SeedImporter.reimport(in: stack.context)

        let recipe = try XCTUnwrap(try stack.context.fetch(FetchDescriptor<Recipe>()).first)
        let seedID = try XCTUnwrap(recipe.seedID)
        let realTitle = recipe.title
        recipe.title = "Overwritten by a bug"
        try stack.context.save()

        try SeedImporter.reimport(in: stack.context)
        let reloaded = try XCTUnwrap(
            try stack.context.fetch(FetchDescriptor<Recipe>()).first { $0.seedID == seedID }
        )
        XCTAssertEqual(reloaded.title, realTitle)
    }

    @MainActor
    func testEveryImportedRecipeResolvesAgainstTheImportedCatalog() throws {
        let stack = try TestContainer.makeStack()
        try SeedImporter.reimport(in: stack.context)

        let names = Set(try stack.context.fetch(FetchDescriptor<Ingredient>()).map { Ingredient.fold($0.name) })
        for recipe in try stack.context.fetch(FetchDescriptor<Recipe>()) {
            for line in recipe.ingredients {
                XCTAssertTrue(names.contains(Ingredient.fold(line.ingredientName)),
                              "\(recipe.title) needs \(line.ingredientName), which is not in the pantry catalog")
            }
        }
    }
}
