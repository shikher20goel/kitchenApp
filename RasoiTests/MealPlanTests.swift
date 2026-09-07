import SwiftData
import XCTest
@testable import Rasoi

final class MealPlanTests: XCTestCase {

    // MARK: - Week boundaries

    func testWeekStartIsAlwaysTheMondayOnOrBeforeTheDate() {
        // 2026-09-07 is a Monday.
        let monday = D.date(2026, 9, 7)
        for offset in 0...6 {
            let day = Calendar.rasoi.date(byAdding: .day, value: offset, to: monday)!
            XCTAssertEqual(MealPlan.weekStart(containing: day), Calendar.rasoi.startOfDay(for: monday),
                           "Day +\(offset) belongs to the week starting Monday.")
        }
    }

    func testSundayBelongsToTheWeekThatStartedTheMondayBefore() {
        let sunday = D.date(2026, 9, 13)
        XCTAssertEqual(MealPlan.weekStart(containing: sunday),
                       Calendar.rasoi.startOfDay(for: D.date(2026, 9, 7)))
    }

    func testWeekStartIsMidnight() {
        let start = MealPlan.weekStart(containing: D.date(2026, 9, 9, hour: 23, minute: 59))
        XCTAssertEqual(Calendar.rasoi.component(.hour, from: start), 0)
        XCTAssertEqual(Calendar.rasoi.component(.minute, from: start), 0)
    }

