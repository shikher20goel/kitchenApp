import Foundation

/// An amount with a unit. The one currency the pantry, the recipes and the grocery list all trade
/// in, so nothing is ever added up in the wrong dimension.
struct Quantity: Hashable, Sendable {
    var amount: Double
    var unit: MeasurementUnit

    init(_ amount: Double, _ unit: MeasurementUnit) {
        self.amount = amount
        self.unit = unit
    }

    var canonical: Quantity {
        Quantity(amount * unit.canonicalFactor, unit.canonical)
    }
}

/// Unit conversion (SPEC §5, GroceryBuilder and PantryDepletion).
///
/// One general table, no per-ingredient special cases: everything within a dimension converts
/// through a canonical unit (grams for mass, millilitres for volume) and counted things stay
/// counted. Cups, tablespoons and teaspoons are the US measures the seeded recipes use.
enum Units {
    /// Converts between two units of the same dimension. Returns nil when they do not measure the
    /// same kind of thing — grams of dal are not millilitres of milk.
    static func convert(_ amount: Double, from source: MeasurementUnit, to target: MeasurementUnit) -> Double? {
        guard source.dimension == target.dimension else { return nil }
        guard source.dimension != .discrete || source == target else {
            // A "bunch" is not a number of anything in particular, so it never becomes a count.
            return nil
        }
        guard target.canonicalFactor > 0 else { return nil }
        return amount * source.canonicalFactor / target.canonicalFactor
    }

    /// Adds two amounts, in the unit of the first. Nil when they cannot be combined.
    static func add(_ left: Quantity, _ right: Quantity) -> Quantity? {
        guard let converted = convert(right.amount, from: right.unit, to: left.unit) else { return nil }
        return Quantity(left.amount + converted, left.unit)
    }

    /// Subtracts, never going below zero, in the unit of the first. Nil when incompatible.
    static func subtract(_ left: Quantity, _ right: Quantity) -> Quantity? {
        guard let converted = convert(right.amount, from: right.unit, to: left.unit) else { return nil }
        return Quantity(max(0, left.amount - converted), left.unit)
    }

    /// Sums amounts that share a dimension into one canonical quantity. Amounts from another
    /// dimension are returned separately rather than silently dropped.
    static func sum(_ quantities: [Quantity]) -> [Quantity] {
        var totals: [MeasurementUnit: Double] = [:]
        var order: [MeasurementUnit] = []
        for quantity in quantities {
            let canonical = quantity.canonical
            if totals[canonical.unit] == nil { order.append(canonical.unit) }
            totals[canonical.unit, default: 0] += canonical.amount
        }
        return order.map { Quantity(totals[$0] ?? 0, $0) }
    }

    /// A shopping-list friendly rendering: 1200 g reads as "1.2 kg", 250 ml stays "250 ml".
    static func display(_ quantity: Quantity) -> String {
        let canonical = quantity.canonical
        switch canonical.unit {
        case .gram where canonical.amount >= 1000:
            return "\(number(canonical.amount / 1000)) kg"
        case .millilitre where canonical.amount >= 1000:
            return "\(number(canonical.amount / 1000)) l"
        case .count:
            return "×\(number(canonical.amount))"
        case .bunch:
            return "\(number(canonical.amount)) bunch"
        default:
            return "\(number(canonical.amount)) \(canonical.unit.rawValue)"
        }
    }

    private static func number(_ value: Double) -> String {
        if abs(value - value.rounded()) < 0.005 {
            return String(Int(value.rounded()))
        }
        return String(format: "%.1f", value)
    }
}
