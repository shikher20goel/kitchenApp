import Foundation

/// One planned meal's contribution to the shopping list.
struct PlannedRecipe: Hashable, Sendable {
    var recipeID: String
    var title: String
    var ingredients: [RecipeIngredient]
    /// What the recipe is written for.
    var recipeServings: Int
    /// What the household plans to cook.
    var servings: Int
}

/// One line of the built list, before it becomes a `GroceryItem`.
struct GroceryLine: Hashable, Sendable {
    var ingredientName: String
    var quantity: Double
    var unit: MeasurementUnit
    var category: IngredientCategory
    /// Which store it is assigned to, or nil for "any store".
    var storeID: String?
    /// Recipe titles that need it, for the "Why?" disclosure.
    var neededFor: [String]
    var isStapleTopUp: Bool
}

/// A line already on the household's list, as the merge sees it.
struct ExistingGroceryLine: Hashable, Sendable {
    var ingredientName: String
    var quantity: Double
    var unit: MeasurementUnit
    var isChecked: Bool
    var addedManually: Bool
    /// Recipe titles currently recorded against the line, so a rebuild can notice that the meal
    /// that needed it has been cooked.
    var neededFor: [String] = []
}

/// Turns a week of planned meals into a shopping list (SPEC §5).
///
/// Sum what the meals need → normalise units → subtract what is already in → add the weekly
/// staples → put each line in a store. Merging back into an existing list never disturbs anything
/// the household has already ticked off or added themselves.
enum GroceryBuilder {
    /// How much of a staple to buy when the household is out of it. General by dimension — there
    /// are no per-ingredient amounts anywhere in Rasoi.
    static func staplePackSize(for facts: IngredientFacts) -> Quantity {
        switch facts.defaultUnit.dimension {
        case .mass: return Quantity(500, .gram)
        case .volume: return Quantity(1000, .millilitre)
        case .discrete: return Quantity(facts.defaultUnit == .bunch ? 1 : 2, facts.defaultUnit)
        }
    }

    static func build(
        meals: [PlannedRecipe],
        pantry: PantrySnapshot,
        index: IngredientIndex,
        stores: [StoreSnapshot],
        includeStaples: Bool = true
    ) -> [GroceryLine] {
        var totals: [String: Quantity] = [:]        // folded catalog name → needed
        var names: [String: String] = [:]           // folded → catalog spelling
        var neededFor: [String: Set<String>] = [:]

        for meal in meals {
            let scaled = Scaling.scale(meal.ingredients, from: meal.recipeServings, to: meal.servings)
            for item in scaled {
                let canonical = index.canonicalName(for: item.ingredientName)
                let key = Ingredient.fold(canonical)
                names[key] = canonical
                neededFor[key, default: []].insert(meal.title)
                let quantity = Quantity(item.quantity, item.unit).canonical
                let density = index.facts(for: item.ingredientName)?.gramsPerTeaspoon
                if let existing = totals[key],
                   let combined = Units.add(existing, quantity, gramsPerTeaspoon: density) {
                    totals[key] = combined
                } else if totals[key] == nil {
                    totals[key] = quantity
                }
            }
        }

        // Subtract what the household already has.
        var lines: [GroceryLine] = []
        for (key, needed) in totals {
            let name = names[key] ?? key
            var outstanding = needed
            let facts = index.facts(for: name)
            if let stock = pantry.stock(for: name),
               let remaining = Units.subtract(needed, Quantity(stock.quantity, stock.unit),
                                              gramsPerTeaspoon: facts?.gramsPerTeaspoon) {
                outstanding = remaining
            }
            guard outstanding.amount > 0.0001 else { continue }
            lines.append(
                GroceryLine(
                    ingredientName: name,
                    quantity: outstanding.amount,
                    unit: outstanding.unit,
                    category: facts?.category ?? .other,
                    storeID: store(for: facts?.category ?? .other, in: stores)?.id,
                    neededFor: neededFor[key]?.sorted() ?? [],
                    isStapleTopUp: false
                )
            )
        }

        if includeStaples {
            lines.append(contentsOf: stapleTopUps(index: index, pantry: pantry, stores: stores,
                                                  alreadyListed: Set(lines.map { Ingredient.fold($0.ingredientName) })))
        }

        // Stable order: by store position, then category, then name (SPEC R5).
        let storeOrder = Dictionary(uniqueKeysWithValues: stores.map { ($0.id, $0.sortOrder) })
        return lines.sorted { left, right in
            let leftStore = left.storeID.flatMap { storeOrder[$0] } ?? Int.max
            let rightStore = right.storeID.flatMap { storeOrder[$0] } ?? Int.max
            if leftStore != rightStore { return leftStore < rightStore }
            if left.category != right.category {
                return categoryOrder(left.category) < categoryOrder(right.category)
            }
            return left.ingredientName.localizedCaseInsensitiveCompare(right.ingredientName) == .orderedAscending
        }
    }

