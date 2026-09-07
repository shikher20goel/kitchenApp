import Foundation

/// Something a child can have right now, from what is already in the kitchen (SPEC §4.1).
struct SnackSuggestion: Hashable, Identifiable, Sendable {
    enum Source: Sendable {
        /// Straight from the pantry — an apple, a yogurt.
        case pantry
        /// A quick snack recipe whose ingredients are all in.
        case recipe
    }

    var id: String
    var title: String
    /// A short, factual line: where it is, or how long it takes.
    var detail: String
    var source: Source
    /// Set when the suggestion is a recipe, so the row can open it.
    var recipeID: String?
    var symbolName: String
}

/// Picks three easy snacks (SPEC §4.1).
///
/// Fruit first — it needs no cooking and no decision — then a quick snack recipe the pantry
/// already covers (the spinach-banana smoothie the Vitamix is for), then whatever else is tagged
/// as an easy healthy snack. Deterministic: the same kitchen always gives the same three (R5).
enum QuickSnacks {
    static let defaultLimit = 3

    static func suggestions(
        pantry: PantrySnapshot,
        index: IngredientIndex,
        recipes: [RecipeSummary],
        on date: Date,
        limit: Int = defaultLimit
    ) -> [SnackSuggestion] {
        var suggestions: [SnackSuggestion] = []
        var used: Set<String> = []

        // 1. Fruit already in the kitchen, soonest to go off first.
        for stock in stocked(pantry: pantry, index: index, category: .fruit) {
            guard used.insert(Ingredient.fold(stock.name)).inserted else { continue }
            suggestions.append(
                SnackSuggestion(
                    id: "pantry:\(Ingredient.fold(stock.name))",
                    title: stock.name,
                    detail: stock.expiresAt.map { expiryDetail($0, on: date) } ?? "ready to eat",
                    source: .pantry,
                    recipeID: nil,
                    symbolName: IngredientCategory.fruit.symbolName
                )
            )
        }

        // 2. A quick snack the pantry already covers.
        let coveredRecipes = recipes
            .filter { $0.serves(.snack) && $0.isQuick && pantry.coverage(for: $0) >= 0.999 }
            .sorted { $0.id < $1.id }
        for recipe in coveredRecipes {
            suggestions.append(
                SnackSuggestion(
                    id: "recipe:\(recipe.id)",
                    title: recipe.title,
                    detail: "\(recipe.totalMinutes) min · everything is in",
                    source: .recipe,
                    recipeID: recipe.id,
                    symbolName: MealType.snack.symbolName
                )
            )
        }

        // 3. Anything else in the kitchen tagged as an easy healthy snack.
        for stock in stocked(pantry: pantry, index: index, category: nil) {
            guard used.insert(Ingredient.fold(stock.name)).inserted else { continue }
            suggestions.append(
                SnackSuggestion(
                    id: "pantry:\(Ingredient.fold(stock.name))",
                    title: stock.name,
                    detail: stock.expiresAt.map { expiryDetail($0, on: date) } ?? "ready to eat",
                    source: .pantry,
                    recipeID: nil,
                    symbolName: index.facts(for: stock.name)?.category.symbolName ?? "leaf"
                )
            )
        }

        return Array(suggestions.prefix(limit))
    }

    /// Quick-healthy-snack ingredients in the pantry, optionally of one category, in a stable
    /// order: soonest to expire first, then by name.
    private static func stocked(
        pantry: PantrySnapshot,
        index: IngredientIndex,
        category: IngredientCategory?
    ) -> [PantryStock] {
        pantry.items
            .filter { stock in
                guard stock.quantity > 0, let facts = index.facts(for: stock.name) else { return false }
                guard facts.isQuickHealthySnack else { return false }
                return category == nil || facts.category == category
            }
            .sorted { left, right in
                switch (left.expiresAt, right.expiresAt) {
                case let (leftDate?, rightDate?) where leftDate != rightDate:
                    return leftDate < rightDate
                case (nil, .some):
                    return false
                case (.some, nil):
                    return true
                default:
                    return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
                }
            }
    }

    private static func expiryDetail(_ expiresAt: Date, on date: Date) -> String {
        let days = ShelfLife.daysUntilExpiry(expiresAt, on: date)
        switch days {
        case ..<0: return "past its date"
        case 0: return "use today"
        case 1: return "1 day left"
        default: return "ready to eat"
        }
    }
}
