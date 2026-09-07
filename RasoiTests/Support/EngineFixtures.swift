import Foundation
@testable import Rasoi

/// Plain-struct fixtures for the engines. No SwiftData: engines work on snapshots, so their tests
/// stay fast and deterministic.
enum Fixtures {
    static func facts(
        _ name: String,
        aliases: [String] = [],
        category: IngredientCategory = .vegetable,
        unit: MeasurementUnit = .gram,
        shelfLifeDays: Int = 7,
        isStaple: Bool = false,
        storeKind: StoreKind = .supermarket,
        nutritionTags: [String] = [],
        egg: Bool = false,
        dairy: Bool = false,
        nuts: Bool = false,
        gluten: Bool = false,
        quickSnack: Bool = false
    ) -> IngredientFacts {
        IngredientFacts(
            name: name,
            aliases: aliases,
            category: category,
            defaultUnit: unit,
            typicalShelfLifeDays: shelfLifeDays,
            isStaple: isStaple,
            defaultStoreKind: storeKind,
            nutritionTags: nutritionTags,
            containsEgg: egg,
            containsDairy: dairy,
            containsNuts: nuts,
            containsGluten: gluten,
            isQuickHealthySnack: quickSnack
        )
    }

    /// A small catalog covering every flag the diet filter looks at.
    static let index = IngredientIndex(facts: [
        facts("Spinach", aliases: ["palak", "baby spinach"], category: .leafyGreen,
              nutritionTags: ["iron", "vegetable"]),
        facts("Paneer", aliases: ["cottage cheese"], category: .dairy,
              nutritionTags: ["protein", "calcium"], dairy: true),
        facts("Milk", category: .dairy, unit: .millilitre, nutritionTags: ["calcium"], dairy: true),
        facts("Egg", category: .egg, unit: .count, nutritionTags: ["protein"], egg: true),
        facts("Cashews", category: .nutSeed, nutritionTags: ["healthyFat"], nuts: true),
        facts("Whole wheat pasta", category: .grain, nutritionTags: ["grain", "wholeGrain"], gluten: true),
        facts("Toor dal", aliases: ["arhar dal"], category: .legume, isStaple: true,
              storeKind: .indian, nutritionTags: ["protein", "iron"]),
        facts("Rice", category: .grain, isStaple: true, nutritionTags: ["grain"]),
        facts("Tomato", category: .vegetable, nutritionTags: ["vegetable", "vitaminC"]),
        facts("Banana", category: .fruit, unit: .count, nutritionTags: ["fruit"], quickSnack: true),
        facts("Mushroom", category: .vegetable, nutritionTags: ["vegetable"]),
    ])

    static func recipe(
        id: String,
        title: String? = nil,
        cuisine: String = "Indian",
        mealTypes: Set<MealType> = [.dinner],
        appliances: Set<Appliance> = [.stovetop],
        prepMinutes: Int = 10,
        cookMinutes: Int = 15,
        servings: Int = 4,
        minAgeYears: Int = 2,
        ingredients: [(String, Double, MeasurementUnit, Bool)] = [("Rice", 200, .gram, false)],
        nutritionTags: [String] = [],
        egg: Bool = false,
        dairy: Bool = false,
        nuts: Bool = false,
        gluten: Bool = false,
        kidBaseline: Int = 3,
        isFavorite: Bool = false,
        isHidden: Bool = false,
        lunchboxOK: Bool = false
    ) -> RecipeSummary {
        RecipeSummary(
            id: id,
            seedID: id,
            title: title ?? id,
            cuisine: cuisine,
            mealTypes: mealTypes,
            appliances: appliances,
            prepMinutes: prepMinutes,
            cookMinutes: cookMinutes,
            servings: servings,
            minAgeYears: minAgeYears,
            ingredients: ingredients.map {
                RecipeIngredient(ingredientName: $0.0, quantity: $0.1, unit: $0.2, isOptional: $0.3)
            },
            nutritionTags: nutritionTags,
            containsEgg: egg,
            containsDairy: dairy,
            containsNuts: nuts,
            containsGluten: gluten,
            kidBaseline: kidBaseline,
            isFavorite: isFavorite,
            isHidden: isHidden,
            lunchboxOK: lunchboxOK
        )
    }
}