    /// Weekly staples the household is out of, or below their own threshold for.
    private static func stapleTopUps(
        index: IngredientIndex,
        pantry: PantrySnapshot,
        stores: [StoreSnapshot],
        alreadyListed: Set<String>
    ) -> [GroceryLine] {
        var lines: [GroceryLine] = []
        for facts in index.allFacts where facts.isStaple {
            let key = Ingredient.fold(facts.name)
            guard !alreadyListed.contains(key) else { continue }

            if let stock = pantry.stock(for: facts.name) {
                if let threshold = stock.lowThreshold {
                    guard stock.quantity <= threshold else { continue }
                } else {
                    guard stock.quantity <= 0 else { continue }
                }
            }

            let pack = staplePackSize(for: facts)
            lines.append(
                GroceryLine(
                    ingredientName: facts.name,
                    quantity: pack.amount,
                    unit: pack.unit,
                    category: facts.category,
                    storeID: store(for: facts.category, in: stores)?.id,
                    neededFor: [],
                    isStapleTopUp: true
                )
            )
        }
        return lines
    }

    /// Where a category is normally bought: a speciality store that claims it, else the first
    /// preferred general store, else nowhere in particular.
    static func store(for category: IngredientCategory, in stores: [StoreSnapshot]) -> StoreSnapshot? {
        let preferred = stores.filter(\.isPreferred).sorted { $0.sortOrder < $1.sortOrder }
        if let speciality = preferred.first(where: { !$0.kind.isGeneral && $0.affinities.contains(category) }) {
            return speciality
        }
        if let general = preferred.first(where: { $0.kind.isGeneral && $0.affinities.contains(category) }) {
            return general
        }
        return preferred.first { $0.kind.isGeneral }
    }

    // MARK: - Merging

    /// What to do to an existing list to bring it in line with a freshly built one.
    struct MergePlan: Equatable, Sendable {
        struct Update: Equatable, Sendable {
            var ingredientName: String
            var quantity: Double
            var unit: MeasurementUnit
            var storeID: String?
            var neededFor: [String]
            var isStapleTopUp: Bool
        }

        var inserts: [GroceryLine] = []
        var updates: [Update] = []
        /// Ingredient names to take off the list.
        var removals: [String] = []
    }

    /// Merges a freshly built list into what is already there.
    ///
    /// Anything ticked off has been bought and is left exactly as it is; anything the household
    /// typed in themselves stays. Rebuilding the same plan twice is a no-op (SPEC §4.4).
    static func merge(_ built: [GroceryLine], into existing: [ExistingGroceryLine]) -> MergePlan {
        var plan = MergePlan()
        let existingByName = Dictionary(
            existing.map { (Ingredient.fold($0.ingredientName), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let builtKeys = Set(built.map { Ingredient.fold($0.ingredientName) })

        for line in built {
            let key = Ingredient.fold(line.ingredientName)
            guard let current = existingByName[key] else {
                plan.inserts.append(line)
                continue
            }
            guard !current.isChecked else { continue }
            let sameQuantity = current.unit == line.unit && abs(current.quantity - line.quantity) < 0.0001
            let sameReasons = current.neededFor == line.neededFor
            if !sameQuantity || !sameReasons {
                plan.updates.append(
                    MergePlan.Update(
                        ingredientName: line.ingredientName,
                        quantity: line.quantity,
                        unit: line.unit,
                        storeID: line.storeID,
                        neededFor: line.neededFor,
                        isStapleTopUp: line.isStapleTopUp
                    )
                )
            }
        }

        for item in existing {
            let key = Ingredient.fold(item.ingredientName)
            guard !builtKeys.contains(key), !item.isChecked, !item.addedManually else { continue }
            plan.removals.append(item.ingredientName)
        }
        plan.removals.sort()
        return plan
    }

    /// The order categories appear in a shop, roughly produce-first.
    private static func categoryOrder(_ category: IngredientCategory) -> Int {
        IngredientCategory.allCases.firstIndex(of: category) ?? IngredientCategory.allCases.count
    }
}
