import Foundation

/// Plain-value views of the SwiftData rows the engines work on.
///
/// Engines never touch SwiftData: a view model takes a snapshot, the engine reasons about it, and
/// the result is written back. That keeps planning deterministic (SPEC R5) and testable without a
/// store.

// MARK: - Recipes

struct RecipeSummary: Identifiable, Hashable, Sendable {
    /// Stable identity: the seedID for catalog recipes, a generated key for user recipes.
    var id: String
    var seedID: String?
    var title: String
    var cuisine: String
    var mealTypes: Set<MealType>
    var appliances: Set<Appliance>
    var prepMinutes: Int
    var cookMinutes: Int
    var servings: Int
    var minAgeYears: Int
    var ingredients: [RecipeIngredient]
    var nutritionTags: [String]
    var containsEgg: Bool
    var containsDairy: Bool
    var containsNuts: Bool
    var containsGluten: Bool
    var kidBaseline: Int
    var isFavorite: Bool
    var isHidden: Bool
    var lunchboxOK: Bool

    var totalMinutes: Int { prepMinutes + cookMinutes }
    var isQuick: Bool { totalMinutes <= Recipe.quickThresholdMinutes }
    var requiredIngredients: [RecipeIngredient] { ingredients.filter { !$0.isOptional } }

    func serves(_ mealType: MealType) -> Bool { mealTypes.contains(mealType) }
}

extension RecipeSummary {
    /// Snapshot of a stored recipe.
    init(recipe: Recipe) {
        self.init(
            id: recipe.seedID ?? "user:\(recipe.persistentModelID.hashValue)",
            seedID: recipe.seedID,
            title: recipe.title,
            cuisine: recipe.cuisine,
            mealTypes: Set(recipe.mealTypes),
            appliances: recipe.applianceSet,
            prepMinutes: recipe.prepMinutes,
            cookMinutes: recipe.cookMinutes,
            servings: recipe.servings,
            minAgeYears: recipe.minAgeYears,
            ingredients: recipe.ingredients,
            nutritionTags: recipe.nutritionTags,
            containsEgg: recipe.containsEgg,
            containsDairy: recipe.containsDairy,
            containsNuts: recipe.containsNuts,
            containsGluten: recipe.containsGluten,
            kidBaseline: recipe.kidBaseline,
            isFavorite: recipe.isFavorite,
            isHidden: recipe.isHidden,
            lunchboxOK: recipe.lunchboxOK
        )
    }
}

// MARK: - Ingredients

/// What the engines need to know about one catalog ingredient.
struct IngredientFacts: Hashable, Sendable {
    var name: String
    var aliases: [String] = []
    var category: IngredientCategory
    var defaultUnit: MeasurementUnit
    var typicalShelfLifeDays: Int
    var isStaple: Bool = false
    var defaultStoreKind: StoreKind = .supermarket
    var nutritionTags: [String] = []
    var containsEgg: Bool = false
    var containsDairy: Bool = false
    var containsNuts: Bool = false
    var containsGluten: Bool = false
    var isQuickHealthySnack: Bool = false

    init(ingredient: Ingredient) {
        self.init(
            name: ingredient.name,
            aliases: ingredient.aliases,
            category: ingredient.category,
            defaultUnit: ingredient.defaultUnit,
            typicalShelfLifeDays: ingredient.typicalShelfLifeDays,
            isStaple: ingredient.isStaple,
            defaultStoreKind: ingredient.defaultStoreKind,
            nutritionTags: ingredient.nutritionTags,
            containsEgg: ingredient.containsEgg,
            containsDairy: ingredient.containsDairy,
            containsNuts: ingredient.containsNuts,
            containsGluten: ingredient.containsGluten,
            isQuickHealthySnack: ingredient.isQuickHealthySnack
        )
    }

