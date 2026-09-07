import SwiftData
import XCTest
@testable import Rasoi

final class PantryDepletionTests: XCTestCase {
    private func line(_ name: String, _ quantity: Double, _ unit: MeasurementUnit, optional: Bool = false) -> RecipeIngredient {
        RecipeIngredient(ingredientName: name, quantity: quantity, unit: unit, isOptional: optional)
    }

    // MARK: - Requirements (pure)

    func testRequirementsScaleWithServings() {
        let needed = PantryDepletion.requirements(
            for: [line("Toor dal", 200, .gram), line("Onion", 2, .count)],
            recipeServings: 4,
            cookedServings: 6
        )
        XCTAssertEqual(needed[Ingredient.fold("Toor dal")]?.amount ?? 0, 300, accuracy: 0.0001)
        XCTAssertEqual(needed[Ingredient.fold("Onion")]?.amount ?? 0, 3, accuracy: 0.0001)
    }

    func testOptionalIngredientsAreNotTakenOut() {
        let needed = PantryDepletion.requirements(
            for: [line("Toor dal", 200, .gram), line("Plain yogurt", 150, .gram, optional: true)],
            recipeServings: 4,
            cookedServings: 4
        )
        XCTAssertNil(needed[Ingredient.fold("Plain yogurt")],
                     "It may or may not have gone in — guessing would corrupt the pantry.")
    }

    func testTheSameIngredientTwiceInARecipeIsSummed() {
        let needed = PantryDepletion.requirements(
            for: [line("Milk", 200, .millilitre), line("Milk", 0.5, .litre)],
            recipeServings: 4,
            cookedServings: 4
        )
        XCTAssertEqual(needed[Ingredient.fold("Milk")]?.amount ?? 0, 700, accuracy: 0.0001)
    }

    // MARK: - Applying to the pantry

    @MainActor
    private func makeStack() throws -> TestStack {
        let stack = try TestContainer.makeStack()
        try SeedImporter.reimport(in: stack.context)
        return stack
    }

    @MainActor
    private func stock(_ stack: TestStack, _ name: String, _ quantity: Double, _ unit: MeasurementUnit,
                       location: PantryLocation = .pantry, on date: Date = D.date(2026, 9, 1)) throws -> PantryItem {
        let ingredient = try XCTUnwrap(Ingredient.named(name, in: stack.context))
        return PantryItem.add(ingredient, quantity: quantity, unit: unit, location: location,
                              on: date, in: stack.context)
    }

    @MainActor
    private func quantity(_ stack: TestStack, _ name: String) throws -> Double? {
        try stack.context.fetch(FetchDescriptor<PantryItem>())
            .first { $0.ingredient?.name == name }?
            .quantity
    }

    @MainActor
    func testPartialUseLeavesTheRest() throws {
        let stack = try makeStack()
        _ = try stock(stack, "Toor dal", 1000, .gram)
        try stack.context.save()

        PantryDepletion.apply([line("Toor dal", 200, .gram)], recipeServings: 4, cookedServings: 4,
                              in: stack.context)
        XCTAssertEqual(try quantity(stack, "Toor dal") ?? 0, 800, accuracy: 0.0001)
    }

    @MainActor
    func testExactUseEmptiesTheRowAndKeepsAStaple() throws {
        let stack = try makeStack()
        _ = try stock(stack, "Toor dal", 200, .gram)
        try stack.context.save()
        XCTAssertTrue(try XCTUnwrap(Ingredient.named("Toor dal", in: stack.context)).isStaple)

        PantryDepletion.apply([line("Toor dal", 200, .gram)], recipeServings: 4, cookedServings: 4,
                              in: stack.context)
        XCTAssertEqual(try quantity(stack, "Toor dal") ?? -1, 0, accuracy: 0.0001,
                       "A staple stays on the list at zero.")
    }

    @MainActor
    func testANonStapleThatRunsOutLeavesThePantry() throws {
        let stack = try makeStack()
        _ = try stock(stack, "Broccoli", 300, .gram, location: .fridge)
        try stack.context.save()

        PantryDepletion.apply([line("Broccoli", 300, .gram)], recipeServings: 4, cookedServings: 4,
                              in: stack.context)
        XCTAssertNil(try quantity(stack, "Broccoli"))
    }

