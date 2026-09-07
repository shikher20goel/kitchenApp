import Foundation
import SwiftData

/// How the meal went, per person (SPEC §4.1).
///
/// Answering is optional for everyone: a member with no tap gets no row, because "we forgot to
/// ask" is not the same as "they wouldn't eat it". Nothing here shows a score or a streak (R3).
@MainActor
@Observable
final class FeedbackViewModel {
    /// Takes stock out of the pantry when a meal is marked cooked. Implemented by the pantry
    /// depletion engine; a test can substitute its own.
    protocol Depleting {
        @MainActor
        func deplete(slot: MealSlot, in context: ModelContext)
    }

    private let context: ModelContext
    private let now: () -> Date
    private let depleter: Depleting?

    let slot: MealSlot
    private(set) var members: [HouseholdMember] = []
    /// In-flight choices, keyed by member name, saved when the household taps Save.
    private(set) var selections: [String: MealReaction] = [:]
    var notes: [String: String] = [:]

    init(
        slot: MealSlot,
        context: ModelContext,
        depleter: Depleting? = nil,
        now: @escaping () -> Date = { .now }
    ) {
        self.slot = slot
        self.context = context
        self.depleter = depleter
        self.now = now
        load()
    }

    func load() {
        let descriptor = FetchDescriptor<HouseholdMember>(sortBy: [SortDescriptor(\.sortOrder)])
        members = ((try? context.fetch(descriptor)) ?? []).filter(\.isActive)

        // Start from whatever was recorded before, so re-opening the sheet shows the last answer.
        for entry in slot.feedback {
            guard let name = entry.member?.name else { continue }
            selections[name] = entry.reaction
            notes[name] = entry.note ?? ""
        }
    }

    func reaction(for member: HouseholdMember) -> MealReaction? {
        selections[member.name]
    }

    func select(_ reaction: MealReaction, for member: HouseholdMember) {
        if selections[member.name] == reaction {
            selections.removeValue(forKey: member.name)
        } else {
            selections[member.name] = reaction
        }
    }

    var answeredCount: Int { selections.count }

    var canSave: Bool { !selections.isEmpty }

    /// Writes one row per member who was actually asked, marks the meal cooked, and lets the
    /// pantry know what was used.
    func save() {
        let date = now()
        for member in members {
            guard let reaction = selections[member.name] else { continue }
            let note = notes[member.name]?.trimmingCharacters(in: .whitespacesAndNewlines)
            MealFeedback.record(
                reaction,
                for: slot,
                member: member,
                note: (note?.isEmpty ?? true) ? nil : note,
                on: date,
                in: context
            )
        }

        if slot.status != .cooked {
            slot.status = .cooked
            depleter?.deplete(slot: slot, in: context)
        }
        try? context.save()
    }
}
