import SwiftData
import XCTest
@testable import Rasoi

final class InsightsViewModelTests: XCTestCase {
    private struct Harness {
        let stack: TestStack
        let model: InsightsViewModel
        let ira: HouseholdMember
        let aarav: HouseholdMember
    }

    private let today = D.date(2026, 9, 9, hour: 18)

    @MainActor
    private func makeHarness() throws -> Harness {
        let stack = try TestContainer.makeStack()
        let context = stack.context
        try SeedImporter.reimport(in: context)
        let adult = HouseholdMember(name: "Shikher", dateOfBirth: D.adultDOB, role: .adult, sortOrder: 0)
        let aarav = HouseholdMember(name: "Aarav", dateOfBirth: D.olderChildDOB, role: .child, sortOrder: 1)
        let ira = HouseholdMember(name: "Ira", dateOfBirth: D.youngChildDOB, role: .child, sortOrder: 2)
        context.insert(adult)
        context.insert(aarav)
        context.insert(ira)
        try context.save()
        let clock = today
        return Harness(stack: stack, model: InsightsViewModel(context: context, now: { clock }),
                       ira: ira, aarav: aarav)
    }

    /// Cooks `recipe` on `date` and records the given reactions.
    @MainActor
    @discardableResult
    private func cook(_ recipe: Recipe, on date: Date, in harness: Harness,
                      reactions: [(HouseholdMember, MealReaction)] = []) -> MealSlot {
        let context = harness.stack.context
        let plan = MealPlan.plan(forWeekContaining: date, in: context)
        let slot = MealSlot.slot(in: plan, on: date, mealType: .dinner, in: context)
        slot.recipe = recipe
        slot.status = .cooked
        for (member, reaction) in reactions {
            MealFeedback.record(reaction, for: slot, member: member, on: date, in: context)
        }
        try? context.save()
        harness.model.load()
        return slot
    }

    @MainActor
    private func recipes(_ harness: Harness, _ count: Int) throws -> [Recipe] {
        let all = try harness.stack.context.fetch(FetchDescriptor<Recipe>(sortBy: [SortDescriptor(\.title)]))
        return Array(all.filter { $0.serves(.dinner) }.prefix(count))
    }

    @MainActor
    func testAnEmptyHistoryShowsNothing() throws {
        let harness = try makeHarness()
        XCTAssertFalse(harness.model.hasAnything)
        XCTAssertTrue(harness.model.children.isEmpty)
        XCTAssertTrue(harness.model.mostCooked.isEmpty)
    }

    @MainActor
    func testFavouritesAndNotLatelyPerChild() throws {
        let harness = try makeHarness()
        let dishes = try recipes(harness, 2)

        cook(dishes[0], on: D.date(2026, 9, 8), in: harness,
             reactions: [(harness.ira, .ateAll), (harness.aarav, .notToday)])
        cook(dishes[1], on: D.date(2026, 9, 7), in: harness,
             reactions: [(harness.ira, .notToday), (harness.aarav, .ateAll)])

        let ira = try XCTUnwrap(harness.model.children.first { $0.name == "Ira" })
        XCTAssertEqual(ira.favourites.map(\.title), [dishes[0].title])
        XCTAssertEqual(ira.notLately.map(\.title), [dishes[1].title])

        let aarav = try XCTUnwrap(harness.model.children.first { $0.name == "Aarav" })
        XCTAssertEqual(aarav.favourites.map(\.title), [dishes[1].title])
        XCTAssertEqual(aarav.notLately.map(\.title), [dishes[0].title])
    }

    @MainActor
    func testChildrenAreListedInHouseholdOrderAndAdultsAreNot() throws {
        let harness = try makeHarness()
        let dishes = try recipes(harness, 1)
        cook(dishes[0], on: D.date(2026, 9, 8), in: harness,
             reactions: [(harness.ira, .ateAll), (harness.aarav, .ateSome)])

        XCTAssertEqual(harness.model.children.map(\.name), ["Aarav", "Ira"])
    }

