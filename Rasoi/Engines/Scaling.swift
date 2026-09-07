import Foundation

/// Scales a recipe's ingredients to a different number of servings (SPEC §4.1, cook mode).
///
/// Quantities are rounded to something a person can actually measure — a quarter of an onion,
/// 225 g of dal — never 1.6667 onions. Pure and deterministic (R5).
enum Scaling {
    /// Ingredients scaled from `from` servings to `to`, with kitchen-friendly rounding.
    static func scale(_ ingredients: [RecipeIngredient], from: Int, to: Int) -> [RecipeIngredient] {
        guard from > 0, to > 0, from != to else { return ingredients }
        let factor = Double(to) / Double(from)
        return ingredients.map { line in
            var scaled = line
            scaled.quantity = round(line.quantity * factor, unit: line.unit)
            return scaled
        }
    }

    /// Rounds a quantity to a step the unit makes sense in.
    ///
    /// - Counted things (2 onions, 1 bunch) go to the nearest quarter.
    /// - Weights and volumes go to the nearest 5 once they are big enough for that to be a
    ///   measurement rather than a distortion; small amounts — a gram of chilli powder — keep
    ///   half-unit precision.
    static func round(_ value: Double, unit: MeasurementUnit) -> Double {
        guard value > 0 else { return 0 }
        switch unit.dimension {
        case .discrete:
            return snap(value, to: 0.25)
        case .mass, .volume:
            if value >= 20 { return snap(value, to: 5) }
            if value >= 5 { return snap(value, to: 1) }
            return snap(value, to: 0.5)
        }
    }

    private static func snap(_ value: Double, to step: Double) -> Double {
        let snapped = (value / step).rounded() * step
        // Never round something away entirely: a pinch stays a pinch.
        return snapped > 0 ? snapped : step
    }

    /// A servings choice offered in cook mode, around the recipe's own number.
    static func servingOptions(around servings: Int) -> [Int] {
        let lower = max(1, servings - 2)
        let upper = max(servings + 4, lower + 4)
        return Array(lower...upper)
    }
}
