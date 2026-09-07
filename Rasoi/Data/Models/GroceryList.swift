import Foundation
import SwiftData

/// One week's shopping (SPEC §3). Built from the plan, merged rather than rebuilt so a list that
/// is half ticked off never loses the household's progress.
@Model
final class GroceryList {
    /// Midnight on the Monday of the week this list covers. Unique: one list per week.
    @Attribute(.unique) var weekStart: Date = Date.distantPast
    var generatedAt: Date?
    /// Set once the household is done shopping; the list is kept for the record either way.
    var isFinalized: Bool = false
    @Relationship(deleteRule: .cascade, inverse: \GroceryItem.list)
    var items: [GroceryItem] = []

    init(weekStart: Date, generatedAt: Date? = nil, isFinalized: Bool = false) {
        self.weekStart = weekStart
        self.generatedAt = generatedAt
        self.isFinalized = isFinalized
    }

    /// The list for this week, created on first use.
    @MainActor
    static func list(forWeekContaining date: Date, in context: ModelContext) -> GroceryList {
        let start = MealPlan.weekStart(containing: date)
        let descriptor = FetchDescriptor<GroceryList>(predicate: #Predicate { $0.weekStart == start })
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let list = GroceryList(weekStart: start)
        context.insert(list)
        return list
    }

    var remainingItems: [GroceryItem] { items.filter { !$0.isChecked } }
}

/// One line on the shopping list.
@Model
final class GroceryItem {
    var list: GroceryList?
    var ingredient: Ingredient?
    var quantity: Double = 0
    var unitRaw: String = MeasurementUnit.gram.rawValue
    var store: Store?
    var isChecked: Bool = false
    /// When it was ticked off — the moment it moves into the pantry.
    var checkedAt: Date?
    /// Recipe titles that need this, for the "Why?" disclosure.
    var neededFor: [String] = []
    /// A weekly staple rather than something a planned recipe called for.
    var isStapleTopUp: Bool = false
    var addedManually: Bool = false

    init(
        list: GroceryList?,
        ingredient: Ingredient?,
        quantity: Double,
        unit: MeasurementUnit,
        store: Store? = nil,
        neededFor: [String] = [],
        isStapleTopUp: Bool = false,
        addedManually: Bool = false
    ) {
        self.list = list
        self.ingredient = ingredient
        self.quantity = quantity
        self.unitRaw = unit.rawValue
        self.store = store
        self.neededFor = neededFor
        self.isStapleTopUp = isStapleTopUp
        self.addedManually = addedManually
    }

    var unit: MeasurementUnit {
        get { MeasurementUnit(rawValue: unitRaw) ?? .gram }
        set { unitRaw = newValue.rawValue }
    }

    /// Ticking an item is what moves it into the pantry, so the timestamp is part of the state:
    /// unchecking clears it and nothing restocks twice.
    func setChecked(_ checked: Bool, on date: Date) {
        isChecked = checked
        checkedAt = checked ? date : nil
    }
}