    func testDaysOfTheWeekAreSevenConsecutiveDaysFromMonday() {
        let days = MealPlan.days(ofWeekContaining: D.date(2026, 9, 10))
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.first, Calendar.rasoi.startOfDay(for: D.date(2026, 9, 7)))
        XCTAssertEqual(days.last, Calendar.rasoi.startOfDay(for: D.date(2026, 9, 13)))
    }

    // MARK: - Plans and slots

    @MainActor
    func testPlanForWeekIsCreatedOnceAndReused() throws {
        let stack = try TestContainer.makeStack()
        let first = MealPlan.plan(forWeekContaining: D.date(2026, 9, 9), in: stack.context)
        try stack.context.save()
        let second = MealPlan.plan(forWeekContaining: D.date(2026, 9, 12), in: stack.context)
        try stack.context.save()

        XCTAssertEqual(first.weekStart, second.weekStart)
        XCTAssertEqual(try stack.context.fetch(FetchDescriptor<MealPlan>()).count, 1)
    }

    @MainActor
    func testSlotIsUniquePerDateAndMealType() throws {
        let stack = try TestContainer.makeStack()
        let plan = MealPlan.plan(forWeekContaining: D.date(2026, 9, 9), in: stack.context)
        let day = D.date(2026, 9, 9)

        let dinner = MealSlot.slot(in: plan, on: day, mealType: .dinner, in: stack.context)
        dinner.servings = 5
        let again = MealSlot.slot(in: plan, on: day, mealType: .dinner, in: stack.context)
        let lunch = MealSlot.slot(in: plan, on: day, mealType: .lunch, in: stack.context)
        try stack.context.save()

        XCTAssertTrue(dinner === again, "Asking twice returns the same slot.")
        XCTAssertEqual(again.servings, 5)
        XCTAssertEqual(try stack.context.fetch(FetchDescriptor<MealSlot>()).count, 2)
        XCTAssertEqual(lunch.mealType, .lunch)
        XCTAssertEqual(plan.slots.count, 2)
    }

    @MainActor
    func testSlotDefaults() throws {
        let stack = try TestContainer.makeStack()
        let plan = MealPlan.plan(forWeekContaining: D.date(2026, 9, 9), in: stack.context)
        let slot = MealSlot.slot(in: plan, on: D.date(2026, 9, 9), mealType: .dinner, in: stack.context)

        XCTAssertEqual(slot.status, .planned)
        XCTAssertFalse(slot.lockedByUser)
        XCTAssertNil(slot.recipe)
        XCTAssertEqual(slot.reasons, [])
        XCTAssertEqual(slot.date, Calendar.rasoi.startOfDay(for: D.date(2026, 9, 9)),
                       "Slots are keyed by the day, not the time of day.")
    }

    @MainActor
    func testSlotStatusAndReasonsRoundTrip() throws {
        let stack = try TestContainer.makeStack()
        let plan = MealPlan.plan(forWeekContaining: D.date(2026, 9, 9), in: stack.context)
        let slot = MealSlot.slot(in: plan, on: D.date(2026, 9, 9), mealType: .dinner, in: stack.context)
        slot.status = .cooked
        slot.reasons = ["Uses spinach before Thursday", "Both kids liked it last time"]
        try stack.context.save()

        let reloaded = try XCTUnwrap(try stack.context.fetch(FetchDescriptor<MealSlot>()).first)
        XCTAssertEqual(reloaded.status, .cooked)
        XCTAssertEqual(reloaded.reasons.count, 2)
    }

    // MARK: - Feedback

    @MainActor
    func testFeedbackIsUniquePerSlotAndMemberAndUpserts() throws {
        let stack = try TestContainer.makeStack()
        let plan = MealPlan.plan(forWeekContaining: D.date(2026, 9, 9), in: stack.context)
        let slot = MealSlot.slot(in: plan, on: D.date(2026, 9, 9), mealType: .dinner, in: stack.context)
        let child = HouseholdMember(name: "Ira", dateOfBirth: D.youngChildDOB, role: .child)
        stack.context.insert(child)

        MealFeedback.record(.notToday, for: slot, member: child, note: nil,
                            on: D.date(2026, 9, 9, hour: 19), in: stack.context)
        MealFeedback.record(.ateSome, for: slot, member: child, note: "ate the rice",
                            on: D.date(2026, 9, 9, hour: 20), in: stack.context)
        try stack.context.save()

        let feedback = try stack.context.fetch(FetchDescriptor<MealFeedback>())
        XCTAssertEqual(feedback.count, 1, "One reaction per child per meal — the later one wins.")
        XCTAssertEqual(feedback.first?.reaction, .ateSome)
        XCTAssertEqual(feedback.first?.note, "ate the rice")
    }

    @MainActor
    func testFeedbackFromDifferentChildrenAreSeparateRows() throws {
        let stack = try TestContainer.makeStack()
        let plan = MealPlan.plan(forWeekContaining: D.date(2026, 9, 9), in: stack.context)
        let slot = MealSlot.slot(in: plan, on: D.date(2026, 9, 9), mealType: .dinner, in: stack.context)
        let younger = HouseholdMember(name: "Ira", dateOfBirth: D.youngChildDOB, role: .child)
        let older = HouseholdMember(name: "Aarav", dateOfBirth: D.olderChildDOB, role: .child)
        stack.context.insert(younger)
        stack.context.insert(older)

        MealFeedback.record(.ateAll, for: slot, member: younger, on: D.date(2026, 9, 9), in: stack.context)
        MealFeedback.record(.notToday, for: slot, member: older, on: D.date(2026, 9, 9), in: stack.context)
        try stack.context.save()

        XCTAssertEqual(try stack.context.fetch(FetchDescriptor<MealFeedback>()).count, 2)
        XCTAssertEqual(slot.feedback.count, 2)
    }

    func testReactionWeightsMatchTheSpec() {
        XCTAssertEqual(MealReaction.ateAll.weight, 1, accuracy: 0.0001)
        XCTAssertEqual(MealReaction.ateSome.weight, 0.4, accuracy: 0.0001)
        XCTAssertEqual(MealReaction.notToday.weight, -1, accuracy: 0.0001)
    }

    func testReactionCopyNeverShamesAChild() {
        // SPEC R3: a refused meal is "Not today", never "failed" or "refused".
        XCTAssertEqual(MealReaction.ateAll.label, "Ate it all")
        XCTAssertEqual(MealReaction.ateSome.label, "Ate some")
        XCTAssertEqual(MealReaction.notToday.label, "Not today")
    }
}