    @MainActor
    func testUsingMoreThanThereIsNeverGoesNegative() throws {
        let stack = try makeStack()
        _ = try stock(stack, "Toor dal", 100, .gram)
        try stack.context.save()

        PantryDepletion.apply([line("Toor dal", 500, .gram)], recipeServings: 4, cookedServings: 4,
                              in: stack.context)
        XCTAssertEqual(try quantity(stack, "Toor dal") ?? -1, 0, accuracy: 0.0001)
    }

    @MainActor
    func testDifferentUnitsAreConvertedBeforeSubtracting() throws {
        let stack = try makeStack()
        _ = try stock(stack, "Basmati rice", 2, .kilogram)
        try stack.context.save()

        PantryDepletion.apply([line("Basmati rice", 500, .gram)], recipeServings: 4, cookedServings: 4,
                              in: stack.context)
        XCTAssertEqual(try quantity(stack, "Basmati rice") ?? 0, 1.5, accuracy: 0.0001)
    }

    @MainActor
    func testStockIsDrawnFromWhateverExpiresFirst() throws {
        let stack = try makeStack()
        let spinach = try XCTUnwrap(Ingredient.named("Spinach", in: stack.context))
        let older = PantryItem.add(spinach, quantity: 100, unit: .gram, location: .fridge,
                                   on: D.date(2026, 9, 1), in: stack.context)
        let newer = PantryItem.add(spinach, quantity: 400, unit: .gram, location: .freezer,
                                   on: D.date(2026, 9, 1), in: stack.context)
        try stack.context.save()
        XCTAssertLessThan(try XCTUnwrap(older.expiresAt), try XCTUnwrap(newer.expiresAt))

        PantryDepletion.apply([line("Spinach", 150, .gram)], recipeServings: 4, cookedServings: 4,
                              in: stack.context)

        XCTAssertEqual(older.quantity, 0, accuracy: 0.0001, "The fridge bag went first.")
        XCTAssertEqual(newer.quantity, 350, accuracy: 0.0001, "The freezer bag only covers the shortfall.")
        let remaining = try stack.context.fetch(FetchDescriptor<PantryItem>())
            .filter { $0.ingredient?.name == "Spinach" }
        XCTAssertEqual(remaining.count, 2, "Spinach is a weekly staple, so the empty row stays at zero.")
    }

    @MainActor
    func testCookingASlotDepletesThroughTheService() throws {
        let stack = try makeStack()
        _ = try stock(stack, "Toor dal", 1000, .gram)
        let recipe = try XCTUnwrap(
            try stack.context.fetch(FetchDescriptor<Recipe>()).first { $0.uses(ingredientNamed: "Toor dal") }
        )
        let plan = MealPlan.plan(forWeekContaining: D.date(2026, 9, 9), in: stack.context)
        let slot = MealSlot.slot(in: plan, on: D.date(2026, 9, 9), mealType: .dinner, in: stack.context)
        slot.recipe = recipe
        slot.servings = recipe.servings
        try stack.context.save()

        PantryDepletionService().deplete(slot: slot, in: stack.context)

        let used = recipe.ingredients.first { Ingredient.fold($0.ingredientName) == Ingredient.fold("Toor dal") }
        XCTAssertEqual(try quantity(stack, "Toor dal") ?? 0,
                       1000 - (used?.quantity ?? 0), accuracy: 0.0001)
    }

    @MainActor
    func testASlotWithNoRecipeChangesNothing() throws {
        let stack = try makeStack()
        _ = try stock(stack, "Toor dal", 500, .gram)
        let plan = MealPlan.plan(forWeekContaining: D.date(2026, 9, 9), in: stack.context)
        let slot = MealSlot.slot(in: plan, on: D.date(2026, 9, 9), mealType: .dinner, in: stack.context)
        try stack.context.save()

        PantryDepletion.apply(slot: slot, in: stack.context)
        XCTAssertEqual(try quantity(stack, "Toor dal") ?? 0, 500, accuracy: 0.0001)
    }
}
