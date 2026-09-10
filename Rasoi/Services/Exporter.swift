import Foundation
import SwiftData

/// Everything the household has put into Rasoi, as one JSON document (SPEC §4.5).
///
/// The seeded catalog is deliberately left out — it ships with the app and would triple the file
/// for no benefit — but every recipe the household wrote, and every flag they set on a seeded one,
/// is here. Nothing is uploaded: the file goes wherever the share sheet is pointed (R1).
struct RasoiExport: Codable, Equatable, Sendable {
    var formatVersion: Int
    var exportedAt: Date
    var household: [Member]
    var diet: Diet
    var stores: [StoreRecord]
    var pantry: [PantryRecord]
    var userRecipes: [RecipeRecord]
    /// Seeded recipes the household has rewritten — their version, not the catalog's.
    var editedSeedRecipes: [RecipeRecord]
    var recipeFlags: [RecipeFlag]
    var plans: [Plan]
    var feedback: [Feedback]
    var groceryLists: [GroceryListRecord]

    struct Member: Codable, Equatable, Sendable {
        var name: String
        var dateOfBirth: Date
        var role: String
        var likes: [String]
        var dislikes: [String]
        var isActive: Bool
    }

    struct Diet: Codable, Equatable, Sendable {
        var isVegetarian: Bool
        var eggsOK: Bool
        var dairyOK: Bool
        var nutFree: Bool
        var glutenFree: Bool
        var excludedIngredients: [String]
        var preferredCuisines: [String]
        var appliances: [String]
        var zipCode: String
        var shoppingWeekday: Int
        var weekdayMaxCookMinutes: Int
    }

    struct StoreRecord: Codable, Equatable, Sendable {
        var name: String
        var kind: String
        var address: String
        var isPreferred: Bool
        var sortOrder: Int
        var categoryAffinity: [String]
    }

    struct PantryRecord: Codable, Equatable, Sendable {
        var ingredient: String
        var quantity: Double
        var unit: String
        var location: String
        var addedAt: Date
        var expiresAt: Date?
    }

    struct RecipeRecord: Codable, Equatable, Sendable {
        /// Set for a seeded recipe the household edited; nil for one they wrote themselves.
        var seedID: String?
        var title: String
        var cuisine: String
        var mealTypes: [String]
        var appliances: [String]
        var prepMinutes: Int
        var cookMinutes: Int
        var servings: Int
        var minAgeYears: Int
        var ingredients: [Line]
        var steps: [String]
        var kidFriendlyNote: String

        struct Line: Codable, Equatable, Sendable {
            var ingredientName: String
            var quantity: Double
            var unit: String
            var isOptional: Bool
            var note: String
        }
    }

    /// A household choice about a seeded recipe, so favourites and hidden dishes survive.
    struct RecipeFlag: Codable, Equatable, Sendable {
        var seedID: String
        var isFavorite: Bool
        var isHidden: Bool
    }

    struct Plan: Codable, Equatable, Sendable {
        var weekStart: Date
        var slots: [Slot]

        struct Slot: Codable, Equatable, Sendable {
            var date: Date
            var mealType: String
            var recipeTitle: String?
            var servings: Int
            var status: String
            var reasons: [String]
            var lockedByUser: Bool
        }
    }

    struct Feedback: Codable, Equatable, Sendable {
        var date: Date
        var mealType: String
        var recipeTitle: String?
        var member: String?
        var reaction: String
        var note: String?
        var createdAt: Date
    }

    struct GroceryListRecord: Codable, Equatable, Sendable {
        var weekStart: Date
        var isFinalized: Bool
        var items: [Item]

        struct Item: Codable, Equatable, Sendable {
            var ingredient: String
            var quantity: Double
            var unit: String
            var store: String?
            var isChecked: Bool
            var neededFor: [String]
            var isStapleTopUp: Bool
            var addedManually: Bool
        }
    }
}

/// Builds the export. There is no import in v1 — this is a copy for the household to keep.
@MainActor
enum Exporter {
    static let formatVersion = 1

