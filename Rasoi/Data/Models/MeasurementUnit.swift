import Foundation

/// The units Rasoi measures in. Raw values match `seed/*.json`; the grocery list normalises to a
/// canonical unit per dimension before it sums anything (SPEC §5, GroceryBuilder).
enum MeasurementUnit: String, Codable, CaseIterable, Sendable {
    case gram = "g"
    case kilogram = "kg"
    case millilitre = "ml"
    case litre = "l"
    case count
    case bunch
    case cup
    case tablespoon = "tbsp"
    case teaspoon = "tsp"

    /// What the unit measures. Only units in the same dimension can be added together.
    enum Dimension: Sendable {
        case mass, volume, discrete
    }

    var dimension: Dimension {
        switch self {
        case .gram, .kilogram: return .mass
        case .millilitre, .litre, .cup, .tablespoon, .teaspoon: return .volume
        case .count, .bunch: return .discrete
        }
    }

    /// The unit quantities of this dimension are stored and summed in.
    var canonical: MeasurementUnit {
        switch dimension {
        case .mass: return .gram
        case .volume: return .millilitre
        case .discrete: return self
        }
    }

    /// How many canonical units one of this unit is worth. `bunch` and `count` stay themselves.
    var canonicalFactor: Double {
        switch self {
        case .gram, .millilitre, .count, .bunch: return 1
        case .kilogram, .litre: return 1000
        case .cup: return 240
        case .tablespoon: return 15
        case .teaspoon: return 5
        }
    }

    /// What a household usually buys or adds at once, used to prefill a quantity field. Counted
    /// things start at one — nobody buys 200 bunches of spinach.
    var typicalQuantity: Double {
        switch dimension {
        case .discrete: return 1
        case .mass: return 200
        case .volume: return 500
        }
    }

    /// Short label for lists ("g", "ml", "×3" is rendered by the view, not here).
    var shortLabel: String {
        switch self {
        case .count: return ""
        case .bunch: return "bunch"
        default: return rawValue
        }
    }
}
