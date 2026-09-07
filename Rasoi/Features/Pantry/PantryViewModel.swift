import Foundation
import SwiftData

/// What the household has in, by location (SPEC §4.3).
///
/// The pantry is the input the planner trusts most, so everything that changes it goes through
/// here: adding upserts one row per ingredient and location, using something up decrements it,
/// and "ran out" removes it — except for a weekly staple, which stays visible at zero so the
/// shopping list can top it up.
@MainActor
@Observable
final class PantryViewModel {
    enum SortOrder: String, CaseIterable, Sendable {
        case name
        case expiring

        var label: String {
            switch self {
            case .name: return "Name"
            case .expiring: return "Expiring"
            }
        }
    }

    private let context: ModelContext
    private let now: () -> Date

    var location: PantryLocation = .fridge { didSet { load() } }
    var sortOrder: SortOrder = .name { didSet { load() } }
    var searchText: String = "" { didSet { load() } }

    /// The rows for the selected location, filtered by the search text and sorted.
    private(set) var items: [PantryItem] = []
    private(set) var allItems: [PantryItem] = []

    init(context: ModelContext, now: @escaping () -> Date = { .now }) {
        self.context = context
        self.now = now
        load()
    }

    func load() {
        allItems = (try? context.fetch(FetchDescriptor<PantryItem>())) ?? []
        var visible = allItems.filter { $0.location == location }

        let query = searchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            let matches = Set(searchCatalog(query, respectExclusions: false).map { Ingredient.fold($0.name) })
            visible = visible.filter { item in
                guard let name = item.ingredient?.name else { return false }
                return matches.contains(Ingredient.fold(name))
            }
        }

        items = visible.sorted(by: ordering)
    }

    /// Sorting is total and deterministic: the fallback on equal keys is the ingredient name.
    private func ordering(_ left: PantryItem, _ right: PantryItem) -> Bool {
        let leftName = left.ingredient?.name ?? ""
        let rightName = right.ingredient?.name ?? ""
        switch sortOrder {
        case .name:
            return leftName.localizedCaseInsensitiveCompare(rightName) == .orderedAscending
        case .expiring:
            // Rows with no expiry sit at the end rather than jumping to the top.
            switch (left.expiresAt, right.expiresAt) {
            case let (leftDate?, rightDate?) where leftDate != rightDate:
                return leftDate < rightDate
            case (nil, .some):
                return false
            case (.some, nil):
                return true
            default:
                return leftName.localizedCaseInsensitiveCompare(rightName) == .orderedAscending
            }
        }
    }

    // MARK: - Catalog

    /// Type-ahead over the ingredient catalog, honouring the household's exclusions.
    func searchCatalog(_ query: String, respectExclusions: Bool = true) -> [Ingredient] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        let catalog = (try? context.fetch(FetchDescriptor<Ingredient>())) ?? []
        let matches = Ingredient.search(trimmed, in: catalog)
        guard respectExclusions else { return matches }
        let profile = DietProfile.current(in: context)
        return matches.filter { !profile.excludes(ingredientNamed: $0.name) }
    }

    // MARK: - Changing the pantry

    @discardableResult
    func add(
        _ ingredient: Ingredient,
        quantity: Double,
        unit: MeasurementUnit? = nil,
        location: PantryLocation? = nil,
        source: PantryItemSource = .manual
    ) -> PantryItem {
        let item = PantryItem.add(
            ingredient,
            quantity: quantity,
            unit: unit ?? ingredient.defaultUnit,
            location: location ?? self.location,
            on: now(),
            source: source,
            in: context
        )
        save()
        return item
    }

    /// Takes an amount off a row — the "I used some" action.
    func markUsed(_ item: PantryItem, quantity: Double) {
        item.consume(quantity: quantity, unit: item.unit)
        save()
    }

    /// Sets a row's quantity outright, never below zero.
    func setQuantity(_ quantity: Double, for item: PantryItem) {
        item.quantity = max(0, quantity)
        save()
    }

    /// "Ran out": the row goes, unless the ingredient is a weekly staple — those stay at zero so
    /// the shopping list tops them up.
    func ranOut(_ item: PantryItem) {
        if item.ingredient?.isStaple == true {
            item.quantity = 0
        } else {
            context.delete(item)
        }
        save()
    }

    func remove(_ item: PantryItem) {
        context.delete(item)
        save()
    }

    // MARK: - Derived

    /// Everything expiring within two days, anywhere in the kitchen, soonest first.
    func expiringSoon(within days: Int = ShelfLife.expiringSoonWindowDays) -> [PantryItem] {
        let today = now()
        return allItems
            .filter { $0.quantity > 0 && $0.isExpiringSoon(on: today, within: days) }
            .sorted { ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture) }
    }

    func count(in location: PantryLocation) -> Int {
        allItems.filter { $0.location == location && $0.quantity > 0 }.count
    }

    private func save() {
        try? context.save()
        load()
    }
}
