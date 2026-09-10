import Foundation
import SwiftData

/// A recipe, seeded or written by the household (SPEC §3).
///
/// Ingredients are a Codable value array rather than a relationship: a recipe's ingredient list is
/// a fixed part of the recipe, not shared state, and keeping it inline means the planner can work
/// on plain snapshots without touching SwiftData.
@Model
final class Recipe {
    var title: String = ""
    var cuisine: String = ""
    var mealTypeRaw: [String] = []
    var appliances: [String] = []
    var prepMinutes: Int = 0
    var cookMinutes: Int = 0
    var servings: Int = 4
    /// The youngest age this dish suits, in whole years.
    var minAgeYears: Int = 1
    var ingredients: [RecipeIngredient] = []
    var steps: [String] = []
    var nutritionTags: [String] = []
    var containsEgg: Bool = false
    var containsDairy: Bool = false
    var containsNuts: Bool = false
    var containsGluten: Bool = false
    /// Editorial "kids usually like this", 1–5. Only used until real feedback exists (SPEC §5).
    var kidBaseline: Int = 3
    /// How to make it work for a young child: mild spice, serve with yogurt, cut small.
    var kidFriendlyNote: String = ""
    var lunchboxOK: Bool = false
    var isFavorite: Bool = false
    var isHidden: Bool = false
    /// Where the recipe came from, e.g. "Adapted from Hebbar's Kitchen". Shown on the recipe.
    var sourceNote: String = ""
    /// The page it was adapted from, so the original is one tap away.
    var sourceURL: String = ""
    /// Set when the household edits a seeded recipe. A reseed then leaves their version alone,
    /// and "Restore original" is offered instead (SPEC R6).
    var isUserEdited: Bool = false
    var sourceRaw: String = RecipeSource.seed.rawValue
    /// Stable key for the seeded catalog; `nil` for recipes the household wrote.
    @Attribute(.unique) var seedID: String?

    init(
        title: String,
        cuisine: String,
        mealTypes: [MealType],
        appliances: [Appliance],
        prepMinutes: Int,
        cookMinutes: Int,
        servings: Int,
        minAgeYears: Int,
        ingredients: [RecipeIngredient],
        steps: [String],
        nutritionTags: [String] = [],
        containsEgg: Bool = false,
        containsDairy: Bool = false,
        containsNuts: Bool = false,
        containsGluten: Bool = false,
        kidBaseline: Int = 3,
        kidFriendlyNote: String = "",
        lunchboxOK: Bool = false,
        isFavorite: Bool = false,
        isHidden: Bool = false,
        sourceNote: String = "",
        sourceURL: String = "",
        source: RecipeSource = .seed,
        seedID: String? = nil
    ) {
        self.title = title
        self.cuisine = cuisine
        self.mealTypeRaw = mealTypes.map(\.rawValue)
        self.appliances = appliances.map(\.rawValue)
        self.prepMinutes = prepMinutes
        self.cookMinutes = cookMinutes
        self.servings = servings
        self.minAgeYears = minAgeYears
        self.ingredients = ingredients
        self.steps = steps
        self.nutritionTags = nutritionTags
        self.containsEgg = containsEgg
        self.containsDairy = containsDairy
        self.containsNuts = containsNuts
        self.containsGluten = containsGluten
        self.kidBaseline = kidBaseline
        self.kidFriendlyNote = kidFriendlyNote
        self.lunchboxOK = lunchboxOK
        self.isFavorite = isFavorite
        self.isHidden = isHidden
        self.sourceNote = sourceNote
        self.sourceURL = sourceURL
        self.sourceRaw = source.rawValue
        self.seedID = seedID
    }

    // MARK: - Vocabulary

    var mealTypes: [MealType] {
        get { mealTypeRaw.compactMap(MealType.init(rawValue:)) }
        set { mealTypeRaw = newValue.map(\.rawValue) }
    }

    var applianceSet: Set<Appliance> {
        get { Set(appliances.compactMap(Appliance.init(rawValue:))) }
        set { appliances = Appliance.allCases.filter(newValue.contains).map(\.rawValue) }
    }

    var source: RecipeSource {
        get { RecipeSource(rawValue: sourceRaw) ?? .seed }
        set { sourceRaw = newValue.rawValue }
    }

    // MARK: - Derived

    var totalMinutes: Int { prepMinutes + cookMinutes }

    /// 15 minutes or less, start to finish (SPEC §3).
    var isQuick: Bool { totalMinutes <= Recipe.quickThresholdMinutes }

    static let quickThresholdMinutes = 15

    var requiredIngredients: [RecipeIngredient] {
        ingredients.filter { !$0.isOptional }
    }

    func serves(_ mealType: MealType) -> Bool {
        mealTypeRaw.contains(mealType.rawValue)
    }

    func uses(ingredientNamed name: String) -> Bool {
        let folded = Ingredient.fold(name)
        return ingredients.contains { Ingredient.fold($0.ingredientName) == folded }
    }

    /// The ingredient list scaled from `servings` to `target`, for cook mode and the grocery list.
    func scaledIngredients(toServings target: Int) -> [RecipeIngredient] {
        guard servings > 0, target > 0, target != servings else { return ingredients }
        let factor = Double(target) / Double(servings)
        return ingredients.map { $0.scaled(by: factor) }
    }
}

/// One line of a recipe's ingredient list. A plain value: no SwiftData relationship, joined to the
/// catalog by `ingredientName`.
struct RecipeIngredient: Codable, Hashable, Sendable {
    var ingredientName: String
    var quantity: Double
    var unitRaw: String
    var isOptional: Bool
    var note: String

    init(ingredientName: String, quantity: Double, unit: MeasurementUnit,
         isOptional: Bool = false, note: String = "") {
        self.ingredientName = ingredientName
        self.quantity = quantity
        self.unitRaw = unit.rawValue
        self.isOptional = isOptional
        self.note = note
    }

    var unit: MeasurementUnit {
        get { MeasurementUnit(rawValue: unitRaw) ?? .gram }
        set { unitRaw = newValue.rawValue }
    }

    func scaled(by factor: Double) -> RecipeIngredient {
        var copy = self
        copy.quantity = quantity * factor
        return copy
    }
}

/// Which meal a recipe belongs to. Raw values match `seed/recipes.json`.
enum MealType: String, Codable, CaseIterable, Sendable {
    case breakfast
    case lunch
    case dinner
    case snack

    var label: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snack"
        }
    }

    var symbolName: String {
        switch self {
        case .breakfast: return "sunrise"
        case .lunch: return "sun.max"
        case .dinner: return "moon.stars"
        case .snack: return "carrot"
        }
    }

    /// The order meals appear in a day.
    var sortOrder: Int {
        switch self {
        case .breakfast: return 0
        case .lunch: return 1
        case .snack: return 2
        case .dinner: return 3
        }
    }
}

/// Where a recipe came from. User recipes are never touched by a reseed (SPEC R6).
enum RecipeSource: String, Codable, CaseIterable, Sendable {
    case seed
    case user
}
