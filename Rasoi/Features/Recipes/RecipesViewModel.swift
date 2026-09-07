import Foundation
import SwiftData

/// Browsing and searching the recipe catalog (SPEC §4.5).
///
/// By default the list shows what this household can actually cook tonight: the diet filter and
/// the household's hidden recipes are applied. "Show everything" reveals the rest, each with the
/// plain reason it was left out.
@MainActor
@Observable
final class RecipesViewModel {
    private let context: ModelContext
    private let now: () -> Date

    var searchText: String = ""
    var mealType: MealType?
    var cuisine: String?
    var appliance: Appliance?
    var quickOnly = false
    var favouritesOnly = false
    var lunchboxOnly = false
    /// Shows recipes the diet filter rules out, each labelled with why.
    var showsEverything = false

    private(set) var allRecipes: [Recipe] = []
    private var index = IngredientIndex(facts: [])
    private var rules = DietRules()
    private var youngestAgeYears = Int.max

    init(context: ModelContext, now: @escaping () -> Date = { .now }) {
        self.context = context
        self.now = now
        load()
    }

    func load() {
        allRecipes = (try? context.fetch(FetchDescriptor<Recipe>(sortBy: [SortDescriptor(\.title)]))) ?? []
        index = IngredientIndex(ingredients: (try? context.fetch(FetchDescriptor<Ingredient>())) ?? [])
        rules = DietRules(profile: DietProfile.current(in: context))

        let members = (try? context.fetch(FetchDescriptor<HouseholdMember>())) ?? []
        let today = now()
        youngestAgeYears = members.filter(\.isActive).map { $0.ageYears(on: today) }.min() ?? Int.max
    }

    /// The recipes to show, filtered and ordered by title.
    var results: [Recipe] {
        allRecipes.filter { matchesFilters($0) && (showsEverything || isAvailable($0)) }
    }

    /// Every cuisine present in the catalog, for the filter row.
    var cuisines: [String] {
        Array(Set(allRecipes.map(\.cuisine))).filter { !$0.isEmpty }.sorted()
    }

    var hasActiveFilters: Bool {
        mealType != nil || cuisine != nil || appliance != nil || quickOnly || favouritesOnly
            || lunchboxOnly || !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func clearFilters() {
        searchText = ""
        mealType = nil
        cuisine = nil
        appliance = nil
        quickOnly = false
        favouritesOnly = false
        lunchboxOnly = false
    }

    // MARK: - Availability

    /// Whether the household can cook this today: not hidden, and past the diet filter.
    func isAvailable(_ recipe: Recipe) -> Bool {
        unavailableReason(for: recipe) == nil
    }

    /// Plain reason a recipe is not in the default list, or nil when it is.
    func unavailableReason(for recipe: Recipe) -> String? {
        if recipe.isHidden { return "Hidden by you" }
        return DietFilter.reasonRejected(
            RecipeSummary(recipe: recipe),
            rules: rules,
            index: index,
            youngestAgeYears: youngestAgeYears
        )
    }

    // MARK: - Filtering

    private func matchesFilters(_ recipe: Recipe) -> Bool {
        if let mealType, !recipe.serves(mealType) { return false }
        if let cuisine, recipe.cuisine != cuisine { return false }
        if let appliance, !recipe.applianceSet.contains(appliance) { return false }
        if quickOnly, !recipe.isQuick { return false }
        if favouritesOnly, !recipe.isFavorite { return false }
        if lunchboxOnly, !recipe.lunchboxOK { return false }

        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return matches(recipe, query: query)
    }

    /// Search covers the title, the cuisine and the ingredient list — including aliases, so
    /// "palak" finds the spinach dishes.
    private func matches(_ recipe: Recipe, query: String) -> Bool {
        let needle = Ingredient.fold(query)
        if Ingredient.fold(recipe.title).contains(needle) { return true }
        if Ingredient.fold(recipe.cuisine).contains(needle) { return true }
        return recipe.ingredients.contains { line in
            let canonical = Ingredient.fold(index.canonicalName(for: line.ingredientName))
            if canonical.contains(needle) || Ingredient.fold(line.ingredientName).contains(needle) {
                return true
            }
            let aliases = index.facts(for: line.ingredientName)?.aliases ?? []
            return aliases.contains { Ingredient.fold($0).contains(needle) }
        }
    }

    // MARK: - Household actions

    func toggleFavorite(_ recipe: Recipe) {
        recipe.isFavorite.toggle()
        save()
    }

    func toggleHidden(_ recipe: Recipe) {
        recipe.isHidden.toggle()
        save()
    }

    /// Which of a recipe's ingredients are already in the kitchen, by catalog name.
    func pantryCoverage(for recipe: Recipe) -> Set<String> {
        let stocked = ((try? context.fetch(FetchDescriptor<PantryItem>())) ?? [])
            .filter { $0.quantity > 0 }
            .compactMap { $0.ingredient?.name }
        return Set(stocked.map(Ingredient.fold))
    }

    func save() {
        try? context.save()
        load()
    }
}
