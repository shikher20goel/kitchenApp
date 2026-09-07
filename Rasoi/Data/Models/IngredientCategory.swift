import Foundation

/// Where an ingredient sits in the shop and on the list (SPEC §3). Raw values match
/// `seed/ingredients.json`; the Shop screen groups by this and stores claim categories with
/// `categoryAffinity`.
enum IngredientCategory: String, Codable, CaseIterable, Sendable {
    case fruit
    case vegetable
    case leafyGreen
    case dairy
    case egg
    case legume
    case grain
    case flourBread
    case nutSeed
    case spice
    case oilCondiment
    case frozen
    case snack
    case beverage
    case other

    var label: String {
        switch self {
        case .fruit: return "Fruit"
        case .vegetable: return "Vegetables"
        case .leafyGreen: return "Leafy greens"
        case .dairy: return "Dairy"
        case .egg: return "Eggs"
        case .legume: return "Dal & legumes"
        case .grain: return "Grains & rice"
        case .flourBread: return "Flour & bread"
        case .nutSeed: return "Nuts & seeds"
        case .spice: return "Spices"
        case .oilCondiment: return "Oils & condiments"
        case .frozen: return "Frozen"
        case .snack: return "Snacks"
        case .beverage: return "Drinks"
        case .other: return "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .fruit: return "apple.logo"
        case .vegetable: return "carrot"
        case .leafyGreen: return "leaf"
        case .dairy: return "drop"
        case .egg: return "oval.portrait"
        case .legume: return "circle.grid.3x3"
        case .grain: return "fork.knife"
        case .flourBread: return "bag"
        case .nutSeed: return "circle.hexagongrid"
        case .spice: return "sparkles"
        case .oilCondiment: return "drop.triangle"
        case .frozen: return "snowflake"
        case .snack: return "takeoutbag.and.cup.and.straw"
        case .beverage: return "cup.and.saucer"
        case .other: return "shippingbox"
        }
    }
}
