import SwiftData
import XCTest
@testable import Rasoi

final class ExporterTests: XCTestCase {
    private let today = D.date(2026, 9, 9, hour: 12)

    @MainActor
    private func makeStack() throws -> TestStack {
        let stack = try TestContainer.makeStack()
        let context = stack.context
        try SeedImporter.reimport(in: context)
        StoreSeeder.seedDefaultsIfEmpty(in: context)

        let adult = HouseholdMember(name: "Shikher", dateOfBirth: D.adultDOB, role: .adult, sortOrder: 0)
        let ira = HouseholdMember(name: "Ira", dateOfBirth: D.youngChildDOB, role: .child, sortOrder: 1)
        ira.likes = ["dosa"]
        context.insert(adult)
        context.insert(ira)

        let profile = DietProfile.current(in: context)
        profile.excludedIngredients = ["Mushroom"]

        let spinach = try XCTUnwrap(Ingredient.named("Spinach", in: context))
        PantryItem.add(spinach, quantity: 200, unit: .gram, location: .fridge, on: today, in: context)

        let recipe = try XCTUnwrap(try context.fetch(FetchDescriptor<Recipe>()).first { $0.serves(.dinner) })
        recipe.isFavorite = true

        let mine = Recipe(title: "Ira's pancakes", cuisine: "American", mealTypes: [.breakfast],
                          appliances: [.stovetop], prepMinutes: 5, cookMinutes: 10, servings: 4,
                          minAgeYears: 1,
                          ingredients: [RecipeIngredient(ingredientName: "Milk", quantity: 200, unit: .millilitre)],
                          steps: ["Mix", "Cook"], source: .user)
        context.insert(mine)

        let plan = MealPlan.plan(forWeekContaining: today, in: context)
        let slot = MealSlot.slot(in: plan, on: today, mealType: .dinner, in: context)
        slot.recipe = recipe
        slot.status = .cooked
        MealFeedback.record(.ateAll, for: slot, member: ira, note: "seconds", on: today, in: context)

        let list = GroceryList.list(forWeekContaining: today, in: context)
        let item = GroceryItem(list: list, ingredient: spinach, quantity: 300, unit: .gram,
                               neededFor: [recipe.title])
        context.insert(item)
        list.items.append(item)

        try context.save()
        return stack
    }

    @MainActor
    func testTheExportCoversEveryKindOfHouseholdData() throws {
        let stack = try makeStack()
        let export = try Exporter.makeExport(in: stack.context, on: today)

        XCTAssertEqual(export.formatVersion, Exporter.formatVersion)
        XCTAssertEqual(export.exportedAt, today)
        XCTAssertEqual(export.household.map(\.name), ["Shikher", "Ira"])
        XCTAssertEqual(export.household.last?.likes, ["dosa"])
        XCTAssertEqual(export.diet.excludedIngredients, ["Mushroom"])
        XCTAssertEqual(export.stores.count, 6)
        XCTAssertEqual(export.pantry.map(\.ingredient), ["Spinach"])
        XCTAssertEqual(export.userRecipes.map(\.title), ["Ira's pancakes"])
        XCTAssertTrue(export.editedSeedRecipes.isEmpty, "Nothing has been edited yet.")
        XCTAssertEqual(export.recipeFlags.count, 1)
        XCTAssertEqual(export.plans.count, 1)
        XCTAssertEqual(export.feedback.map(\.member), ["Ira"])
        XCTAssertEqual(export.feedback.first?.note, "seconds")
        XCTAssertEqual(export.groceryLists.first?.items.map(\.ingredient), ["Spinach"])
    }

    @MainActor
    func testTheSeededCatalogIsNotCopiedIntoTheExport() throws {
        let stack = try makeStack()
        let export = try Exporter.makeExport(in: stack.context, on: today)

        XCTAssertEqual(export.userRecipes.count, 1, "Only what the household wrote.")
        XCTAssertTrue(export.recipeFlags.allSatisfy { $0.isFavorite || $0.isHidden },
                      "Only the seeded recipes the household marked.")
    }

    @MainActor
    func testASeededRecipeTheHouseholdRewroteIsExported() throws {
        let stack = try makeStack()
        let context = stack.context
        let recipe = try XCTUnwrap(try context.fetch(FetchDescriptor<Recipe>()).first { $0.seedID != nil })
        let editor = RecipeEditorViewModel(context: context, recipe: recipe)
        editor.draft.steps = ["My own first step.", "My own second step."]
        _ = editor.save()

        let export = try Exporter.makeExport(in: context, on: today)
        let edited = try XCTUnwrap(export.editedSeedRecipes.first)
        XCTAssertEqual(edited.seedID, recipe.seedID)
        XCTAssertEqual(edited.steps.count, 2)
    }

    @MainActor
    func testTheJsonRoundTrips() throws {
        let stack = try makeStack()
        let data = try Exporter.jsonData(in: stack.context, on: today)
        let decoded = try Exporter.decoder().decode(RasoiExport.self, from: data)

        XCTAssertEqual(decoded, try Exporter.makeExport(in: stack.context, on: today))
        XCTAssertEqual(decoded.household.count, 2)
        XCTAssertEqual(decoded.plans.first?.slots.count, 1)
    }

    @MainActor
    func testTheJsonIsReadableAndStable() throws {
        let stack = try makeStack()
        let first = try Exporter.jsonData(in: stack.context, on: today)
        let second = try Exporter.jsonData(in: stack.context, on: today)
        XCTAssertEqual(first, second, "The same household exports byte-identically.")

        let text = try XCTUnwrap(String(data: first, encoding: .utf8))
        XCTAssertTrue(text.contains("\"formatVersion\" : 1"))
        XCTAssertTrue(text.contains("Ira"))
    }

    @MainActor
    func testAnEmptyHouseholdStillExports() throws {
        let stack = try TestContainer.makeStack()
        let export = try Exporter.makeExport(in: stack.context, on: today)
        XCTAssertTrue(export.household.isEmpty)
        XCTAssertTrue(export.pantry.isEmpty)
        XCTAssertEqual(export.diet.zipCode, "07302", "Defaults come through.")
    }

    @MainActor
    func testTheTemporaryFileIsWritten() throws {
        let stack = try makeStack()
        let url = try Exporter.writeTemporaryFile(in: stack.context, on: today)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(url.pathExtension, "json")
        XCTAssertTrue(url.lastPathComponent.contains("2026-09-09"))
        let decoded = try Exporter.decoder().decode(RasoiExport.self, from: try Data(contentsOf: url))
        XCTAssertEqual(decoded.household.count, 2)
    }
}
