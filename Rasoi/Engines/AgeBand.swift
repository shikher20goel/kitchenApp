import Foundation

/// A family member's age band (SPEC §3). Nutrition coverage targets and the planner's
/// minimum-age filter both read this — never a raw age — so the bands stay the single source
/// of truth for "how old is old enough".
enum AgeBand: String, Codable, CaseIterable, Sendable {
    case preschool  // 2–5
    case child      // 6–8
    case preteen    // 9–13
    case teen       // 14–18
    case adult      // 19+

    /// Whole years completed between `dob` and `date`. Never negative: a date of birth in the
    /// future reads as 0 rather than a nonsense age.
    static func years(dob: Date, on date: Date = .now) -> Int {
        let calendar = Calendar.rasoi
        let from = calendar.startOfDay(for: dob)
        let to = calendar.startOfDay(for: date)
        guard to >= from else { return 0 }
        return calendar.dateComponents([.year], from: from, to: to).year ?? 0
    }

    /// The band a person born on `dob` is in on `date`.
    ///
    /// Under-twos share the youngest band: Rasoi plans family meals and has no infant-feeding
    /// content, so a baby is simply handled as the youngest eater at the table.
    static func band(dob: Date, on date: Date = .now) -> AgeBand {
        band(years: years(dob: dob, on: date))
    }

    /// The band for a whole-year age.
    static func band(years: Int) -> AgeBand {
        switch years {
        case ..<6: return .preschool
        case 6...8: return .child
        case 9...13: return .preteen
        case 14...18: return .teen
        default: return .adult
        }
    }

    /// A short, warm label for the UI. Never used to describe how much someone should eat (R2).
    var label: String {
        switch self {
        case .preschool: return "2–5 years"
        case .child: return "6–8 years"
        case .preteen: return "9–13 years"
        case .teen: return "14–18 years"
        case .adult: return "Adult"
        }
    }
}