    init(
        name: String,
        aliases: [String] = [],
        category: IngredientCategory,
        defaultUnit: MeasurementUnit,
        typicalShelfLifeDays: Int,
        isStaple: Bool = false,
        defaultStoreKind: StoreKind = .supermarket,
        nutritionTags: [String] = [],
        containsEgg: Bool = false,
        containsDairy: Bool = false,
        containsNuts: Bool = false,
        containsGluten: Bool = false,
        isQuickHealthySnack: Bool = false
    ) {
        self.name = name
        self.aliases = aliases
        self.category = category
        self.defaultUnit = defaultUnit
        self.typicalShelfLifeDays = typicalShelfLifeDays
        self.isStaple = isStaple
        self.defaultStoreKind = defaultStoreKind
        self.nutritionTags = nutritionTags
        self.containsEgg = containsEgg
        self.containsDairy = containsDairy
        self.containsNuts = containsNuts
        self.containsGluten = containsGluten
        self.isQuickHealthySnack = isQuickHealthySnack
    }
}

/// Name-and-alias lookup over the catalog. Every engine resolves ingredient text through this, so
/// "palak", "Palak" and "Spinach" all reach the same row.
struct IngredientIndex: Sendable {
    private var byKey: [String: IngredientFacts] = [:]
    private var ordered: [IngredientFacts] = []

    init(facts: [IngredientFacts]) {
        ordered = facts
        for entry in facts {
            byKey[Ingredient.fold(entry.name)] = entry
            for alias in entry.aliases {
                // A canonical name always wins over another row's alias.
                let key = Ingredient.fold(alias)
                if byKey[key] == nil || byKey[key]?.name == entry.name {
                    byKey[key] = entry
                }
            }
        }
        // Second pass so canonical names cannot be shadowed by an alias inserted after them.
        for entry in facts {
            byKey[Ingredient.fold(entry.name)] = entry
        }
    }

    init(ingredients: [Ingredient]) {
        self.init(facts: ingredients.map(IngredientFacts.init(ingredient:)))
    }

    var allFacts: [IngredientFacts] { ordered }

    /// The catalog row for a name or alias.
    func facts(for name: String) -> IngredientFacts? {
        byKey[Ingredient.fold(name)]
    }

    /// The catalog name a piece of text refers to, or the text itself when it is unknown.
    func canonicalName(for name: String) -> String {
        facts(for: name)?.name ?? name
    }

    func category(for name: String) -> IngredientCategory? {
        facts(for: name)?.category
    }
}

// MARK: - Diet

/// The household's diet settings, flattened for the engines.
struct DietRules: Sendable {
    var isVegetarian: Bool = true
    var eggsOK: Bool = true
    var dairyOK: Bool = true
    var nutFree: Bool = false
    var glutenFree: Bool = false
    var excludedIngredients: [String] = []
    var appliances: Set<Appliance> = []

    init(
        isVegetarian: Bool = true,
        eggsOK: Bool = true,
        dairyOK: Bool = true,
        nutFree: Bool = false,
        glutenFree: Bool = false,
        excludedIngredients: [String] = [],
        appliances: Set<Appliance> = []
    ) {
        self.isVegetarian = isVegetarian
        self.eggsOK = eggsOK
        self.dairyOK = dairyOK
        self.nutFree = nutFree
        self.glutenFree = glutenFree
        self.excludedIngredients = excludedIngredients
        self.appliances = appliances
    }

    init(profile: DietProfile) {
        self.init(
            isVegetarian: profile.isVegetarian,
            eggsOK: profile.eggsOK,
            dairyOK: profile.dairyOK,
            nutFree: profile.nutFree,
            glutenFree: profile.glutenFree,
            excludedIngredients: profile.excludedIngredients,
            appliances: profile.applianceSet
        )
    }
}

// MARK: - Pantry

/// One row of the pantry, flattened for the engines.
struct PantryStock: Hashable, Sendable {
    var name: String
    var quantity: Double
    var unit: MeasurementUnit
    var expiresAt: Date?
    /// Below this, a staple is topped up on the next shop.
    var lowThreshold: Double?

