import SwiftData
import XCTest
@testable import Rasoi

final class PlanViewModelTests: XCTestCase {
    private struct Harness {
        let stack: TestStack
        let model: PlanViewModel
        let ira: HouseholdMember
        let aarav: HouseholdMember
    }

    private let monday = D.date(2026, 9, 7)

    @MainActor
    private func makeHarness(today: Date? = nil) throws -> Harness {
        let stack = try TestContainer.makeStack()
        let context = stack.context
        try SeedImporter.reimport(in: context)
        StoreSeeder.seedDefaultsIfEmpty(in: context)

        let adult = HouseholdMember(name: "Shikher", dateOfBirth: D.adultDOB, role: .adult, sortOrder: 0)
        let aarav = HouseholdMember(name: "Aarav", dateOfBirth: D.olderChildDOB, role: .child, sortOrder: 1)
        let ira = HouseholdMember(name: "Ira", dateOfBirth: D.youngChildDOB, role: .child, sortOrder: 2)
        context.insert(adult)
        context.insert(aarav)
        context.insert(ira)
        try context.save()

        let clock = today ?? monday
        let model = PlanViewModel(context: context, weekContaining: monday, now: { clock })
        return Harness(stack: stack, model: model, ira: ira, aarav: aarav)
    }

    @MainActor
    private func dinnerSlots(_ model: PlanViewModel) -> [MealSlot] {
        model.slots.filter { $0.mealType == .dinner }.sorted { $0.date < $1.date }
    }

    // MARK: - Generating

    @MainActor
    func testGenerateCreatesAFullWeek() throws {
        let harness = try makeHarness()
        harness.model.generateWeek()

        XCTAssertEqual(harness.model.slots.count, 28)
        XCTAssertEqual(harness.model.days.count, 7)
        XCTAssertTrue(dinnerSlots(harness.model).allSatisfy { $0.recipe != nil }, "Every dinner is filled.")
        XCTAssertTrue(harness.model.slots.allSatisfy { $0.recipe == nil || !$0.reasons.isEmpty },
                      "Every planned meal explains itself.")
        XCTAssertEqual(harness.model.slots.first?.servings, 3, "Servings default to who is at the table.")
    }

    @MainActor
    func testGeneratingTwiceDoesNotDuplicateSlots() throws {
        let harness = try makeHarness()
        harness.model.generateWeek()
        harness.model.generateWeek()

        XCTAssertEqual(try harness.stack.context.fetch(FetchDescriptor<MealSlot>()).count, 28)
        XCTAssertEqual(try harness.stack.context.fetch(FetchDescriptor<MealPlan>()).count, 1)
    }

    @MainActor
    func testRegeneratePreservesLockedSlots() throws {
        let harness = try makeHarness()
        harness.model.generateWeek()

        let wednesday = try XCTUnwrap(dinnerSlots(harness.model).dropFirst(2).first)
        let pinned = try XCTUnwrap(wednesday.recipe)
        harness.model.toggleLock(wednesday)

        harness.model.regenerateUnlockedSlots()

        let after = try XCTUnwrap(harness.model.slot(on: wednesday.date, mealType: .dinner))
        XCTAssertTrue(after.lockedByUser)
        XCTAssertEqual(after.recipe?.persistentModelID, pinned.persistentModelID,
                       "A pinned meal survives a regenerate.")
    }

    @MainActor
    func testACookedMealIsNeverOverwritten() throws {
        let harness = try makeHarness()
        harness.model.generateWeek()
        let monday = try XCTUnwrap(dinnerSlots(harness.model).first)
        let cooked = try XCTUnwrap(monday.recipe)
        harness.model.setStatus(.cooked, for: monday)

        harness.model.generateWeek()
        let after = try XCTUnwrap(harness.model.slot(on: monday.date, mealType: .dinner))
        XCTAssertEqual(after.recipe?.persistentModelID, cooked.persistentModelID)
        XCTAssertEqual(after.status, .cooked)
    }

    // MARK: - Swapping

    @MainActor
    func testAlternativesAreRankedAndExplained() throws {
        let harness = try makeHarness()
        harness.model.generateWeek()
        let slot = try XCTUnwrap(dinnerSlots(harness.model).first)

        let alternatives = harness.model.alternatives(for: slot)
        XCTAssertGreaterThanOrEqual(alternatives.count, 3)
        XCTAssertTrue(alternatives.allSatisfy { !$0.reasons.isEmpty })
        XCTAssertEqual(Set(alternatives.map(\.recipe.title)).count, alternatives.count, "No duplicates.")
        XCTAssertTrue(alternatives.allSatisfy { $0.recipe.serves(.dinner) })
    }

