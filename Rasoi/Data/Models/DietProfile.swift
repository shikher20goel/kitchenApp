import Foundation
import SwiftData

/// What this household eats and cooks with (SPEC §3). A singleton row: `current(in:)` is the only
/// way to reach it, so no screen can accidentally create a second profile.
@Model
final class DietProfile {
    /// Vegetarian is a hard filter in v1 and the UI does not offer a way off it (SPEC R4).
    var isVegetarian: Bool = true
    var eggsOK: Bool = true
    var dairyOK: Bool = true
    var nutFree: Bool = false
    var glutenFree: Bool = false
    /// Ingredient names the household never wants to see. Matched case-insensitively.
    var excludedIngredients: [String] = []
    var preferredCuisines: [String] = DietProfile.defaultCuisines
    var appliances: [String] = DietProfile.defaultAppliances
    var zipCode: String = "07302"
    /// Gregorian weekday number (1 = Sunday) the weekly shop happens on.
    var shoppingWeekday: Int = 1
    /// Dinner on a school night has to fit in this many minutes, prep + cook.
    var weekdayMaxCookMinutes: Int = 35
    var hasCompletedOnboarding: Bool = false
    /// Version of `seed/*.json` already imported; 0 means "nothing imported yet".
    var seedVersion: Int = 0

    init() {}

    static let defaultCuisines = ["Indian", "Mexican", "Italian", "Chinese-style", "American"]
    static let defaultAppliances = [
        Appliance.instantPot, .vitamix, .stovetop, .oven,
    ].map(\.rawValue)

    /// The household's profile, created with SPEC defaults on first use.
    @MainActor
    static func current(in context: ModelContext) -> DietProfile {
        var descriptor = FetchDescriptor<DietProfile>()
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let profile = DietProfile()
        context.insert(profile)
        return profile
    }

    /// Appliances as a set, in the vocabulary the recipes are tagged with.
    var applianceSet: Set<Appliance> {
        get { Set(appliances.compactMap(Appliance.init(rawValue:))) }
        set { appliances = Appliance.allCases.filter(newValue.contains).map(\.rawValue) }
    }

    /// True when the household has asked never to see this ingredient.
    func excludes(ingredientNamed name: String) -> Bool {
        let needle = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        return excludedIngredients.contains { excluded in
            excluded.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil) == needle
        }
    }
}

/// The kitchen equipment a recipe can require. Raw values match `seed/recipes.json`.
enum Appliance: String, Codable, CaseIterable, Sendable {
    case instantPot
    case vitamix
    case stovetop
    case oven
    case airFryer
    case microwave
    case blenderBasic

    var label: String {
        switch self {
        case .instantPot: return "Instant Pot"
        case .vitamix: return "Vitamix"
        case .stovetop: return "Stovetop"
        case .oven: return "Oven"
        case .airFryer: return "Air fryer"
        case .microwave: return "Microwave"
        case .blenderBasic: return "Blender"
        }
    }

    var symbolName: String {
        switch self {
        case .instantPot: return "cooktop"
        case .vitamix, .blenderBasic: return "tornado"
        case .stovetop: return "flame"
        case .oven: return "oven"
        case .airFryer: return "wind"
        case .microwave: return "microwave"
        }
    }
}
