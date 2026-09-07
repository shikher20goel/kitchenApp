import Foundation
import SwiftData

/// A recipe being written or edited. A plain value so validation and the derived allergen flags
/// can be tested without a store.
struct RecipeDraft: Equatable, Sendable {
    var title: String = ""
    var cuisine: String = "Indian"
    var mealTypes: Set<MealType> = [.dinner]
    var appliances: Set<Appliance> = [.stovetop]
    var prepMinutes: Int = 10
    var cookMinutes: Int = 20
    var servings: Int = 4
    var minAgeYears: Int = 1
    var ingredients: [RecipeIngredient] = []
    var steps: [String] = []
    var kidFriendlyNote: String = ""
    var lunchboxOK: Bool = false

    init() {}

    init(recipe: Recipe) {
        title = recipe.title
        cuisine = recipe.cuisine
        mealTypes = Set(recipe.mealTypes)
        appliances = recipe.applianceSet
        prepMinutes = recipe.prepMinutes
        cookMinutes = recipe.cookMinutes
        servings = recipe.servings
        minAgeYears = recipe.minAgeYears
        ingredients = recipe.ingredients
        steps = recipe.steps
        kidFriendlyNote = recipe.kidFriendlyNote
        lunchboxOK = recipe.lunchboxOK
    }

    /// Allergen flags a recipe carries, worked out from its ingredients rather than typed by hand.
    struct DerivedFlags: Equatable, Sendable {
        var containsEgg = false
        var containsDairy = false
        var containsNuts = false
        var containsGluten = false
        /// Food-group and nutrient tags collected from the ingredients, in catalog order.
        var nutritionTags: [String] = []
    }

    /// Only required ingredients set a flag: an optional garnish can be left out, so flagging the
    /// recipe for it would hide a dish the household could happily make.
    func derivedFlags(using index: IngredientIndex) -> DerivedFlags {
        var flags = DerivedFlags()
        var tags: [String] = []
        for line in ingredients where !line.isOptional {
            guard let facts = index.facts(for: line.ingredientName) else { continue }
            flags.containsEgg = flags.containsEgg || facts.containsEgg
            flags.containsDairy = flags.containsDairy || facts.containsDairy
            flags.containsNuts = flags.containsNuts || facts.containsNuts
            flags.containsGluten = flags.containsGluten || facts.containsGluten
            for tag in facts.nutritionTags where !tags.contains(tag) {
                tags.append(tag)
            }
        }
        flags.nutritionTags = tags
        return flags
    }

    var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var nonEmptySteps: [String] {
        steps.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    var usableIngredients: [RecipeIngredient] {
        ingredients.filter {
            !$0.ingredientName.trimmingCharacters(in: .whitespaces).isEmpty && $0.quantity > 0
        }
    }

    /// Everything wrong with the draft, in the order the form shows it.
    var validationErrors: [String] {
        var errors: [String] = []
        if trimmedTitle.isEmpty { errors.append("Give the recipe a name.") }
        if usableIngredients.isEmpty { errors.append("Add at least one ingredient with a quantity.") }
        if nonEmptySteps.isEmpty { errors.append("Add at least one step.") }
        if mealTypes.isEmpty { errors.append("Choose at least one meal.") }
        if servings < 1 { errors.append("Servings must be at least one.") }
        return errors
    }

    var isValid: Bool { validationErrors.isEmpty }

    var totalMinutes: Int { prepMinutes + cookMinutes }
}

/// Creates and updates the household's own recipes (SPEC §4.5).
@MainActor
@Observable
final class RecipeEditorViewModel {
    private let context: ModelContext
    /// The recipe being edited, or nil when writing a new one.
    private let existing: Recipe?

    var draft: RecipeDraft

    init(context: ModelContext, recipe: Recipe? = nil) {
        self.context = context
        self.existing = recipe
        self.draft = recipe.map(RecipeDraft.init(recipe:)) ?? RecipeDraft()
    }

    var isEditing: Bool { existing != nil }

    var index: IngredientIndex {
        IngredientIndex(ingredients: (try? context.fetch(FetchDescriptor<Ingredient>())) ?? [])
    }

    /// Catalog type-ahead for an ingredient row.
    func ingredientSuggestions(for query: String) -> [Ingredient] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return [] }
        let catalog = (try? context.fetch(FetchDescriptor<Ingredient>())) ?? []
        return Ingredient.search(trimmed, in: catalog, limit: 6)
    }

    var cuisines: [String] {
        let fromCatalog = (try? context.fetch(FetchDescriptor<Recipe>()))?.map(\.cuisine) ?? []
        return Set(fromCatalog + DietProfile.defaultCuisines).filter { !$0.isEmpty }.sorted()
    }

    /// Writes the draft. Returns nil (changing nothing) when the draft is not valid.
    @discardableResult
    func save() -> Recipe? {
        guard draft.isValid else { return nil }
        let flags = draft.derivedFlags(using: index)
        // Ingredient names are stored in the catalog's own spelling so every join lines up.
        let lines = draft.usableIngredients.map { line -> RecipeIngredient in
            var copy = line
            copy.ingredientName = index.canonicalName(for: line.ingredientName)
            return copy
        }

        let recipe = existing ?? Recipe(
            title: draft.trimmedTitle,
            cuisine: draft.cuisine,
            mealTypes: [],
            appliances: [],
            prepMinutes: 0,
            cookMinutes: 0,
            servings: draft.servings,
            minAgeYears: draft.minAgeYears,
            ingredients: [],
            steps: [],
            source: .user,
            seedID: nil
        )

        recipe.title = draft.trimmedTitle
        recipe.cuisine = draft.cuisine
        recipe.mealTypes = MealType.allCases.filter(draft.mealTypes.contains)
        recipe.applianceSet = draft.appliances
        recipe.prepMinutes = max(0, draft.prepMinutes)
        recipe.cookMinutes = max(0, draft.cookMinutes)
        recipe.servings = draft.servings
        recipe.minAgeYears = draft.minAgeYears
        recipe.ingredients = lines
        recipe.steps = draft.nonEmptySteps
        recipe.kidFriendlyNote = draft.kidFriendlyNote.trimmingCharacters(in: .whitespacesAndNewlines)
        recipe.lunchboxOK = draft.lunchboxOK
        recipe.containsEgg = flags.containsEgg
        recipe.containsDairy = flags.containsDairy
        recipe.containsNuts = flags.containsNuts
        recipe.containsGluten = flags.containsGluten
        recipe.nutritionTags = flags.nutritionTags

        if existing == nil {
            context.insert(recipe)
        }
        try? context.save()
        return recipe
    }
}
