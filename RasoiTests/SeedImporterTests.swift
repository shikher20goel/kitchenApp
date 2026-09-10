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

/// A household that edits a seeded recipe owns it from then on (SPEC R6).
final class SeedRecipeEditingTests: XCTestCase {
    @MainActor
    private func seededStack() throws -> TestStack {
        let stack = try TestContainer.makeStack()
        try SeedImporter.reimport(in: stack.context)
        return stack
    }

    @MainActor
    private func firstSeedRecipe(_ stack: TestStack) throws -> Recipe {
        try XCTUnwrap(
            try stack.context.fetch(FetchDescriptor<Recipe>(sortBy: [SortDescriptor(\.title)]))
                .first { $0.seedID != nil }
        )
    }

    @MainActor
    func testEditingASeededRecipeMarksItAsTheHouseholds() throws {
        let stack = try seededStack()
        let recipe = try firstSeedRecipe(stack)
        XCTAssertFalse(recipe.isUserEdited)

        let editor = RecipeEditorViewModel(context: stack.context, recipe: recipe)
        editor.draft.steps = ["My own way of doing it."]
        XCTAssertNotNil(editor.save())

        XCTAssertTrue(recipe.isUserEdited)
        XCTAssertEqual(recipe.steps, ["My own way of doing it."])
        XCTAssertNotNil(recipe.seedID, "It is still the same catalog recipe, not a copy.")
    }

    @MainActor
    func testAReimportLeavesAnEditedRecipeAlone() throws {
        let stack = try seededStack()
        let recipe = try firstSeedRecipe(stack)
        let seedID = try XCTUnwrap(recipe.seedID)

        let editor = RecipeEditorViewModel(context: stack.context, recipe: recipe)
        editor.draft.steps = ["Simmer gently for ten minutes.", "Rest, then serve."]
        editor.draft.title = "Our version"
        _ = editor.save()

        try SeedImporter.reimport(in: stack.context)

        let after = try XCTUnwrap(
            try stack.context.fetch(FetchDescriptor<Recipe>()).first { $0.seedID == seedID }
        )
        XCTAssertEqual(after.title, "Our version")
        XCTAssertEqual(after.steps.count, 2, "The household's steps survive a catalog update.")
    }

    @MainActor
    func testRestoringTheOriginalBringsTheSeedBack() throws {
        let stack = try seededStack()
        let recipe = try firstSeedRecipe(stack)
        let seedID = try XCTUnwrap(recipe.seedID)
        let originalTitle = recipe.title
        let originalSteps = recipe.steps

        let editor = RecipeEditorViewModel(context: stack.context, recipe: recipe)
        editor.draft.title = "Our version"
        editor.draft.steps = ["Do it my way."]
        _ = editor.save()

        try SeedImporter.restoreFromSeed(recipe, in: stack.context)

        XCTAssertEqual(recipe.title, originalTitle)
        XCTAssertEqual(recipe.steps, originalSteps)
        XCTAssertFalse(recipe.isUserEdited)
        XCTAssertEqual(recipe.seedID, seedID)
    }

    @MainActor
    func testAttributionSurvivesAnEdit() throws {
        let stack = try seededStack()
        let recipe = try firstSeedRecipe(stack)
        recipe.sourceNote = "Adapted from Somewhere"
        recipe.sourceURL = "https://example.com/recipe"
        try stack.context.save()

        let editor = RecipeEditorViewModel(context: stack.context, recipe: recipe)
        editor.draft.steps = ["One step."]
        _ = editor.save()

        XCTAssertEqual(recipe.sourceNote, "Adapted from Somewhere")
        XCTAssertEqual(recipe.sourceURL, "https://example.com/recipe")
    }
}
