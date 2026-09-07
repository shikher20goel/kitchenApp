import Foundation
import SwiftData

/// Today (SPEC §4.1): tonight's dinner, the rest of the day, what needs using up, and three easy
/// snacks.
@MainActor
@Observable
final class TodayViewModel {
    private let context: ModelContext
    private let now: () -> Date

    private(set) var slots: [MealSlot] = []
    private(set) var expiringItems: [PantryItem] = []
    private(set) var snacks: [SnackSuggestion] = []
    private(set) var coverage: DayCoverage = DayCoverage(date: .distantPast, covered: [], hasWholeGrain: false)
    /// Built by `load()`. The banner reads the whole recipe catalog, which must not happen inside
    /// a view body.
    private(set) var expiringHeadline: String?

    init(context: ModelContext, now: @escaping () -> Date = { .now }) {
        self.context = context
        self.now = now
        load()
    }

    var today: Date { Calendar.rasoi.startOfDay(for: now()) }

    func load() {
        let plan = MealPlan.plan(forWeekContaining: today, in: context)
        slots = plan.slots(on: today)

        let pantryItems = (try? context.fetch(FetchDescriptor<PantryItem>())) ?? []
        expiringItems = pantryItems
            .filter { $0.quantity > 0 && $0.isExpiringSoon(on: now()) }
            .sorted { ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture) }

        let ingredients = (try? context.fetch(FetchDescriptor<Ingredient>())) ?? []
        let index = IngredientIndex(ingredients: ingredients)
        let recipes = ((try? context.fetch(FetchDescriptor<Recipe>())) ?? [])
            .filter { !$0.isHidden }
            .map(RecipeSummary.init(recipe:))

        snacks = QuickSnacks.suggestions(
            pantry: PantrySnapshot(pantryItems: pantryItems),
            index: index,
            recipes: recipes,
            on: now()
        )

        coverage = NutritionCoverage.day(
            slots.compactMap(\.recipe).map(RecipeSummary.init(recipe:)),
            on: today,
            index: index
        )
        expiringHeadline = makeExpiringHeadline(recipes: recipes)
    }

    func slot(_ mealType: MealType) -> MealSlot? {
        slots.first { $0.mealType == mealType }
    }

    var dinner: MealSlot? { slot(.dinner) }

    var otherMeals: [MealSlot] {
        slots.filter { $0.mealType != .dinner }
            .sorted { $0.mealType.sortOrder < $1.mealType.sortOrder }
    }

    var hasPlanForToday: Bool { slots.contains { $0.recipe != nil } }

    // MARK: - Expiring soon

    /// "Use the spinach: 2 recipes" — how many eligible recipes use an expiring ingredient.
    func recipeCount(using item: PantryItem) -> Int {
        guard let name = item.ingredient?.name else { return 0 }
        let recipes = ((try? context.fetch(FetchDescriptor<Recipe>())) ?? [])
            .filter { !$0.isHidden }
            .map(RecipeSummary.init(recipe:))
        return recipeCount(using: item, recipes: recipes)
    }

    private func recipeCount(using item: PantryItem, recipes: [RecipeSummary]) -> Int {
        guard let name = item.ingredient?.name else { return 0 }
        let folded = Ingredient.fold(name)
        return recipes.filter { recipe in
            recipe.ingredients.contains { Ingredient.fold($0.ingredientName) == folded }
        }.count
    }

    private func makeExpiringHeadline(recipes: [RecipeSummary]) -> String? {
        guard let first = expiringItems.first, let name = first.ingredient?.name else { return nil }
        let count = recipeCount(using: first, recipes: recipes)
        let others = expiringItems.count - 1
        var text = count > 0 ? "Use the \(name.lowercased()): \(count) recipe\(count == 1 ? "" : "s")"
                             : "Use the \(name.lowercased()) soon"
        if others > 0 {
            text += " · \(others) more item\(others == 1 ? "" : "s") to use"
        }
        return text
    }

    // MARK: - Cooking

    /// Marks a meal cooked. The feedback sheet is what draws the pantry down, so this only
    /// records the status when nobody is going to be asked.
    func markCooked(_ slot: MealSlot, depleting: Bool = false) {
        guard slot.status != .cooked else { return }
        slot.status = .cooked
        if depleting {
            PantryDepletion.apply(slot: slot, in: context)
        }
        try? context.save()
        load()
    }

    func setServings(_ servings: Int, for slot: MealSlot) {
        slot.servings = max(1, servings)
        try? context.save()
    }

    func recipe(withPlannerID id: String) -> Recipe? {
        ((try? context.fetch(FetchDescriptor<Recipe>())) ?? [])
            .first { RecipeSummary(recipe: $0).id == id }
    }
}
