import SwiftData
import XCTest
@testable import Rasoi

final class FamilyViewModelTests: XCTestCase {
    @MainActor
    func testAddMembersKeepsThemInInsertionOrder() throws {
        let stack = try TestContainer.makeStack()
        let viewModel = FamilyViewModel(context: stack.context)

        viewModel.addMember(name: "Shikher", dateOfBirth: D.adultDOB, role: .adult)
        viewModel.addMember(name: "Ira", dateOfBirth: D.youngChildDOB, role: .child)
        viewModel.addMember(name: "Aarav", dateOfBirth: D.olderChildDOB, role: .child)

        XCTAssertEqual(viewModel.members.map(\.name), ["Shikher", "Ira", "Aarav"])
        XCTAssertEqual(viewModel.members.map(\.sortOrder), [0, 1, 2])
        XCTAssertEqual(viewModel.children.map(\.name), ["Ira", "Aarav"])
        XCTAssertEqual(viewModel.adults.map(\.name), ["Shikher"])
    }

    @MainActor
    func testAddMemberTrimsNameAndPicksADefaultAvatar() throws {
        let stack = try TestContainer.makeStack()
        let viewModel = FamilyViewModel(context: stack.context)
        let child = viewModel.addMember(name: "  Ira  ", dateOfBirth: D.youngChildDOB, role: .child)

        XCTAssertEqual(child.name, "Ira")
        XCTAssertEqual(child.avatarSymbol, "figure.child.circle")
        XCTAssertFalse(child.colorHex.isEmpty)
    }

    @MainActor
    func testEditMemberUpdatesOnlyWhatWasGiven() throws {
        let stack = try TestContainer.makeStack()
        let viewModel = FamilyViewModel(context: stack.context)
        let child = viewModel.addMember(name: "Ira", dateOfBirth: D.youngChildDOB, role: .child)

        viewModel.update(child, likes: ["dosa", "paneer"])
        XCTAssertEqual(child.name, "Ira")
        XCTAssertEqual(child.likes, ["dosa", "paneer"])

        viewModel.update(child, name: "Ira G", dislikes: ["bitter gourd"])
        XCTAssertEqual(child.name, "Ira G")
        XCTAssertEqual(child.likes, ["dosa", "paneer"], "Likes are untouched by a name edit.")
        XCTAssertEqual(child.dislikes, ["bitter gourd"])
    }

    @MainActor
    func testReorderRenumbersEveryone() throws {
        let stack = try TestContainer.makeStack()
        let viewModel = FamilyViewModel(context: stack.context)
        viewModel.addMember(name: "A", dateOfBirth: D.adultDOB, role: .adult)
        viewModel.addMember(name: "B", dateOfBirth: D.adultDOB, role: .adult)
        viewModel.addMember(name: "C", dateOfBirth: D.youngChildDOB, role: .child)

        viewModel.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)

        XCTAssertEqual(viewModel.members.map(\.name), ["C", "A", "B"])
        XCTAssertEqual(viewModel.members.map(\.sortOrder), [0, 1, 2])
    }

    @MainActor
    func testDeactivateKeepsTheMemberButOutOfTheActiveList() throws {
        let stack = try TestContainer.makeStack()
        let viewModel = FamilyViewModel(context: stack.context)
        let grandparent = viewModel.addMember(name: "Nani", dateOfBirth: D.date(1955, 2, 2), role: .adult)

        viewModel.setActive(false, for: grandparent)
        XCTAssertEqual(viewModel.activeMembers.map(\.name), [])
        XCTAssertEqual(viewModel.inactiveMembers.map(\.name), ["Nani"])
        XCTAssertEqual(viewModel.members.count, 1)

        viewModel.setActive(true, for: grandparent)
        XCTAssertEqual(viewModel.activeMembers.map(\.name), ["Nani"])
    }

    @MainActor
    func testRemovingAMemberWithoutHistoryDeletesThem() throws {
        let stack = try TestContainer.makeStack()
        let viewModel = FamilyViewModel(context: stack.context)
        let guest = viewModel.addMember(name: "Guest", dateOfBirth: D.adultDOB, role: .adult)

        XCTAssertEqual(viewModel.remove(guest), .deleted)
        XCTAssertTrue(viewModel.members.isEmpty)
    }

    @MainActor
    func testRemovingAMemberWithHistoryDeactivatesThemInstead() throws {
        let stack = try TestContainer.makeStack()
        let viewModel = FamilyViewModel(context: stack.context)
        let child = viewModel.addMember(name: "Ira", dateOfBirth: D.youngChildDOB, role: .child)

        let plan = MealPlan.plan(forWeekContaining: D.date(2026, 9, 9), in: stack.context)
        let slot = MealSlot.slot(in: plan, on: D.date(2026, 9, 9), mealType: .dinner, in: stack.context)
        MealFeedback.record(.ateAll, for: slot, member: child, on: D.date(2026, 9, 9), in: stack.context)
        try stack.context.save()

        XCTAssertEqual(viewModel.remove(child), .deactivated, "Meal history is never thrown away (R6).")
        XCTAssertEqual(viewModel.members.count, 1)
        XCTAssertFalse(child.isActive)
        XCTAssertEqual(try stack.context.fetch(FetchDescriptor<MealFeedback>()).count, 1)
    }

    @MainActor
    func testYoungestAgeDrivesTheDietFilter() throws {
        let stack = try TestContainer.makeStack()
        let viewModel = FamilyViewModel(context: stack.context)
        viewModel.addMember(name: "Shikher", dateOfBirth: D.adultDOB, role: .adult)
        let ira = viewModel.addMember(name: "Ira", dateOfBirth: D.youngChildDOB, role: .child)

        XCTAssertEqual(viewModel.youngestAgeYears(on: D.date(2026, 9, 6)), 4)

        viewModel.setActive(false, for: ira)
        XCTAssertEqual(viewModel.youngestAgeYears(on: D.date(2026, 9, 6)), 38,
                       "An inactive member is not at the table.")
    }

    @MainActor
    func testEmptyHouseholdDoesNotBlockEveryRecipe() throws {
        let stack = try TestContainer.makeStack()
        let viewModel = FamilyViewModel(context: stack.context)
        XCTAssertEqual(viewModel.youngestAgeYears(on: D.date(2026, 9, 6)), Int.max)
    }

    @MainActor
    func testViewModelSeesMembersAlreadyInTheStore() throws {
        let stack = try TestContainer.makeStack()
        stack.context.insert(HouseholdMember(name: "Existing", dateOfBirth: D.adultDOB, role: .adult))
        try stack.context.save()

        let viewModel = FamilyViewModel(context: stack.context)
        XCTAssertEqual(viewModel.members.map(\.name), ["Existing"])
    }
}
