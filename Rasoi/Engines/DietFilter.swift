import Foundation

/// Decides whether a recipe may be shown or planned at all (SPEC §5).
///
/// Rules are applied in a fixed order so the reason a household sees is always the same one, and
/// every check is general: nothing here knows about a particular recipe.
enum DietFilter {
    /// Words that can never appear in a vegetarian kitchen. The seeded catalog contains none of
    /// them (SPEC R4); this is a backstop for recipes the household writes themselves.
    static let nonVegetarianWords = [
        "chicken", "beef", "pork", "fish", "shrimp", "prawn", "crab", "mutton", "lamb",
        "bacon", "ham", "turkey", "anchovy", "gelatin", "salmon", "tuna", "sausage",
    ]

    static func eligible(
        _ recipe: RecipeSummary,
        rules: DietRules,
        index: IngredientIndex,
        youngestAgeYears: Int
    ) -> Bool {
        reasonRejected(recipe, rules: rules, index: index, youngestAgeYears: youngestAgeYears) == nil
    }

    /// The recipes that pass, in the order they were given.
    static func eligible(
        _ recipes: [RecipeSummary],
        rules: DietRules,
        index: IngredientIndex,
        youngestAgeYears: Int
    ) -> [RecipeSummary] {
        recipes.filter { eligible($0, rules: rules, index: index, youngestAgeYears: youngestAgeYears) }
    }

    /// Why a recipe is not on the table, phrased for the UI — neutral, never a judgement.
    /// `nil` means it is eligible.
    static func reasonRejected(
        _ recipe: RecipeSummary,
        rules: DietRules,
        index: IngredientIndex,
        youngestAgeYears: Int
    ) -> String? {
        // Only required ingredients decide: an optional garnish can be left out.
        let required = recipe.requiredIngredients

        if rules.isVegetarian, containsNonVegetarianIngredient(in: required, index: index) {
            return "Not vegetarian"
        }
        if !rules.eggsOK, containsFlagged(recipe, required, index, \.containsEgg, recipe.containsEgg) {
            return "Has egg"
        }
        if !rules.dairyOK, containsFlagged(recipe, required, index, \.containsDairy, recipe.containsDairy) {
            return "Has dairy"
        }
        if rules.nutFree, containsFlagged(recipe, required, index, \.containsNuts, recipe.containsNuts) {
            return "Has nuts"
        }
        if rules.glutenFree, containsFlagged(recipe, required, index, \.containsGluten, recipe.containsGluten) {
            return "Has gluten"
        }
        if let excluded = excludedIngredient(in: required, rules: rules, index: index) {
            return "You've excluded \(excluded)"
        }
        if let missing = missingAppliance(for: recipe, rules: rules) {
            return "Needs \(missing.article) \(missing.label)"
        }
        if recipe.minAgeYears > youngestAgeYears {
            return "Better from age \(recipe.minAgeYears)"
        }
        return nil
    }

    // MARK: - Individual rules

    private static func containsNonVegetarianIngredient(
        in ingredients: [RecipeIngredient],
        index: IngredientIndex
    ) -> Bool {
        ingredients.contains { line in
            let name = Ingredient.fold(index.canonicalName(for: line.ingredientName))
            return nonVegetarianWords.contains { name.contains($0) }
        }
    }

    /// A recipe carries its own allergen flags; the catalog is consulted as well so a recipe that
    /// forgot to set one is still caught.
    private static func containsFlagged(
        _ recipe: RecipeSummary,
        _ ingredients: [RecipeIngredient],
        _ index: IngredientIndex,
        _ flag: KeyPath<IngredientFacts, Bool>,
        _ recipeFlag: Bool
    ) -> Bool {
        if recipeFlag { return true }
        return ingredients.contains { line in
            index.facts(for: line.ingredientName)?[keyPath: flag] == true
        }
    }

    /// The catalog name of the first excluded ingredient the recipe needs.
    private static func excludedIngredient(
        in ingredients: [RecipeIngredient],
        rules: DietRules,
        index: IngredientIndex
    ) -> String? {
        guard !rules.excludedIngredients.isEmpty else { return nil }
        // Exclusions are alias-aware in both directions: the household may type an alias, and the
        // recipe may use one.
        let excluded = Set(rules.excludedIngredients.map { Ingredient.fold(index.canonicalName(for: $0)) })
        for line in ingredients {
            let canonical = index.canonicalName(for: line.ingredientName)
            if excluded.contains(Ingredient.fold(canonical)) {
                return canonical
            }
        }
        return nil
    }

    private static func missingAppliance(for recipe: RecipeSummary, rules: DietRules) -> Appliance? {
        Appliance.allCases.first { recipe.appliances.contains($0) && !rules.appliances.contains($0) }
    }
}

private extension Appliance {
    /// "a Vitamix", "an oven" — used in the rejection reason.
    var article: String {
        let vowels: Set<Character> = ["a", "e", "i", "o", "u"]
        guard let initial = label.lowercased().first else { return "a" }
        return vowels.contains(initial) ? "an" : "a"
    }
}
