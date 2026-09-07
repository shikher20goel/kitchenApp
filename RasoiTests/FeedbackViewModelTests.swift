import SwiftData
import XCTest
@testable import Rasoi

final class FeedbackViewModelTests: XCTestCase {
    private struct Harness {
        let stack: TestStack
        let model: FeedbackViewModel
        let slot: MealSlot
        let ira: HouseholdMember
        let aarav: HouseholdMember
        let adult: HouseholdMember
        let depleter: SpyDepleter
    }

    /// Records that depletion was asked for, without touching the pantry.
    private final class SpyDepleter: FeedbackViewModel.Depleting {
        private(set) var calls = 0
        @MainActor
        func deplete(slot: MealSlot, in context: ModelContext) { calls += 1 }
    }

    @MainActor
    private func makeHarness() throws -> Harness {
        let stack = try TestContainer.makeStack()
        let context = stack.context
        let adult = HouseholdMember(name: "Shikher", dateOfBirth: D.adultDOB, role: .adult, sortOrder: 0)
        let aarav = HouseholdMember(name: "Aarav", dateOfBirth: D.olderChildDOB, role: .child, sortOrder: 1)
        let ira = HouseholdMember(name: "Ira", dateOfBirth: D.youngChildDOB, role: .child, sortOrder: 2)
        context.insert(adult)
        context.insert(aarav)
        context.insert(ira)

        let plan = MealPlan.plan(forWeekContaining: D.date(2026, 9, 9), in: context)
        let slot = MealSlot.slot(in: plan, on: D.date(2026, 9, 9), mealType: .dinner, in: context)
        try context.save()

        let depleter = SpyDepleter()
        let model = FeedbackViewModel(slot: slot, context: context, depleter: depleter,
                                      now: { D.date(2026, 9, 9, hour: 19) })
        return Harness(stack: stack, model: model, slot: slot, ira: ira, aarav: aarav,
                       adult: adult, depleter: depleter)
    }

    @MainActor
    func testEveryActiveMemberIsListedInHouseholdOrder() throws {
        let harness = try makeHarness()
        XCTAssertEqual(harness.model.members.map(\.name), ["Shikher", "Aarav", "Ira"])
    }

    @MainActor
    func testAnUnansweredMemberGetsNoRow() throws {
        let harness = try makeHarness()
        harness.model.select(.ateAll, for: harness.ira)
        harness.model.save()

        let feedback = try harness.stack.context.fetch(FetchDescriptor<MealFeedback>())
        XCTAssertEqual(feedback.count, 1, "Nobody is answered for silently.")
        XCTAssertEqual(feedback.first?.member?.name, "Ira")
    }

    @MainActor
    func testChangingAReactionOverwritesTheSameRow() throws {
        let harness = try makeHarness()
        harness.model.select(.notToday, for: harness.aarav)
        harness.model.save()
        harness.model.select(.ateSome, for: harness.aarav)
        harness.model.save()

        let feedback = try harness.stack.context.fetch(FetchDescriptor<MealFeedback>())
        XCTAssertEqual(feedback.count, 1)
        XCTAssertEqual(feedback.first?.reaction, .ateSome)
    }

    @MainActor
    func testTappingTheSameReactionTwiceClearsIt() throws {
        let harness = try makeHarness()
        harness.model.select(.ateAll, for: harness.ira)
        harness.model.select(.ateAll, for: harness.ira)
        XCTAssertNil(harness.model.reaction(for: harness.ira))
        XCTAssertFalse(harness.model.canSave)
    }

    @MainActor
    func testNotesAreSavedOnlyWhenTheyHaveContent() throws {
        let harness = try makeHarness()
        harness.model.select(.ateSome, for: harness.ira)
        harness.model.notes["Ira"] = "   "
        harness.model.select(.ateAll, for: harness.aarav)
        harness.model.notes["Aarav"] = "asked for seconds"
        harness.model.save()

        let feedback = try harness.stack.context.fetch(FetchDescriptor<MealFeedback>())
        let byName = Dictionary(uniqueKeysWithValues: feedback.map { ($0.member?.name ?? "", $0) })
        XCTAssertNil(byName["Ira"]?.note)
        XCTAssertEqual(byName["Aarav"]?.note, "asked for seconds")
    }

    @MainActor
    func testSavingMarksTheMealCookedAndDepletesThePantryOnce() throws {
        let harness = try makeHarness()
        harness.model.select(.ateAll, for: harness.ira)
        harness.model.save()

        XCTAssertEqual(harness.slot.status, .cooked)
        XCTAssertEqual(harness.depleter.calls, 1)

        harness.model.select(.ateSome, for: harness.aarav)
        harness.model.save()
        XCTAssertEqual(harness.depleter.calls, 1, "A meal is only taken out of the pantry once.")
    }

    @MainActor
    func testReopeningTheSheetShowsWhatWasRecorded() throws {
        let harness = try makeHarness()
        harness.model.select(.notToday, for: harness.ira)
        harness.model.notes["Ira"] = "too spicy"
        harness.model.save()

        let reopened = FeedbackViewModel(slot: harness.slot, context: harness.stack.context,
                                         now: { D.date(2026, 9, 10) })
        XCTAssertEqual(reopened.reaction(for: harness.ira), .notToday)
        XCTAssertEqual(reopened.notes["Ira"], "too spicy")
    }

    @MainActor
    func testInactiveMembersAreNotAsked() throws {
        let harness = try makeHarness()
        harness.adult.isActive = false
        try harness.stack.context.save()

        let model = FeedbackViewModel(slot: harness.slot, context: harness.stack.context)
        XCTAssertEqual(model.members.map(\.name), ["Aarav", "Ira"])
    }
}
