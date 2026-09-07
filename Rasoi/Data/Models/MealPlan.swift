import Foundation
import SwiftData

/// One week of planned meals, always Monday-based (SPEC §3).
@Model
final class MealPlan {
    /// Midnight on the Monday the week starts. Unique: one plan per week.
    @Attribute(.unique) var weekStart: Date = Date.distantPast
    var generatedAt: Date?
    @Relationship(deleteRule: .cascade, inverse: \MealSlot.plan)
    var slots: [MealSlot] = []

    init(weekStart: Date, generatedAt: Date? = nil) {
        self.weekStart = weekStart
        self.generatedAt = generatedAt
    }

    /// Midnight on the Monday of the week `date` falls in. Sunday belongs to the week that began
    /// six days earlier, which is why the app calendar sets `firstWeekday = 2`.
    static func weekStart(containing date: Date) -> Date {
        let calendar = Calendar.rasoi
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay) // 1 = Sunday
        let daysSinceMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysSinceMonday, to: startOfDay) ?? startOfDay
    }

    /// The seven days, Monday first, of the week `date` falls in.
    static func days(ofWeekContaining date: Date) -> [Date] {
        let start = weekStart(containing: date)
        return (0..<7).compactMap { Calendar.rasoi.date(byAdding: .day, value: $0, to: start) }
    }

    /// The plan for this week, created on first use.
    @MainActor
    static func plan(forWeekContaining date: Date, in context: ModelContext) -> MealPlan {
        let start = weekStart(containing: date)
        let descriptor = FetchDescriptor<MealPlan>(predicate: #Predicate { $0.weekStart == start })
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let plan = MealPlan(weekStart: start)
        context.insert(plan)
        return plan
    }

    var days: [Date] { MealPlan.days(ofWeekContaining: weekStart) }

    /// The slots of one day, in the order meals happen.
    func slots(on date: Date) -> [MealSlot] {
        let day = Calendar.rasoi.startOfDay(for: date)
        return slots
            .filter { $0.date == day }
            .sorted { $0.mealType.sortOrder < $1.mealType.sortOrder }
    }
}

/// One meal on one day (SPEC §3). Exactly one slot exists per date + meal type.
@Model
final class MealSlot {
    var plan: MealPlan?
    /// Midnight on the day of the meal.
    var date: Date = Date.distantPast
    var mealTypeRaw: String = MealType.dinner.rawValue
    var recipe: Recipe?
    var servings: Int = 4
    var statusRaw: String = MealSlotStatus.planned.rawValue
    /// Why the planner chose this recipe — shown as "why this" (SPEC R5).
    var reasons: [String] = []
    /// A locked slot survives regeneration untouched.
    var lockedByUser: Bool = false
    @Relationship(deleteRule: .cascade, inverse: \MealFeedback.slot)
    var feedback: [MealFeedback] = []

    init(
        plan: MealPlan?,
        date: Date,
        mealType: MealType,
        recipe: Recipe? = nil,
        servings: Int = 4,
        status: MealSlotStatus = .planned,
        reasons: [String] = [],
        lockedByUser: Bool = false
    ) {
        self.plan = plan
        self.date = Calendar.rasoi.startOfDay(for: date)
        self.mealTypeRaw = mealType.rawValue
        self.recipe = recipe
        self.servings = servings
        self.statusRaw = status.rawValue
        self.reasons = reasons
        self.lockedByUser = lockedByUser
    }

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .dinner }
        set { mealTypeRaw = newValue.rawValue }
    }

    var status: MealSlotStatus {
        get { MealSlotStatus(rawValue: statusRaw) ?? .planned }
        set { statusRaw = newValue.rawValue }
    }

    /// Monday–Friday dinners have to fit the weekday time cap (SPEC §5 rule 2).
    var isWeekday: Bool {
        let weekday = Calendar.rasoi.component(.weekday, from: date)
        return weekday >= 2 && weekday <= 6
    }

    /// The slot for this day and meal, created on first use.
    @MainActor
    static func slot(in plan: MealPlan, on date: Date, mealType: MealType, in context: ModelContext) -> MealSlot {
        let day = Calendar.rasoi.startOfDay(for: date)
        if let existing = plan.slots.first(where: { $0.date == day && $0.mealTypeRaw == mealType.rawValue }) {
            return existing
        }
        let slot = MealSlot(plan: plan, date: day, mealType: mealType)
        context.insert(slot)
        plan.slots.append(slot)
        return slot
    }
}

/// What happened to a planned meal. Nothing here is a judgement of the cook or the child (R3).
enum MealSlotStatus: String, Codable, CaseIterable, Sendable {
    case planned
    case cooked
    case skipped
    case eatingOut

    var label: String {
        switch self {
        case .planned: return "Planned"
        case .cooked: return "Cooked"
        case .skipped: return "Skipped"
        case .eatingOut: return "Eating out"
        }
    }
}

/// One child's (or adult's) reaction to one cooked meal (SPEC §3). One row per slot per member.
@Model
final class MealFeedback {
    var slot: MealSlot?
    var member: HouseholdMember?
    var reactionRaw: String = MealReaction.ateAll.rawValue
    var note: String?
    var createdAt: Date = Date.distantPast

    init(slot: MealSlot?, member: HouseholdMember?, reaction: MealReaction, note: String? = nil, createdAt: Date) {
        self.slot = slot
        self.member = member
        self.reactionRaw = reaction.rawValue
        self.note = note
        self.createdAt = createdAt
    }

    var reaction: MealReaction {
        get { MealReaction(rawValue: reactionRaw) ?? .ateAll }
        set { reactionRaw = newValue.rawValue }
    }

    /// Records a reaction, replacing this member's earlier one for the same meal.
    @discardableResult
    @MainActor
    static func record(
        _ reaction: MealReaction,
        for slot: MealSlot,
        member: HouseholdMember,
        note: String? = nil,
        on date: Date,
        in context: ModelContext
    ) -> MealFeedback {
        if let existing = slot.feedback.first(where: { $0.member === member }) {
            existing.reaction = reaction
            existing.note = note
            existing.createdAt = date
            return existing
        }
        let entry = MealFeedback(slot: slot, member: member, reaction: reaction, note: note, createdAt: date)
        context.insert(entry)
        slot.feedback.append(entry)
        return entry
    }
}

/// How a meal went. Three buttons, warm and neutral — never a score a child can fail (SPEC R3).
enum MealReaction: String, Codable, CaseIterable, Sendable {
    case ateAll
    case ateSome
    case notToday

    var label: String {
        switch self {
        case .ateAll: return AppCopy.reactionAteAll
        case .ateSome: return AppCopy.reactionAteSome
        case .notToday: return AppCopy.reactionNotToday
        }
    }

    var symbolName: String {
        switch self {
        case .ateAll: return "checkmark.circle.fill"
        case .ateSome: return "circle.lefthalf.filled"
        case .notToday: return "arrow.uturn.left.circle"
        }
    }

    /// Contribution to a kid score (SPEC §5, KidScore).
    var weight: Double {
        switch self {
        case .ateAll: return 1
        case .ateSome: return 0.4
        case .notToday: return -1
        }
    }
}
