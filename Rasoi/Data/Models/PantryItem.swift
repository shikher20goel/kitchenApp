import Foundation
import SwiftData

/// Something the household actually has, in one of the three places it can be (SPEC §3).
/// There is exactly one row per ingredient + location; `add(_:)` upserts rather than duplicating.
@Model
final class PantryItem {
    var ingredient: Ingredient?
    var quantity: Double = 0
    var unitRaw: String = MeasurementUnit.gram.rawValue
    var locationRaw: String = PantryLocation.pantry.rawValue
    var addedAt: Date = Date.distantPast
    var expiresAt: Date?
    /// Below this the Shop screen tops the item up as a staple.
    var lowThreshold: Double?
    var sourceRaw: String = PantryItemSource.manual.rawValue

    init(
        ingredient: Ingredient?,
        quantity: Double,
        unit: MeasurementUnit,
        location: PantryLocation,
        addedAt: Date,
        expiresAt: Date? = nil,
        lowThreshold: Double? = nil,
        source: PantryItemSource = .manual
    ) {
        self.ingredient = ingredient
        self.quantity = quantity
        self.unitRaw = unit.rawValue
        self.locationRaw = location.rawValue
        self.addedAt = addedAt
        self.expiresAt = expiresAt
        self.lowThreshold = lowThreshold
        self.sourceRaw = source.rawValue
    }

    var unit: MeasurementUnit {
        get { MeasurementUnit(rawValue: unitRaw) ?? .gram }
        set { unitRaw = newValue.rawValue }
    }

    var location: PantryLocation {
        get { PantryLocation(rawValue: locationRaw) ?? .pantry }
        set { locationRaw = newValue.rawValue }
    }

    var source: PantryItemSource {
        get { PantryItemSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var isEmpty: Bool { quantity <= 0 }

    /// True when a threshold is set and the quantity has fallen to it.
    var isLow: Bool {
        guard let lowThreshold else { return false }
        return quantity <= lowThreshold
    }

    func isExpiringSoon(on date: Date, within days: Int = ShelfLife.expiringSoonWindowDays) -> Bool {
        ShelfLife.isExpiringSoon(expiresAt, on: date, within: days)
    }

    /// Adds stock, converting `unit` into the row's own unit when the two measure the same thing,
    /// and pushes the expiry out from the newest addition.
    func restock(quantity amount: Double, unit incomingUnit: MeasurementUnit, on date: Date, source newSource: PantryItemSource) {
        quantity += convert(amount, from: incomingUnit)
        addedAt = date
        sourceRaw = newSource.rawValue
        refreshExpiry()
    }

    /// Takes stock away. Never goes below zero — a recipe that used more than was recorded just
    /// empties the row rather than inventing a negative pantry.
    func consume(quantity amount: Double, unit incomingUnit: MeasurementUnit,
                 gramsPerTeaspoon: Double? = nil) {
        quantity = max(0, quantity - convert(amount, from: incomingUnit, gramsPerTeaspoon: gramsPerTeaspoon))
    }

    /// Recomputes `expiresAt` from the catalog shelf life for the current location.
    func refreshExpiry() {
        guard let ingredient else { return }
        expiresAt = ShelfLife.expiry(
            shelfLifeDays: ingredient.typicalShelfLifeDays,
            addedAt: addedAt,
            location: location
        )
    }

    /// Converts an incoming amount into this row's unit; incompatible dimensions are taken at
    /// face value rather than dropped, so a mis-tagged recipe can never silently lose stock.
    private func convert(_ amount: Double, from incoming: MeasurementUnit,
                         gramsPerTeaspoon: Double? = nil) -> Double {
        guard incoming != unit else { return amount }
        let density = gramsPerTeaspoon ?? ingredient?.gramsPerTeaspoon
        if let converted = Units.convert(amount, from: incoming, to: unit, gramsPerTeaspoon: density) {
            return converted
        }
        return amount
    }
}

extension PantryItem {
    /// The row for this ingredient in this location, if the household has one.
    @MainActor
    static func existing(for ingredient: Ingredient, location: PantryLocation, in context: ModelContext) -> PantryItem? {
        let name = ingredient.name
        let locationRaw = location.rawValue
        let descriptor = FetchDescriptor<PantryItem>(
            predicate: #Predicate { item in
                item.locationRaw == locationRaw && item.ingredient?.name == name
            }
        )
        return try? context.fetch(descriptor).first
    }

    /// Adds stock, creating the row the first time. This is the only way stock enters the pantry
    /// so the one-row-per-ingredient-and-location rule cannot be broken by a caller.
    @discardableResult
    @MainActor
    static func add(
        _ ingredient: Ingredient,
        quantity: Double,
        unit: MeasurementUnit,
        location: PantryLocation,
        on date: Date,
        source: PantryItemSource = .manual,
        in context: ModelContext
    ) -> PantryItem {
        if let item = existing(for: ingredient, location: location, in: context) {
            item.restock(quantity: quantity, unit: unit, on: date, source: source)
            return item
        }
        let item = PantryItem(
            ingredient: ingredient,
            quantity: quantity,
            unit: unit,
            location: location,
            addedAt: date,
            source: source
        )
        item.refreshExpiry()
        context.insert(item)
        return item
    }
}

/// Where in the kitchen something is kept. Drives the shelf-life multiplier and the Pantry tabs.
enum PantryLocation: String, Codable, CaseIterable, Sendable {
    case fridge
    case pantry
    case freezer

    var label: String {
        switch self {
        case .fridge: return "Fridge"
        case .pantry: return "Pantry"
        case .freezer: return "Freezer"
        }
    }

    var symbolName: String {
        switch self {
        case .fridge: return "refrigerator"
        case .pantry: return "cabinet"
        case .freezer: return "snowflake"
        }
    }
}

/// How a pantry row got there — useful when explaining a quantity back to the household.
enum PantryItemSource: String, Codable, CaseIterable, Sendable {
    case manual
    case shop
    case seed
}