    init(name: String, quantity: Double, unit: MeasurementUnit, expiresAt: Date?, lowThreshold: Double? = nil) {
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.expiresAt = expiresAt
        self.lowThreshold = lowThreshold
    }

    init(item: PantryItem) {
        self.init(
            name: item.ingredient?.name ?? "",
            quantity: item.quantity,
            unit: item.unit,
            expiresAt: item.expiresAt,
            lowThreshold: item.lowThreshold
        )
    }
}

/// What the household has in, as the planner and the grocery builder see it.
struct PantrySnapshot: Sendable {
    let items: [PantryStock]
    /// Total per folded ingredient name, in that ingredient's own unit.
    private let byName: [String: PantryStock]

    init(items: [PantryStock]) {
        self.items = items
        var merged: [String: PantryStock] = [:]
        // A row at zero still counts as "known to the household", so it can be topped up, but it
        // contributes no stock.
        for item in items where item.quantity > 0 {
            let key = Ingredient.fold(item.name)
            if var existing = merged[key] {
                if let combined = Units.add(Quantity(existing.quantity, existing.unit),
                                            Quantity(item.quantity, item.unit)) {
                    existing.quantity = combined.amount
                }
                // Keep the soonest expiry: that is the one worth cooking towards.
                if let incoming = item.expiresAt,
                   existing.expiresAt.map({ incoming < $0 }) ?? true {
                    existing.expiresAt = incoming
                }
                merged[key] = existing
            } else {
                merged[key] = item
            }
        }
        byName = merged
    }

    init(pantryItems: [PantryItem]) {
        self.init(items: pantryItems.map(PantryStock.init(item:)))
    }

    func has(_ ingredientName: String) -> Bool {
        byName[Ingredient.fold(ingredientName)] != nil
    }

    func stock(for ingredientName: String) -> PantryStock? {
        byName[Ingredient.fold(ingredientName)]
    }

    /// The share of a recipe's required ingredients the household already has, 0…1.
    func coverage(for recipe: RecipeSummary) -> Double {
        let required = recipe.requiredIngredients
        guard !required.isEmpty else { return 1 }
        let present = required.filter { has($0.ingredientName) }.count
        return Double(present) / Double(required.count)
    }

    /// Catalog names that should be cooked soon, as they are stored (for display in a reason).
    func expiringNames(on date: Date, within days: Int = ShelfLife.useItUpWindowDays) -> [String] {
        byName.values
            .filter { ShelfLife.isExpiringSoon($0.expiresAt, on: date, within: days) }
            .map(\.name)
            .sorted()
    }

    /// The expiring ingredients this recipe would use up.
    func expiringIngredients(for recipe: RecipeSummary, on date: Date,
                             within days: Int = ShelfLife.useItUpWindowDays) -> [String] {
        let expiring = Set(expiringNames(on: date, within: days).map(Ingredient.fold))
        return recipe.requiredIngredients
            .map(\.ingredientName)
            .filter { expiring.contains(Ingredient.fold($0)) }
            .map { stock(for: $0)?.name ?? $0 }
            .sorted()
    }
}

// MARK: - Stores

/// A store as the grocery builder sees it.
struct StoreSnapshot: Hashable, Sendable {
    /// Stable key — the store's name, which is unique in practice and readable in an export.
    var id: String
    var name: String
    var kind: StoreKind
    var isPreferred: Bool
    var sortOrder: Int
    var affinities: Set<IngredientCategory>

    init(id: String, name: String, kind: StoreKind, isPreferred: Bool, sortOrder: Int,
         affinities: Set<IngredientCategory>) {
        self.id = id
        self.name = name
        self.kind = kind
        self.isPreferred = isPreferred
        self.sortOrder = sortOrder
        self.affinities = affinities
    }

    init(store: Store) {
        self.init(
            id: store.name,
            name: store.name,
            kind: store.kind,
            isPreferred: store.isPreferred,
            sortOrder: store.sortOrder,
            affinities: store.affinities
        )
    }
}
