import Foundation
import SwiftData

/// Puts the bundled catalog into SwiftData, and keeps it there across updates.
///
/// The import is an upsert keyed by ingredient name and recipe `seedID`, so running it twice
/// changes nothing (SPEC R6). Household state — favourites, hidden recipes, everything the user
/// wrote — is never overwritten or deleted.
enum SeedImporter {
    struct Result: Equatable, Sendable {
        var ingredientsInserted = 0
        var ingredientsUpdated = 0
        var recipesInserted = 0
        var recipesUpdated = 0
        var skipped = false

        static let skippedResult = Result(skipped: true)
    }

    /// Imports only when the bundled catalog is newer than what has already been applied.
    @discardableResult
    @MainActor
    static func importIfNeeded(in context: ModelContext, bundle: Bundle = .main) throws -> Result {
        let profile = DietProfile.current(in: context)
        let version = try SeedLoader.loadRecipes(from: bundle).version
        guard profile.seedVersion < version else { return .skippedResult }
        return try reimport(in: context, bundle: bundle)
    }

    /// Applies the bundled catalog whatever the recorded version, upserting every row.
    @discardableResult
    @MainActor
    static func reimport(in context: ModelContext, bundle: Bundle = .main) throws -> Result {
        let ingredientFile = try SeedLoader.loadIngredients(from: bundle)
        let recipeFile = try SeedLoader.loadRecipes(from: bundle)
        var result = Result()

        var ingredientsByName: [String: Ingredient] = [:]
        for ingredient in try context.fetch(FetchDescriptor<Ingredient>()) {
            ingredientsByName[Ingredient.fold(ingredient.name)] = ingredient
        }

        for dto in ingredientFile.ingredients {
            if let existing = ingredientsByName[Ingredient.fold(dto.name)] {
                apply(dto, to: existing)
                result.ingredientsUpdated += 1
            } else {
                let ingredient = make(dto)
                context.insert(ingredient)
                ingredientsByName[Ingredient.fold(dto.name)] = ingredient
                result.ingredientsInserted += 1
            }
        }

        var recipesBySeedID: [String: Recipe] = [:]
        for recipe in try context.fetch(FetchDescriptor<Recipe>()) {
            if let seedID = recipe.seedID {
                recipesBySeedID[seedID] = recipe
            }
        }

        for dto in recipeFile.recipes {
            if let existing = recipesBySeedID[dto.seedID] {
                // A recipe the household has edited is theirs now; the seed does not overwrite it.
                if !existing.isUserEdited {
                    apply(dto, to: existing)
                }
                result.recipesUpdated += 1
            } else {
                let recipe = make(dto)
                context.insert(recipe)
                recipesBySeedID[dto.seedID] = recipe
                result.recipesInserted += 1
            }
        }

        DietProfile.current(in: context).seedVersion = recipeFile.version
        try context.save()
        return result
    }

    // MARK: - Mapping

    private static func make(_ dto: IngredientDTO) -> Ingredient {
        let ingredient = Ingredient(
            name: dto.name,
            category: IngredientCategory(rawValue: dto.category) ?? .other,
            defaultUnit: MeasurementUnit(rawValue: dto.defaultUnit) ?? .gram,
            typicalShelfLifeDays: dto.typicalShelfLifeDays
        )
        apply(dto, to: ingredient)
        return ingredient
    }

    /// Catalog facts are refreshed from the seed; nothing here is user-owned.
    private static func apply(_ dto: IngredientDTO, to ingredient: Ingredient) {
        ingredient.name = dto.name
        ingredient.aliases = dto.aliases
        ingredient.category = IngredientCategory(rawValue: dto.category) ?? .other
        ingredient.defaultUnit = MeasurementUnit(rawValue: dto.defaultUnit) ?? .gram
        ingredient.typicalShelfLifeDays = dto.typicalShelfLifeDays
        ingredient.isStaple = dto.isStaple
        ingredient.defaultStoreKind = StoreKind(rawValue: dto.defaultStoreKind) ?? .supermarket
        ingredient.nutritionTags = dto.nutritionTags
        ingredient.containsEgg = dto.containsEgg
        ingredient.containsDairy = dto.containsDairy
        ingredient.containsNuts = dto.containsNuts
        ingredient.containsGluten = dto.containsGluten
        ingredient.isQuickHealthySnack = dto.isQuickHealthySnack
    }

    private static func make(_ dto: RecipeDTO) -> Recipe {
        let recipe = Recipe(
            title: dto.title,
            cuisine: dto.cuisine,
            mealTypes: dto.mealTypes.compactMap(MealType.init(rawValue:)),
            appliances: dto.appliances.compactMap(Appliance.init(rawValue:)),
            prepMinutes: dto.prepMinutes,
            cookMinutes: dto.cookMinutes,
            servings: dto.servings,
            minAgeYears: dto.minAgeYears,
            ingredients: dto.ingredients.map(ingredientLine),
            steps: dto.steps,
            source: .seed,
            seedID: dto.seedID
        )
        apply(dto, to: recipe)
        return recipe
    }

    /// Puts a seeded recipe back the way it shipped, discarding the household's edits.
    @MainActor
    static func restoreFromSeed(_ recipe: Recipe, in context: ModelContext, bundle: Bundle = .main) throws {
        guard let seedID = recipe.seedID else { return }
        guard let dto = try SeedLoader.loadRecipes(from: bundle).recipes.first(where: { $0.seedID == seedID })
        else { return }
        apply(dto, to: recipe)
        recipe.isUserEdited = false
        try context.save()
    }

    /// Recipe content comes from the seed; `isFavorite` and `isHidden` belong to the household and
    /// are deliberately left alone (SPEC R6).
    private static func apply(_ dto: RecipeDTO, to recipe: Recipe) {
        recipe.title = dto.title
        recipe.cuisine = dto.cuisine
        recipe.mealTypes = dto.mealTypes.compactMap(MealType.init(rawValue:))
        recipe.appliances = dto.appliances
        recipe.prepMinutes = dto.prepMinutes
        recipe.cookMinutes = dto.cookMinutes
        recipe.servings = dto.servings
        recipe.minAgeYears = dto.minAgeYears
        recipe.ingredients = dto.ingredients.map(ingredientLine)
        recipe.steps = dto.steps
        recipe.nutritionTags = dto.nutritionTags
        recipe.containsEgg = dto.containsEgg
        recipe.containsDairy = dto.containsDairy
        recipe.containsNuts = dto.containsNuts
        recipe.containsGluten = dto.containsGluten
        recipe.kidBaseline = dto.kidBaseline
        recipe.kidFriendlyNote = dto.kidFriendlyNote
        recipe.lunchboxOK = dto.lunchboxOK
        recipe.sourceNote = dto.sourceNote ?? ""
        recipe.sourceURL = dto.sourceURL ?? ""
        recipe.source = .seed
        recipe.seedID = dto.seedID
    }

    private static func ingredientLine(_ dto: RecipeIngredientDTO) -> RecipeIngredient {
        RecipeIngredient(
            ingredientName: dto.ingredientName,
            quantity: dto.quantity,
            unit: MeasurementUnit(rawValue: dto.unit) ?? .gram,
            isOptional: dto.isOptional,
            note: dto.note
        )
    }
}
