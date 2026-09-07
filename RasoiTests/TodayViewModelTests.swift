import SwiftData
import XCTest
@testable import Rasoi

final class TodayViewModelTests: XCTestCase {
    private struct Harness {
        let stack: TestStack
        let plan: PlanViewModel
        let model: TodayViewModel
    }

    /// A Tuesday, so "today" sits inside the generated week.
    private let today = D.date(2026, 9, 8, hour: 9)

    @MainActor
    private func makeHarness() throws -> Harness {
        let stack = try TestContainer.makeStack()
        let context = stack.context
        try SeedImporter.reimport(in: context)
        StoreSeeder.seedDefaultsIfEmpty(in: context)
        context.insert(HouseholdMember(name: "Shikher", dateOfBirth: D.adultDOB, role: .adult, sortOrder: 0))
        context.insert(HouseholdMember(name: "Ira", dateOfBirth: D.youngChildDOB, role: .child, sortOrder: 1))
        try context.save()

        let clock = today
        let plan = PlanViewModel(context: context, weekContaining: clock, now: { clock })
        let model = TodayViewModel(context: context, now: { clock })
        return Harness(stack: stack, plan: plan, model: model)
    }

    @MainActor
    func testTodayShowsTheDaysMealsOnceTheWeekIsPlanned() throws {
        let harness = try makeHarness()
        XCTAssertFalse(harness.model.hasPlanForToday)

        harness.plan.generateWeek()
        harness.model.load()

        XCTAssertTrue(harness.model.hasPlanForToday)
        XCTAssertEqual(harness.model.slots.count, 4)
        XCTAssertNotNil(harness.model.dinner?.recipe)
        XCTAssertEqual(harness.model.otherMeals.map(\.mealType), [.breakfast, .lunch, .snack])
        XCTAssertTrue(harness.model.slots.allSatisfy {
            Calendar.rasoi.isDate($0.date, inSameDayAs: self.today)
        })
    }

    @MainActor
    func testTheDinnerCardCarriesItsReasons() throws {
        let harness = try makeHarness()
        harness.plan.generateWeek()
        harness.model.load()

        let dinner = try XCTUnwrap(harness.model.dinner)
        XCTAssertFalse(dinner.reasons.isEmpty, "Every meal can say why it is here.")
    }

    @MainActor
    func testExpiringSoonBannerNamesTheItemAndCountsRecipes() throws {
        let harness = try makeHarness()
        let context = harness.stack.context
        let spinach = try XCTUnwrap(Ingredient.named("Spinach", in: context))
        PantryItem.add(spinach, quantity: 200, unit: .gram, location: .fridge,
                       on: D.date(2026, 9, 6), in: context)
        try context.save()
        harness.model.load()

        XCTAssertEqual(harness.model.expiringItems.count, 1)
        let headline = try XCTUnwrap(harness.model.expiringHeadline)
        XCTAssertTrue(headline.localizedCaseInsensitiveContains("spinach"))
        XCTAssertGreaterThan(harness.model.recipeCount(using: harness.model.expiringItems[0]), 0)
    }

    @MainActor
    func testNothingExpiringMeansNoBanner() throws {
        let harness = try makeHarness()
        XCTAssertNil(harness.model.expiringHeadline)
        XCTAssertTrue(harness.model.expiringItems.isEmpty)
    }

    @MainActor
    func testTheSnackStripComesFromThePantry() throws {
        let harness = try makeHarness()
        let context = harness.stack.context
        for name in ["Banana", "Apple", "Plain yogurt"] {
            let ingredient = try XCTUnwrap(Ingredient.named(name, in: context))
            PantryItem.add(ingredient, quantity: 3, unit: ingredient.defaultUnit, location: .fridge,
                           on: today, in: context)
        }
        try context.save()
        harness.model.load()

        XCTAssertEqual(harness.model.snacks.count, 3)
        XCTAssertEqual(harness.model.snacks.map(\.title), ["Banana", "Apple", "Plain yogurt"],
                       "Fruit leads, and the fruit that goes off first leads the fruit.")
    }

    @MainActor
    func testCoverageDotsReflectTheDay() throws {
        let harness = try makeHarness()
        harness.plan.generateWeek()
        harness.model.load()

        XCTAssertFalse(harness.model.coverage.covered.isEmpty)
        XCTAssertEqual(harness.model.coverage.date, Calendar.rasoi.startOfDay(for: today))
    }

    @MainActor
    func testMarkingCookedWithoutFeedbackLeavesThePantryAlone() throws {
        let harness = try makeHarness()
        harness.plan.generateWeek()
        harness.model.load()
        let dinner = try XCTUnwrap(harness.model.dinner)
        let recipe = try XCTUnwrap(dinner.recipe)
        let ingredient = try XCTUnwrap(
            Ingredient.named(recipe.requiredIngredients[0].ingredientName, in: harness.stack.context)
        )
        PantryItem.add(ingredient, quantity: 5000, unit: ingredient.defaultUnit, location: .pantry,
                       on: today, in: harness.stack.context)
        try harness.stack.context.save()

        harness.model.markCooked(dinner)

        XCTAssertEqual(harness.model.dinner?.status, .cooked)
        let stocked = try XCTUnwrap(PantryItem.existing(for: ingredient, location: .pantry,
                                                        in: harness.stack.context))
        XCTAssertEqual(stocked.quantity, 5000, accuracy: 0.0001,
                       "The feedback sheet is what draws the pantry down.")
    }

    @MainActor
    func testMarkingCookedCanDepleteWhenAskedTo() throws {
        let harness = try makeHarness()
        harness.plan.generateWeek()
        harness.model.load()
        let dinner = try XCTUnwrap(harness.model.dinner)
        let recipe = try XCTUnwrap(dinner.recipe)
        let line = recipe.requiredIngredients[0]
        let ingredient = try XCTUnwrap(Ingredient.named(line.ingredientName, in: harness.stack.context))
        PantryItem.add(ingredient, quantity: 5000, unit: line.unit, location: .pantry,
                       on: today, in: harness.stack.context)
        try harness.stack.context.save()

        harness.model.markCooked(dinner, depleting: true)

        let stocked = try XCTUnwrap(PantryItem.existing(for: ingredient, location: .pantry,
                                                        in: harness.stack.context))
        XCTAssertLessThan(stocked.quantity, 5000)
    }
}
