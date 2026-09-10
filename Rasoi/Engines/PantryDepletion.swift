import Foundation
import SwiftData

/// Takes what a cooked meal used out of the pantry (SPEC §5).
///
/// Only required ingredients are drawn down: an optional garnish may or may not have gone in, and
/// guessing wrong would quietly corrupt the pantry. Quantities never go below zero, and a row that
/// reaches zero is removed unless the ingredient is a weekly staple — those stay so the shopping
/// list can top them up.
enum PantryDepletion {
    /// How much of each ingredient a meal used, keyed by folded catalog name.
    static func requirements(
        for ingredients: [RecipeIngredient],
        recipeServings: Int,
        cookedServings: Int
    ) -> [String: Quantity] {
        let scaled = Scaling.scale(ingredients, from: recipeServings, to: cookedServings)
        var totals: [String: Quantity] = [:]
        for line in scaled where !line.isOptional {
            let key = Ingredient.fold(line.ingredientName)
            let quantity = Quantity(line.quantity, line.unit)
            if let existing = totals[key], let combined = Units.add(existing, quantity) {
                totals[key] = combined
            } else if totals[key] == nil {
                totals[key] = quantity
            }
        }
        return totals
    }

    /// Applies a cooked slot to the pantry.
    @MainActor
    static func apply(slot: MealSlot, in context: ModelContext) {
        guard let recipe = slot.recipe else { return }
        apply(
            recipe.ingredients,
            recipeServings: recipe.servings,
            cookedServings: slot.servings,
            in: context
        )
    }

    @MainActor
    static func apply(
        _ ingredients: [RecipeIngredient],
        recipeServings: Int,
        cookedServings: Int,
        in context: ModelContext
    ) {
        let needed = requirements(for: ingredients, recipeServings: recipeServings, cookedServings: cookedServings)
        guard !needed.isEmpty else { return }
        let stock = (try? context.fetch(FetchDescriptor<PantryItem>())) ?? []

        for (name, required) in needed {
            var remaining = required
            // Draw from whatever expires first: cooking is the best way to use something up.
            let rows = stock
                .filter { Ingredient.fold($0.ingredient?.name ?? "") == name && $0.quantity > 0 }
                .sorted(by: soonestFirst)

            for row in rows {
                guard remaining.amount > 0 else { break }
                // A teaspoon of turmeric has to come out of a jar measured in grams.
                let density = row.ingredient?.gramsPerTeaspoon
                guard let available = Units.convert(row.quantity, from: row.unit, to: remaining.unit,
                                                    gramsPerTeaspoon: density) else { continue }
                let take = min(available, remaining.amount)
                row.consume(quantity: take, unit: remaining.unit, gramsPerTeaspoon: density)
                remaining.amount -= take
            }
        }

        // A row at zero goes, unless it is a staple the household always keeps in.
        for row in stock where row.quantity <= 0 {
            if row.ingredient?.isStaple == true {
                row.quantity = 0
            } else {
                context.delete(row)
            }
        }
        try? context.save()
    }

    /// Deterministic order: soonest expiry first, then fridge before pantry before freezer.
    private static func soonestFirst(_ left: PantryItem, _ right: PantryItem) -> Bool {
        switch (left.expiresAt, right.expiresAt) {
        case let (leftDate?, rightDate?) where leftDate != rightDate:
            return leftDate < rightDate
        case (nil, .some):
            return false
        case (.some, nil):
            return true
        default:
            let order: [PantryLocation] = [.fridge, .pantry, .freezer]
            let leftIndex = order.firstIndex(of: left.location) ?? order.count
            let rightIndex = order.firstIndex(of: right.location) ?? order.count
            return leftIndex < rightIndex
        }
    }
}
