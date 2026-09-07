import SwiftData
import XCTest
@testable import Rasoi

final class HouseholdMemberTests: XCTestCase {
    @MainActor
    func testInsertAndFetch() throws {
        let stack = try TestContainer.makeStack()
        let context = stack.context
        context.insert(HouseholdMember(name: "Aarav", dateOfBirth: D.olderChildDOB, role: .child))
        try context.save()

        let members = try context.fetch(FetchDescriptor<HouseholdMember>())
        XCTAssertEqual(members.count, 1)
        XCTAssertEqual(members.first?.name, "Aarav")
        XCTAssertEqual(members.first?.role, .child)
        XCTAssertTrue(members.first?.isActive == true, "Members are active by default.")
    }

    @MainActor
    func testSortOrderOrdersTheHousehold() throws {
        let stack = try TestContainer.makeStack()
        let context = stack.context
        context.insert(HouseholdMember(name: "Third", dateOfBirth: D.adultDOB, role: .adult, sortOrder: 2))
        context.insert(HouseholdMember(name: "First", dateOfBirth: D.adultDOB, role: .adult, sortOrder: 0))
        context.insert(HouseholdMember(name: "Second", dateOfBirth: D.youngChildDOB, role: .child, sortOrder: 1))
        try context.save()

        let descriptor = FetchDescriptor<HouseholdMember>(sortBy: [SortDescriptor(\.sortOrder)])
        XCTAssertEqual(try context.fetch(descriptor).map(\.name), ["First", "Second", "Third"])
    }

    @MainActor
    func testActiveFilterHidesInactiveMembers() throws {
        let stack = try TestContainer.makeStack()
        let context = stack.context
        let away = HouseholdMember(name: "Away", dateOfBirth: D.adultDOB, role: .adult)
        away.isActive = false
        context.insert(away)
        context.insert(HouseholdMember(name: "Here", dateOfBirth: D.adultDOB, role: .adult))
        try context.save()

        let descriptor = FetchDescriptor<HouseholdMember>(predicate: #Predicate { $0.isActive == true })
        XCTAssertEqual(try context.fetch(descriptor).map(\.name), ["Here"])
    }

    @MainActor
    func testLikesAndDislikesRoundTrip() throws {
        let stack = try TestContainer.makeStack()
        let context = stack.context
        let member = HouseholdMember(name: "Ira", dateOfBirth: D.youngChildDOB, role: .child)
        member.likes = ["paneer", "dosa"]
        member.dislikes = ["bitter gourd"]
        context.insert(member)
        try context.save()

        let fetched = try XCTUnwrap(try context.fetch(FetchDescriptor<HouseholdMember>()).first)
        XCTAssertEqual(fetched.likes, ["paneer", "dosa"])
        XCTAssertEqual(fetched.dislikes, ["bitter gourd"])
    }

    @MainActor
    func testAgeBandUsesDateOfBirth() throws {
        let member = HouseholdMember(name: "Ira", dateOfBirth: D.youngChildDOB, role: .child)
        XCTAssertEqual(member.ageBand(on: D.date(2026, 9, 6)), .preschool)
        XCTAssertEqual(member.ageYears(on: D.date(2026, 9, 6)), 4)
    }

    @MainActor
    func testRoleRoundTripsThroughStorage() throws {
        let stack = try TestContainer.makeStack()
        let context = stack.context
        context.insert(HouseholdMember(name: "Parent", dateOfBirth: D.adultDOB, role: .adult))
        try context.save()

        let fetched = try XCTUnwrap(try context.fetch(FetchDescriptor<HouseholdMember>()).first)
        XCTAssertEqual(fetched.role, .adult)
        XCTAssertFalse(fetched.isChild)
    }
}
