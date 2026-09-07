import Foundation
import SwiftData

/// A place the household shops (SPEC §3). Coordinates stay `nil` until someone taps a result in
/// the store finder — Rasoi never geocodes or stores an address on its own.
@Model
final class Store {
    var name: String = ""
    var kindRaw: String = StoreKind.supermarket.rawValue
    var address: String = ""
    var latitude: Double?
    var longitude: Double?
    /// Preferred stores are the ones the weekly list is split across.
    var isPreferred: Bool = false
    var sortOrder: Int = 0
    /// Ingredient categories normally bought here, as `IngredientCategory` raw values.
    var categoryAffinity: [String] = []

    init(
        name: String,
        kind: StoreKind,
        address: String = "",
        latitude: Double? = nil,
        longitude: Double? = nil,
        isPreferred: Bool = false,
        sortOrder: Int = 0,
        categoryAffinity: [IngredientCategory] = []
    ) {
        self.name = name
        self.kindRaw = kind.rawValue
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.isPreferred = isPreferred
        self.sortOrder = sortOrder
        self.categoryAffinity = categoryAffinity.map(\.rawValue)
    }

    var kind: StoreKind {
        get { StoreKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    var affinities: Set<IngredientCategory> {
        get { Set(categoryAffinity.compactMap(IngredientCategory.init(rawValue:))) }
        set { categoryAffinity = IngredientCategory.allCases.filter(newValue.contains).map(\.rawValue) }
    }

    /// True when this store normally carries the category.
    func handles(_ category: IngredientCategory) -> Bool {
        categoryAffinity.contains(category.rawValue)
    }

    var hasCoordinate: Bool { latitude != nil && longitude != nil }
}

/// The kind of shop. Speciality kinds win over general ones when the grocery list picks a store,
/// so dal and atta land at the Indian grocery rather than in the supermarket pile.
enum StoreKind: String, Codable, CaseIterable, Sendable {
    case supermarket
    case warehouse
    case indian
    case hispanic
    case eastAsian
    case farmers
    case other

    var label: String {
        switch self {
        case .supermarket: return "Supermarket"
        case .warehouse: return "Warehouse club"
        case .indian: return "Indian grocery"
        case .hispanic: return "Hispanic grocery"
        case .eastAsian: return "East Asian grocery"
        case .farmers: return "Farmers market"
        case .other: return "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .supermarket: return "cart"
        case .warehouse: return "shippingbox"
        case .indian, .hispanic, .eastAsian: return "storefront"
        case .farmers: return "leaf"
        case .other: return "building.2"
        }
    }

    /// General stores carry everything; speciality stores are checked first for their categories.
    var isGeneral: Bool {
        self == .supermarket || self == .warehouse
    }
}

/// Puts the six default stores in place on first launch (SPEC §3). Idempotent: it does nothing
/// once the household has any store at all, so a user who deletes Costco never sees it return.
enum StoreSeeder {
    /// Name, kind, whether it is a default weekly stop, and the categories it claims.
    static let defaults: [(name: String, kind: StoreKind, preferred: Bool, affinity: [IngredientCategory])] = [
        ("Walmart", .supermarket, true, IngredientCategory.allCases),
        ("Costco", .warehouse, true, IngredientCategory.allCases),
        ("Stop & Shop", .supermarket, true, IngredientCategory.allCases),
        ("Indian grocery", .indian, false, [.legume, .spice, .flourBread, .dairy]),
        ("Spanish grocery", .hispanic, false, [.flourBread, .vegetable]),
        ("Chinese grocery", .eastAsian, false, [.legume, .oilCondiment, .grain]),
    ]

    @MainActor
    static func seedDefaultsIfEmpty(in context: ModelContext) {
        var descriptor = FetchDescriptor<Store>()
        descriptor.fetchLimit = 1
        guard (try? context.fetch(descriptor))?.isEmpty ?? false else { return }

        for (index, entry) in defaults.enumerated() {
            context.insert(
                Store(
                    name: entry.name,
                    kind: entry.kind,
                    isPreferred: entry.preferred,
                    sortOrder: index,
                    categoryAffinity: entry.affinity
                )
            )
        }
    }
}