    @MainActor
    func testSwapReplacesTheRecipeAndSaysWhy() throws {
        let harness = try makeHarness()
        harness.model.generateWeek()
        let slot = try XCTUnwrap(dinnerSlots(harness.model).first)
        let alternative = try XCTUnwrap(harness.model.alternatives(for: slot).first { $0.recipe !== slot.recipe })

        harness.model.swap(slot, to: alternative.recipe, reasons: alternative.reasons)

        let after = try XCTUnwrap(harness.model.slot(on: slot.date, mealType: .dinner))
        XCTAssertEqual(after.recipe?.title, alternative.recipe.title)
        XCTAssertFalse(after.reasons.isEmpty)
    }

    @MainActor
    func testSwappingWithoutReasonsSaysTheHouseholdChose() throws {
        let harness = try makeHarness()
        harness.model.generateWeek()
        let slot = try XCTUnwrap(dinnerSlots(harness.model).first)
        let other = try XCTUnwrap(harness.model.alternatives(for: slot).last?.recipe)

        harness.model.swap(slot, to: other)
        XCTAssertEqual(harness.model.slot(on: slot.date, mealType: .dinner)?.reasons, ["You chose this"])
    }

    // MARK: - Statuses

    @MainActor
    func testSkipAndEatingOutStickThroughARegenerate() throws {
        let harness = try makeHarness()
        harness.model.generateWeek()
        let slots = dinnerSlots(harness.model)
        let skipped = try XCTUnwrap(slots.dropFirst(3).first)
        let eatingOut = try XCTUnwrap(slots.dropFirst(4).first)

        harness.model.setStatus(.skipped, for: skipped)
        harness.model.setStatus(.eatingOut, for: eatingOut)
        harness.model.regenerateUnlockedSlots()

        XCTAssertEqual(harness.model.slot(on: skipped.date, mealType: .dinner)?.status, .skipped)
        XCTAssertEqual(harness.model.slot(on: eatingOut.date, mealType: .dinner)?.status, .eatingOut)
    }

    @MainActor
    func testClearingASlotEmptiesIt() throws {
        let harness = try makeHarness()
        harness.model.generateWeek()
        let slot = try XCTUnwrap(dinnerSlots(harness.model).first)

        harness.model.clear(slot)
        let after = try XCTUnwrap(harness.model.slot(on: slot.date, mealType: .dinner))
        XCTAssertNil(after.recipe)
        XCTAssertTrue(after.reasons.isEmpty)
    }

    // MARK: - Learning from feedback

    @MainActor
    func testARefusedDinnerDropsOutOfNextWeeksPlan() throws {
        let harness = try makeHarness()
        harness.model.generateWeek()

        // Both children turn the same dinner down, three weeks running.
        let slot = try XCTUnwrap(dinnerSlots(harness.model).first)
        let refused = try XCTUnwrap(slot.recipe)
        let refusedID = RecipeSummary(recipe: refused).id
        let context = harness.stack.context

        for week in 0..<3 {
            let day = Calendar.rasoi.date(byAdding: .day, value: -7 * (week + 1), to: monday)!
            let plan = MealPlan.plan(forWeekContaining: day, in: context)
            let past = MealSlot.slot(in: plan, on: day, mealType: .dinner, in: context)
            past.recipe = refused
            past.status = .cooked
            MealFeedback.record(.notToday, for: past, member: harness.ira, on: day, in: context)
            MealFeedback.record(.notToday, for: past, member: harness.aarav, on: day, in: context)
        }
        try context.save()

        let nextWeek = Calendar.rasoi.date(byAdding: .day, value: 7, to: monday)!
        let clock = monday
        let planner = PlanViewModel(context: context, weekContaining: nextWeek, now: { clock })
        planner.generateWeek()

        let plannedIDs = planner.slots.compactMap { $0.recipe }.map { RecipeSummary(recipe: $0).id }
        XCTAssertFalse(plannedIDs.contains(refusedID),
                       "A dish both children turned down three times is rested, not repeated.")
    }

