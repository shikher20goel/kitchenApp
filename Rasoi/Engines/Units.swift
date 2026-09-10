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
    /// One teaspoon, in millilitres. The bridge between spoons and grams.
    static let millilitresPerTeaspoon = MeasurementUnit.teaspoon.canonicalFactor

    /// Converts between two units.
    ///
    /// Within a dimension this is the ordinary table. Across dimensions it needs a density:
    /// pass `gramsPerTeaspoon` — which the ingredient catalog carries for anything measured in
    /// spoons but bought by weight — and "1 tsp of salt" and "500 g of salt" become comparable,
    /// so the shopping list stops asking for salt you already have.
    static func convert(
        _ amount: Double,
        from source: MeasurementUnit,
        to target: MeasurementUnit,
        gramsPerTeaspoon: Double? = nil
    ) -> Double? {
        if source.dimension != target.dimension,
           let gramsPerTeaspoon, gramsPerTeaspoon > 0,
           let bridged = acrossDimensions(amount, from: source, to: target,
                                          gramsPerTeaspoon: gramsPerTeaspoon) {
            return bridged
        }
        guard source.dimension == target.dimension else { return nil }
        guard source.dimension != .discrete || source == target else {
            // A "bunch" is not a number of anything in particular, so it never becomes a count.
            return nil
        }
        guard target.canonicalFactor > 0 else { return nil }
        return amount * source.canonicalFactor / target.canonicalFactor
    }

    /// Volume ↔ mass, through the teaspoon.
    private static func acrossDimensions(
        _ amount: Double,
        from source: MeasurementUnit,
        to target: MeasurementUnit,
        gramsPerTeaspoon: Double
    ) -> Double? {
        switch (source.dimension, target.dimension) {
        case (.volume, .mass):
            let millilitres = amount * source.canonicalFactor
            let grams = millilitres / millilitresPerTeaspoon * gramsPerTeaspoon
            return grams / target.canonicalFactor
        case (.mass, .volume):
            let grams = amount * source.canonicalFactor
            let millilitres = grams / gramsPerTeaspoon * millilitresPerTeaspoon
            return millilitres / target.canonicalFactor
        default:
            return nil
        }
    }

    /// Adds two amounts, in the unit of the first. Nil when they cannot be combined.
    static func add(_ left: Quantity, _ right: Quantity, gramsPerTeaspoon: Double? = nil) -> Quantity? {
        guard let converted = convert(right.amount, from: right.unit, to: left.unit,
                                      gramsPerTeaspoon: gramsPerTeaspoon) else { return nil }
        return Quantity(left.amount + converted, left.unit)
    }

    /// Subtracts, never going below zero, in the unit of the first. Nil when incompatible.
    static func subtract(_ left: Quantity, _ right: Quantity, gramsPerTeaspoon: Double? = nil) -> Quantity? {
        guard let converted = convert(right.amount, from: right.unit, to: left.unit,
                                      gramsPerTeaspoon: gramsPerTeaspoon) else { return nil }
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
