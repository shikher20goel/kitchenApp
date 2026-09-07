import Foundation
import SwiftData

/// One row of the seeded ingredient catalog (SPEC §3). Names are unique and act as the key the
/// recipes, pantry and grocery list all join on.
@Model
final class Ingredient {
    @Attribute(.unique) var name: String = ""
    /// Other names the household might type: "arhar dal" or "tuvar dal" both find Toor dal.
    var aliases: [String] = []
    var categoryRaw: String = IngredientCategory.other.rawValue
    var defaultUnitRaw: String = MeasurementUnit.gram.rawValue
    var typicalShelfLifeDays: Int = 7
    /// Staples are topped up every week whether or not a recipe calls for them.
    var isStaple: Bool = false
    var defaultStoreKindRaw: String = StoreKind.supermarket.rawValue
    var nutritionTags: [String] = []
    var containsEgg: Bool = false
    var containsDairy: Bool = false
    var containsNuts: Bool = false
    var containsGluten: Bool = false
    /// Feeds the Today screen's quick-snack strip: things a child can eat with no cooking.
    var isQuickHealthySnack: Bool = false

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
        self.categoryRaw = category.rawValue
        self.defaultUnitRaw = defaultUnit.rawValue
        self.typicalShelfLifeDays = typicalShelfLifeDays
        self.isStaple = isStaple
        self.defaultStoreKindRaw = defaultStoreKind.rawValue
        self.nutritionTags = nutritionTags
        self.containsEgg = containsEgg
        self.containsDairy = containsDairy
        self.containsNuts = containsNuts
        self.containsGluten = containsGluten
        self.isQuickHealthySnack = isQuickHealthySnack
    }

    var category: IngredientCategory {
        get { IngredientCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var defaultUnit: MeasurementUnit {
        get { MeasurementUnit(rawValue: defaultUnitRaw) ?? .gram }
        set { defaultUnitRaw = newValue.rawValue }
    }

    var defaultStoreKind: StoreKind {
        get { StoreKind(rawValue: defaultStoreKindRaw) ?? .supermarket }
        set { defaultStoreKindRaw = newValue.rawValue }
    }

    /// Name plus aliases, folded for matching.
    var searchKeys: [String] {
        ([name] + aliases).map(Ingredient.fold)
    }
}

extension Ingredient {
    /// Case- and diacritic-insensitive form used for every name comparison in the app.
    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The catalog row with this exact name (case-insensitive), or nil.
    @MainActor
    static func named(_ name: String, in context: ModelContext) -> Ingredient? {
        let folded = fold(name)
        // The unique index is on the exact string, so an exact hit is tried first and the
        // case-insensitive sweep only runs when that misses.
        var descriptor = FetchDescriptor<Ingredient>(predicate: #Predicate { $0.name == name })
        descriptor.fetchLimit = 1
        if let exact = try? context.fetch(descriptor).first {
            return exact
        }
        return (try? context.fetch(FetchDescriptor<Ingredient>()))?
            .first { fold($0.name) == folded }
    }

    /// Type-ahead over the catalog, matching the name and every alias.
    ///
    /// Ranking is deterministic (SPEC R5): exact name, then name prefix, then alias prefix, then
    /// anything containing the query — alphabetically within each rank.
    static func search(_ query: String, in candidates: [Ingredient], limit: Int = 20) -> [Ingredient] {
        let needle = fold(query)
        guard !needle.isEmpty else { return [] }

        func rank(_ ingredient: Ingredient) -> Int? {
            let name = fold(ingredient.name)
            if name == needle { return 0 }
            if name.hasPrefix(needle) { return 1 }
            let aliases = ingredient.aliases.map(fold)
            if aliases.contains(where: { $0 == needle || $0.hasPrefix(needle) }) { return 2 }
            if name.contains(needle) { return 3 }
            if aliases.contains(where: { $0.contains(needle) }) { return 4 }
            return nil
        }

        var ranked: [(rank: Int, ingredient: Ingredient)] = []
        for ingredient in candidates {
            if let rank = rank(ingredient) {
                ranked.append((rank: rank, ingredient: ingredient))
            }
        }
        ranked.sort { left, right in
            if left.rank != right.rank { return left.rank < right.rank }
            return left.ingredient.name.localizedCaseInsensitiveCompare(right.ingredient.name) == .orderedAscending
        }
        return ranked.prefix(limit).map(\.ingredient)
    }
}
