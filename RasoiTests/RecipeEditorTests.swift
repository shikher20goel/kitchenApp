import SwiftData
import XCTest
@testable import Rasoi

final class RecipeEditorTests: XCTestCase {
    private struct Harness {
        let stack: TestStack
        let model: RecipeEditorViewModel
    }

    @MainActor
    private func makeHarness(editing recipe: Recipe? = nil) throws -> Harness {
        let stack = try TestContainer.makeStack()
        try SeedImporter.reimport(in: stack.context)
        return Harness(stack: stack, model: RecipeEditorViewModel(context: stack.context, recipe: recipe))
    }

    private func line(_ name: String, _ quantity: Double = 100, unit: MeasurementUnit = .gram, optional: Bool = false) -> RecipeIngredient {
        RecipeIngredient(ingredientName: name, quantity: quantity, unit: unit, isOptional: optional)
    }

    // MARK: - Validation

    func testAnEmptyDraftListsEverythingItNeeds() {
        let draft = RecipeDraft()
        XCTAssertFalse(draft.isValid)
        XCTAssertEqual(draft.validationErrors, [
            "Give the recipe a name.",
            "Add at least one ingredient with a quantity.",
            "Add at least one step.",
        ])
    }

    func testADraftIsValidWithATitleAnIngredientAndAStep() {
        var draft = RecipeDraft()
        draft.title = "  Ira's khichdi  "
        draft.ingredients = [line("Moong dal", 200)]
        draft.steps = ["Rinse and pressure cook."]
        XCTAssertTrue(draft.isValid)
        XCTAssertEqual(draft.trimmedTitle, "Ira's khichdi")
    }

    func testBlankStepsAndZeroQuantityIngredientsDoNotCount() {
        var draft = RecipeDraft()
        draft.title = "Test"
        draft.ingredients = [line("Moong dal", 0), line("   ", 100)]
        draft.steps = ["   ", ""]
        XCTAssertFalse(draft.isValid)
        XCTAssertTrue(draft.validationErrors.contains("Add at least one ingredient with a quantity."))
        XCTAssertTrue(draft.validationErrors.contains("Add at least one step."))
    }

    func testAMealTypeIsRequired() {
        var draft = RecipeDraft()
        draft.title = "Test"
        draft.ingredients = [line("Moong dal", 200)]
        draft.steps = ["Cook"]
        draft.mealTypes = []
        XCTAssertEqual(draft.validationErrors, ["Choose at least one meal."])
    }

    // MARK: - Derived flags

    @MainActor
    func testFlagsAreDerivedFromTheIngredientCatalog() throws {
        let harness = try makeHarness()
        var draft = RecipeDraft()
        draft.ingredients = [line("Paneer", 200), line("Whole wheat pasta", 300), line("Cashews", 40)]

        let flags = draft.derivedFlags(using: harness.model.index)
        XCTAssertTrue(flags.containsDairy)
        XCTAssertTrue(flags.containsGluten)
        XCTAssertTrue(flags.containsNuts)
        XCTAssertFalse(flags.containsEgg)
        XCTAssertTrue(flags.nutritionTags.contains("protein"))
    }

    @MainActor
    func testAnOptionalIngredientDoesNotSetAFlag() throws {
        let harness = try makeHarness()
        var draft = RecipeDraft()
        draft.ingredients = [line("Moong dal", 200), line("Plain yogurt", 150, optional: true)]

        let flags = draft.derivedFlags(using: harness.model.index)
        XCTAssertFalse(flags.containsDairy, "A dollop of yogurt on the side can simply be left off.")
    }

    @MainActor
    func testUnknownIngredientsSetNoFlags() throws {
        let harness = try makeHarness()
        var draft = RecipeDraft()
        draft.ingredients = [line("Grandma's masala", 10)]
        XCTAssertEqual(draft.derivedFlags(using: harness.model.index), RecipeDraft.DerivedFlags())
    }

    // MARK: - Saving

    @MainActor
    func testSavingWritesAUserRecipeWithDerivedFlags() throws {
        let harness = try makeHarness()
        harness.model.draft.title = "Weeknight paneer bhurji"
        harness.model.draft.mealTypes = [.dinner, .lunch]
        harness.model.draft.appliances = [.stovetop]
        harness.model.draft.ingredients = [line("paneer", 300), line("Tomato", 2, unit: .count)]
        harness.model.draft.steps = ["Crumble the paneer.", "Cook with tomato and spices."]

        let saved = try XCTUnwrap(harness.model.save())
        XCTAssertEqual(saved.source, .user)
        XCTAssertNil(saved.seedID)
        XCTAssertTrue(saved.containsDairy, "Flags come from the ingredients, not from the form.")
        XCTAssertEqual(saved.ingredients.first?.ingredientName, "Paneer",
                       "Ingredient names are stored the way the catalog spells them.")
        XCTAssertEqual(saved.mealTypes, [.lunch, .dinner], "Meals are stored in the order they happen.")
        XCTAssertEqual(try harness.stack.context.fetch(FetchDescriptor<Recipe>()).filter { $0.source == .user }.count, 1)
    }

    @MainActor
    func testSavingAnInvalidDraftChangesNothing() throws {
        let harness = try makeHarness()
        let before = try harness.stack.context.fetch(FetchDescriptor<Recipe>()).count
        harness.model.draft.title = "No ingredients"

        XCTAssertNil(harness.model.save())
        XCTAssertEqual(try harness.stack.context.fetch(FetchDescriptor<Recipe>()).count, before)
    }

    @MainActor
    func testEditingAnExistingRecipeUpdatesItInPlace() throws {
        let stack = try TestContainer.makeStack()
        try SeedImporter.reimport(in: stack.context)
        let mine = Recipe(
            title: "Old name", cuisine: "American", mealTypes: [.dinner], appliances: [.stovetop],
            prepMinutes: 5, cookMinutes: 5, servings: 2, minAgeYears: 1,
            ingredients: [RecipeIngredient(ingredientName: "Milk", quantity: 100, unit: .millilitre)],
            steps: ["Warm"], source: .user
        )
        stack.context.insert(mine)
        try stack.context.save()
        let before = try stack.context.fetch(FetchDescriptor<Recipe>()).count

        let model = RecipeEditorViewModel(context: stack.context, recipe: mine)
        XCTAssertTrue(model.isEditing)
        XCTAssertEqual(model.draft.title, "Old name")
        model.draft.title = "New name"
        model.draft.servings = 6
        let saved = try XCTUnwrap(model.save())

        XCTAssertTrue(saved === mine)
        XCTAssertEqual(mine.title, "New name")
        XCTAssertEqual(mine.servings, 6)
        XCTAssertEqual(try stack.context.fetch(FetchDescriptor<Recipe>()).count, before, "No duplicate row.")
    }

    @MainActor
    func testIngredientSuggestionsComeFromTheCatalog() throws {
        let harness = try makeHarness()
        XCTAssertTrue(harness.model.ingredientSuggestions(for: "p").isEmpty)
        XCTAssertTrue(harness.model.ingredientSuggestions(for: "toor").contains { $0.name == "Toor dal" })
        XCTAssertTrue(harness.model.cuisines.contains("Indian"))
    }
}
