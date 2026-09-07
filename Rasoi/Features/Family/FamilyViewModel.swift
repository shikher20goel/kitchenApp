import Foundation
import SwiftData

/// Who is in the household, and the rules for changing that.
///
/// Members are never deleted once they have meal feedback: a child's history is what the planner
/// learns from, so removing someone deactivates them instead (SPEC R6).
@MainActor
@Observable
final class FamilyViewModel {
    private let context: ModelContext

    /// Everyone, active first, then by their own order.
    private(set) var members: [HouseholdMember] = []

    /// Suggested avatars — SF Symbols only, no photos, nothing to upload.
    static let avatarSymbols = [
        "person.circle", "figure.child.circle", "star.circle", "leaf.circle",
        "heart.circle", "sun.max.circle", "moon.circle", "bolt.circle",
    ]

    /// The palette a member's chip can use.
    static let avatarColors = ["E8A33D", "7C9A73", "C2643F", "5B8FA8", "9A7BB0", "B0894F"]

    init(context: ModelContext) {
        self.context = context
        load()
    }

    func load() {
        let descriptor = FetchDescriptor<HouseholdMember>(
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
        )
        members = (try? context.fetch(descriptor)) ?? []
    }

    var activeMembers: [HouseholdMember] { members.filter(\.isActive) }
    var inactiveMembers: [HouseholdMember] { members.filter { !$0.isActive } }
    var children: [HouseholdMember] { activeMembers.filter(\.isChild) }
    var adults: [HouseholdMember] { activeMembers.filter { !$0.isChild } }

    /// The age of the youngest person at the table — what the diet filter compares against.
    /// With nobody in the household yet, every recipe is allowed.
    func youngestAgeYears(on date: Date = .now) -> Int {
        activeMembers.map { $0.ageYears(on: date) }.min() ?? Int.max
    }

    @discardableResult
    func addMember(
        name: String,
        dateOfBirth: Date,
        role: MemberRole,
        likes: [String] = [],
        dislikes: [String] = [],
        avatarSymbol: String? = nil,
        colorHex: String? = nil
    ) -> HouseholdMember {
        let index = members.count
        let member = HouseholdMember(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            dateOfBirth: dateOfBirth,
            role: role,
            likes: likes,
            dislikes: dislikes,
            avatarSymbol: avatarSymbol ?? (role == .child ? "figure.child.circle" : "person.circle"),
            colorHex: colorHex ?? Self.avatarColors[index % Self.avatarColors.count],
            sortOrder: index
        )
        context.insert(member)
        save()
        return member
    }

    func update(
        _ member: HouseholdMember,
        name: String? = nil,
        dateOfBirth: Date? = nil,
        role: MemberRole? = nil,
        likes: [String]? = nil,
        dislikes: [String]? = nil,
        avatarSymbol: String? = nil,
        colorHex: String? = nil
    ) {
        if let name { member.name = name.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let dateOfBirth { member.dateOfBirth = dateOfBirth }
        if let role { member.role = role }
        if let likes { member.likes = likes }
        if let dislikes { member.dislikes = dislikes }
        if let avatarSymbol { member.avatarSymbol = avatarSymbol }
        if let colorHex { member.colorHex = colorHex }
        save()
    }

    /// Moves members around in the list; `sortOrder` is renumbered so the order sticks.
    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        var ordered = members
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, member) in ordered.enumerated() {
            member.sortOrder = index
        }
        save()
    }

    func setActive(_ isActive: Bool, for member: HouseholdMember) {
        member.isActive = isActive
        save()
    }

    /// What happened when the household asked to remove someone.
    enum RemovalOutcome: Equatable {
        /// Nobody had recorded a meal for them, so the row is gone.
        case deleted
        /// They have meal history, which the planner learns from, so they were deactivated.
        case deactivated
    }

    @discardableResult
    func remove(_ member: HouseholdMember) -> RemovalOutcome {
        if hasFeedback(member) {
            setActive(false, for: member)
            return .deactivated
        }
        context.delete(member)
        save()
        return .deleted
    }

    func hasFeedback(_ member: HouseholdMember) -> Bool {
        let name = member.name
        let descriptor = FetchDescriptor<MealFeedback>(
            predicate: #Predicate { $0.member?.name == name }
        )
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    private func save() {
        try? context.save()
        load()
    }
}
