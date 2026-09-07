import Foundation
@testable import Rasoi

/// Fixed dates for deterministic tests (SPEC R5). Never use `Date()` in a test.
enum D {
    /// A date at noon in the app calendar's time zone — noon keeps DST shifts from moving the day.
    static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        guard let date = Calendar.rasoi.date(from: components) else {
            preconditionFailure("Invalid test date \(year)-\(month)-\(day)")
        }
        return date
    }

    /// The demo household's children (CLAUDE.md: never commit real family data).
    static let youngChildDOB = date(2022, 3, 1)
    static let olderChildDOB = date(2017, 6, 15)
    static let adultDOB = date(1988, 4, 20)
}