    static func makeExport(in context: ModelContext, on date: Date = .now) throws -> RasoiExport {
        let members = try context.fetch(FetchDescriptor<HouseholdMember>(sortBy: [SortDescriptor(\.sortOrder)]))
        let profile = DietProfile.current(in: context)
        let stores = try context.fetch(FetchDescriptor<Store>(sortBy: [SortDescriptor(\.sortOrder)]))
        let pantry = try context.fetch(FetchDescriptor<PantryItem>())
        let recipes = try context.fetch(FetchDescriptor<Recipe>(sortBy: [SortDescriptor(\.title)]))
        let plans = try context.fetch(FetchDescriptor<MealPlan>(sortBy: [SortDescriptor(\.weekStart)]))
        let feedback = try context.fetch(FetchDescriptor<MealFeedback>())
        let lists = try context.fetch(FetchDescriptor<GroceryList>(sortBy: [SortDescriptor(\.weekStart)]))

        return RasoiExport(
            formatVersion: formatVersion,
            exportedAt: date,
            household: members.map {
                RasoiExport.Member(name: $0.name, dateOfBirth: $0.dateOfBirth, role: $0.roleRaw,
                                   likes: $0.likes, dislikes: $0.dislikes, isActive: $0.isActive)
            },
            diet: RasoiExport.Diet(
                isVegetarian: profile.isVegetarian, eggsOK: profile.eggsOK, dairyOK: profile.dairyOK,
                nutFree: profile.nutFree, glutenFree: profile.glutenFree,
                excludedIngredients: profile.excludedIngredients,
                preferredCuisines: profile.preferredCuisines, appliances: profile.appliances,
                zipCode: profile.zipCode, shoppingWeekday: profile.shoppingWeekday,
                weekdayMaxCookMinutes: profile.weekdayMaxCookMinutes
            ),
            stores: stores.map {
                RasoiExport.StoreRecord(name: $0.name, kind: $0.kindRaw, address: $0.address,
                                        isPreferred: $0.isPreferred, sortOrder: $0.sortOrder,
                                        categoryAffinity: $0.categoryAffinity)
            },
            pantry: pantry.compactMap { item in
                guard let name = item.ingredient?.name else { return nil }
                return RasoiExport.PantryRecord(ingredient: name, quantity: item.quantity,
                                                unit: item.unitRaw, location: item.locationRaw,
                                                addedAt: item.addedAt, expiresAt: item.expiresAt)
            },
            userRecipes: recipes.filter { $0.source == .user }.map(recipeRecord),
            editedSeedRecipes: recipes.filter { $0.isUserEdited && $0.seedID != nil }.map(recipeRecord),
            recipeFlags: recipes.compactMap { recipe in
                guard let seedID = recipe.seedID, recipe.isFavorite || recipe.isHidden else { return nil }
                return RasoiExport.RecipeFlag(seedID: seedID, isFavorite: recipe.isFavorite,
                                              isHidden: recipe.isHidden)
            },
            plans: plans.map { plan in
                RasoiExport.Plan(
                    weekStart: plan.weekStart,
                    slots: plan.slots
                        .sorted { $0.date == $1.date ? $0.mealType.sortOrder < $1.mealType.sortOrder : $0.date < $1.date }
                        .map { slot in
                            RasoiExport.Plan.Slot(date: slot.date, mealType: slot.mealTypeRaw,
                                                  recipeTitle: slot.recipe?.title, servings: slot.servings,
                                                  status: slot.statusRaw, reasons: slot.reasons,
                                                  lockedByUser: slot.lockedByUser)
                        }
                )
            },
            feedback: feedback.map { entry in
                RasoiExport.Feedback(date: entry.slot?.date ?? entry.createdAt,
                                     mealType: entry.slot?.mealTypeRaw ?? "",
                                     recipeTitle: entry.slot?.recipe?.title,
                                     member: entry.member?.name,
                                     reaction: entry.reactionRaw, note: entry.note,
                                     createdAt: entry.createdAt)
            },
            groceryLists: lists.map { list in
                RasoiExport.GroceryListRecord(
                    weekStart: list.weekStart,
                    isFinalized: list.isFinalized,
                    items: list.items.compactMap { item in
                        guard let name = item.ingredient?.name else { return nil }
                        return RasoiExport.GroceryListRecord.Item(
                            ingredient: name, quantity: item.quantity, unit: item.unitRaw,
                            store: item.store?.name, isChecked: item.isChecked,
                            neededFor: item.neededFor, isStapleTopUp: item.isStapleTopUp,
                            addedManually: item.addedManually
                        )
                    }
                )
            }
        )
    }

    private static func recipeRecord(_ recipe: Recipe) -> RasoiExport.RecipeRecord {
        RasoiExport.RecipeRecord(
            seedID: recipe.isUserEdited ? recipe.seedID : nil,
            title: recipe.title, cuisine: recipe.cuisine, mealTypes: recipe.mealTypeRaw,
            appliances: recipe.appliances, prepMinutes: recipe.prepMinutes,
            cookMinutes: recipe.cookMinutes, servings: recipe.servings,
            minAgeYears: recipe.minAgeYears,
            ingredients: recipe.ingredients.map {
                RasoiExport.RecipeRecord.Line(ingredientName: $0.ingredientName, quantity: $0.quantity,
                                              unit: $0.unitRaw, isOptional: $0.isOptional, note: $0.note)
            },
            steps: recipe.steps, kidFriendlyNote: recipe.kidFriendlyNote
        )
    }

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func jsonData(in context: ModelContext, on date: Date = .now) throws -> Data {
        try encoder().encode(makeExport(in: context, on: date))
    }

    /// Writes the export to a temporary file and returns its URL, ready for the share sheet.
    static func writeTemporaryFile(in context: ModelContext, on date: Date = .now) throws -> URL {
        let stamp = ISO8601DateFormatter().string(from: date).prefix(10)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("rasoi-export-\(stamp).json")
        try jsonData(in: context, on: date).write(to: url, options: .atomic)
        return url
    }
}