    @MainActor
    func testDetailUsesTheSameWarmWordsAsTheFeedbackSheet() throws {
        let harness = try makeHarness()
        let dishes = try recipes(harness, 1)
        cook(dishes[0], on: D.date(2026, 9, 8), in: harness, reactions: [(harness.ira, .ateAll)])
        cook(dishes[0], on: D.date(2026, 9, 5), in: harness, reactions: [(harness.ira, .ateAll)])

        let ira = try XCTUnwrap(harness.model.children.first { $0.name == "Ira" })
        XCTAssertEqual(ira.favourites.first?.detail, "ate it all twice")
        XCTAssertFalse(ira.favourites.first?.detail.contains("fail") == true)
    }

    @MainActor
    func testMostCookedCountsRepeats() throws {
        let harness = try makeHarness()
        let dishes = try recipes(harness, 2)
        cook(dishes[0], on: D.date(2026, 9, 8), in: harness)
        cook(dishes[0], on: D.date(2026, 9, 1), in: harness)
        cook(dishes[1], on: D.date(2026, 9, 5), in: harness)

        XCTAssertEqual(harness.model.mostCooked.first?.title, dishes[0].title)
        XCTAssertEqual(harness.model.mostCooked.first?.times, 2)
        XCTAssertEqual(harness.model.mostCooked.count, 2)
    }

    @MainActor
    func testAnythingOlderThanFourWeeksIsOutOfScope() throws {
        let harness = try makeHarness()
        let dishes = try recipes(harness, 1)
        cook(dishes[0], on: D.date(2026, 6, 1), in: harness, reactions: [(harness.ira, .ateAll)])

        XCTAssertTrue(harness.model.mostCooked.isEmpty)
        XCTAssertEqual(harness.model.cookedCount, 0)
    }

    @MainActor
    func testVarietyAndCookedCounts() throws {
        let harness = try makeHarness()
        let dishes = try recipes(harness, 3)
        for (index, dish) in dishes.enumerated() {
            cook(dish, on: Calendar.rasoi.date(byAdding: .day, value: -index * 2, to: today)!, in: harness)
        }

        XCTAssertEqual(harness.model.distinctRecipeCount, 3)
        XCTAssertGreaterThanOrEqual(harness.model.cuisineCount, 1)
        XCTAssertEqual(harness.model.cookedCount, 3)
        XCTAssertGreaterThanOrEqual(harness.model.plannedCount, 3)
        XCTAssertTrue(harness.model.hasAnything)
    }

    @MainActor
    func testTheWeeklyHintNamesAFoodGroupAndNothingElse() throws {
        let harness = try makeHarness()
        let context = harness.stack.context
        // A week of nothing but one plain grain dish leaves obvious gaps.
        let pasta = try XCTUnwrap(
            try context.fetch(FetchDescriptor<Recipe>()).first { $0.nutritionTags.contains("grain") }
        )
        let plan = MealPlan.plan(forWeekContaining: today, in: context)
        for day in plan.days {
            let slot = MealSlot.slot(in: plan, on: day, mealType: .dinner, in: context)
            slot.recipe = pasta
        }
        try context.save()
        harness.model.load()

        let hint = try XCTUnwrap(harness.model.weeklyHint)
        XCTAssertTrue(hint.hasPrefix("This week is light on"))
        for banned in ["calorie", "weight", "diet", "bmi"] {
            XCTAssertFalse(hint.lowercased().contains(banned), "R2: the hint mentions \(banned)")
        }
    }

    @MainActor
    func testNoHintWhenThereIsNoPlan() throws {
        let harness = try makeHarness()
        XCTAssertNil(harness.model.weeklyHint)
    }

    @MainActor
    func testCopyNeverShowsAScoreOrAStreak() throws {
        let harness = try makeHarness()
        let dishes = try recipes(harness, 1)
        cook(dishes[0], on: D.date(2026, 9, 8), in: harness, reactions: [(harness.ira, .ateSome)])

        let details = harness.model.children.flatMap { $0.favourites + $0.notLately }.map(\.detail)
        for detail in details {
            XCTAssertFalse(detail.contains("%"))
            XCTAssertNil(detail.rangeOfCharacter(from: CharacterSet(charactersIn: "0123456789")),
                         "Counts are spelled out in words, never as a score: \(detail)")
        }
    }
}
