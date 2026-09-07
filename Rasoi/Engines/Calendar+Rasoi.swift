import Foundation

extension Calendar {
    /// The one calendar every engine uses. Gregorian with Monday as the first weekday so
    /// `MealPlan.weekStart` is always a Monday (SPEC §3), and the user's own time zone so
    /// "today" means their today. Engines take dates only through this calendar, which keeps
    /// planning deterministic for a given input (SPEC R5).
    static var rasoi: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // Monday
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    /// Midnight at the start of the given day, in this calendar.
    func startOfDay(forDay date: Date) -> Date {
        startOfDay(for: date)
    }
}