    @MainActor
    func testWeekNavigation() throws {
        let harness = try makeHarness()
        let start = harness.model.weekStart
        harness.model.showNextWeek()
        XCTAssertEqual(harness.model.weekStart, Calendar.rasoi.date(byAdding: .day, value: 7, to: start))
        harness.model.showPreviousWeek()
        XCTAssertEqual(harness.model.weekStart, start)
    }

    @MainActor
    func testSummaryCountsWhatIsOnTheTable() throws {
        let harness = try makeHarness()
        XCTAssertFalse(harness.model.hasPlan)
        harness.model.generateWeek()

        let summary = harness.model.summary
        XCTAssertTrue(harness.model.hasPlan)
        XCTAssertEqual(summary.totalSlots, 28)
        XCTAssertGreaterThan(summary.plannedMeals, 20)
        XCTAssertLessThanOrEqual(summary.newRecipes, summary.plannedMeals)
    }

    @MainActor
    func testPantryContentsSteerThePlan() throws {
        let harness = try makeHarness()
        let context = harness.stack.context
        // Stock everything one weeknight dinner needs. Pick it from the planner's own eligible
        // list so the test is not defeated by a recipe the household could not cook anyway.
        let eligible = harness.model.makePlannerInput().recipes
            .filter { $0.serves(.dinner) && $0.totalMinutes <= 35 }
            .sorted { $0.id < $1.id }
        let summary = try XCTUnwrap(eligible.first)
        let recipe = try XCTUnwrap(harness.model.recipesByPlannerID[summary.id])
        for line in recipe.requiredIngredients {
            guard let ingredient = Ingredient.named(line.ingredientName, in: context) else { continue }
            PantryItem.add(ingredient, quantity: line.quantity * 4, unit: line.unit,
                           location: .pantry, on: monday, in: context)
        }
        try context.save()

        harness.model.generateWeek()
        let planned = harness.model.slots.first { $0.recipe?.persistentModelID == recipe.persistentModelID }
        let slot = try XCTUnwrap(planned, "A dinner the pantry fully covers should be on the week's plan.")
        XCTAssertTrue(slot.reasons.contains { $0.localizedCaseInsensitiveContains("pantry") },
                      "…and it should say so, got \(slot.reasons)")
    }
}

/// SPEC §11: a full week has to appear in well under a second, from the real catalog.
final class MealPlannerPerformanceTests: XCTestCase {
    @MainActor
    func testGeneratingAWeekFromTheRealCatalogIsFast() throws {
        let stack = try TestContainer.makeStack()
        let context = stack.context
        try SeedImporter.reimport(in: context)
        context.insert(HouseholdMember(name: "Shikher", dateOfBirth: D.adultDOB, role: .adult, sortOrder: 0))
        context.insert(HouseholdMember(name: "Aarav", dateOfBirth: D.olderChildDOB, role: .child, sortOrder: 1))
        context.insert(HouseholdMember(name: "Ira", dateOfBirth: D.youngChildDOB, role: .child, sortOrder: 2))
        try context.save()

        let monday = D.date(2026, 9, 7)
        let model = PlanViewModel(context: context, weekContaining: monday, now: { monday })

        // Warm the caches the way opening the tab does, then time the generation itself.
        model.load()
        let started = Date()
        model.generateWeek()
        let elapsed = Date().timeIntervalSince(started)

        XCTAssertLessThan(elapsed, 1.0, "A week took \(elapsed)s to plan; SPEC §11 allows one second.")
        XCTAssertEqual(model.slots.count, 28)
        XCTAssertTrue(model.slots.filter { $0.mealType == .dinner }.allSatisfy { $0.recipe != nil })
    }

    @MainActor
    func testEverySlotCanExplainItself() throws {
        let stack = try TestContainer.makeStack()
        let context = stack.context
        try SeedImporter.reimport(in: context)
        context.insert(HouseholdMember(name: "Ira", dateOfBirth: D.youngChildDOB, role: .child))
        try context.save()

        let monday = D.date(2026, 9, 7)
        let model = PlanViewModel(context: context, weekContaining: monday, now: { monday })
        model.generateWeek()

        for slot in model.slots where slot.recipe != nil {
            XCTAssertFalse(slot.reasons.isEmpty,
                           "\(slot.mealType.label) on \(slot.date) has no reason (SPEC R5)")
        }
    }
}
