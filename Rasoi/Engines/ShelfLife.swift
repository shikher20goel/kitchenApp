import Foundation

/// Turns a catalog shelf life into a date, and answers "is this about to go off?" (SPEC §5).
/// Pure and calendar-based so a day is a day regardless of the hour something was added.
enum ShelfLife {
    /// Frozen food keeps roughly six times as long as the same item in the fridge.
    static let freezerMultiplier = 6
    /// The Today screen and the Pantry warn this far ahead.
    static let expiringSoonWindowDays = 2
    /// The planner reaches a day further to build "use it up" meals.
    static let useItUpWindowDays = 3

    /// When something added on `addedAt` should be used by.
    static func expiry(shelfLifeDays: Int, addedAt: Date, location: PantryLocation) -> Date? {
        guard shelfLifeDays > 0 else { return addedAt }
        let days = shelfLifeDays * (location == .freezer ? freezerMultiplier : 1)
        return Calendar.rasoi.date(byAdding: .day, value: days, to: addedAt)
    }

    /// Whole days from `date` until `expiresAt`; negative once it has passed.
    static func daysUntilExpiry(_ expiresAt: Date, on date: Date) -> Int {
        let calendar = Calendar.rasoi
        let from = calendar.startOfDay(for: date)
        let to = calendar.startOfDay(for: expiresAt)
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }

    /// True when the item expires within `within` days — or already has.
    static func isExpiringSoon(_ expiresAt: Date?, on date: Date, within days: Int = expiringSoonWindowDays) -> Bool {
        guard let expiresAt else { return false }
        return daysUntilExpiry(expiresAt, on: date) <= days
    }
}
