import Foundation

/// Wire shapes for `seed/ingredients.json` and `seed/recipes.json`. Keys mirror the JSON exactly;
/// vocabulary fields stay `String` here and are validated when they are mapped into models, so a
/// typo in the data is a test failure rather than a silent decode crash.
struct IngredientSeedFile: Codable, Sendable {
    var version: Int
    var ingredients: [IngredientDTO]
}

struct IngredientDTO: Codable, Sendable {
    var name: String
    var aliases: [String]
    var category: String
    var defaultUnit: String
    var typicalShelfLifeDays: Int
    var isStaple: Bool
    var defaultStoreKind: String
    var nutritionTags: [String]
    var containsEgg: Bool
    var containsDairy: Bool
    var containsNuts: Bool
    var containsGluten: Bool
    var isQuickHealthySnack: Bool
}

struct RecipeSeedFile: Codable, Sendable {
    var version: Int
    var recipes: [RecipeDTO]
}

struct RecipeDTO: Codable, Sendable {
    var seedID: String
    var title: String
    var cuisine: String
    var mealTypes: [String]
    var appliances: [String]
    var prepMinutes: Int
    var cookMinutes: Int
    var servings: Int
    var minAgeYears: Int
    var ingredients: [RecipeIngredientDTO]
    var steps: [String]
    var nutritionTags: [String]
    var isQuick: Bool
    var kidBaseline: Int
    var kidFriendlyNote: String
    var lunchboxOK: Bool
    var source: String
    var containsEgg: Bool
    var containsDairy: Bool
    var containsNuts: Bool
    var containsGluten: Bool
}

struct RecipeIngredientDTO: Codable, Sendable {
    var ingredientName: String
    var quantity: Double
    var unit: String
    var isOptional: Bool
    var note: String
}
