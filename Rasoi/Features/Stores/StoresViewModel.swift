import Foundation
import SwiftData

/// The shops the household actually visits (SPEC §4.5). Order matters: the grocery list is split
/// across preferred stores in this order, and the Shop screen walks them the same way.
@MainActor
@Observable
final class StoresViewModel {
    private let context: ModelContext

    private(set) var stores: [Store] = []

    init(context: ModelContext) {
        self.context = context
        load()
    }

    func load() {
        let descriptor = FetchDescriptor<Store>(sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)])
        stores = (try? context.fetch(descriptor)) ?? []
    }

    var preferredStores: [Store] { stores.filter(\.isPreferred) }

    @discardableResult
    func addStore(name: String, kind: StoreKind, address: String = "",
                  latitude: Double? = nil, longitude: Double? = nil,
                  isPreferred: Bool = true) -> Store {
        let store = Store(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: kind,
            address: address,
            latitude: latitude,
            longitude: longitude,
            isPreferred: isPreferred,
            sortOrder: stores.count,
            categoryAffinity: Self.defaultAffinity(for: kind)
        )
        context.insert(store)
        save()
        return store
    }

    /// What a kind of shop is assumed to carry until the household says otherwise.
    static func defaultAffinity(for kind: StoreKind) -> [IngredientCategory] {
        switch kind {
        case .supermarket, .warehouse: return IngredientCategory.allCases
        case .indian: return [.legume, .spice, .flourBread, .dairy]
        case .hispanic: return [.flourBread, .vegetable]
        case .eastAsian: return [.legume, .oilCondiment, .grain]
        case .farmers: return [.fruit, .vegetable, .leafyGreen]
        case .other: return []
        }
    }

    func update(_ store: Store, name: String? = nil, kind: StoreKind? = nil, address: String? = nil,
                isPreferred: Bool? = nil, affinities: Set<IngredientCategory>? = nil) {
        if let name { store.name = name.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let kind { store.kind = kind }
        if let address { store.address = address }
        if let isPreferred { store.isPreferred = isPreferred }
        if let affinities { store.affinities = affinities }
        save()
    }

    func toggleAffinity(_ category: IngredientCategory, for store: Store) {
        var current = store.affinities
        if current.contains(category) {
            current.remove(category)
        } else {
            current.insert(category)
        }
        store.affinities = current
        save()
    }

    func togglePreferred(_ store: Store) {
        store.isPreferred.toggle()
        save()
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        var ordered = stores
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, store) in ordered.enumerated() {
            store.sortOrder = index
        }
        save()
    }

    /// Removing a shop leaves the grocery lines it held; they simply fall back to "any store".
    func remove(_ store: Store) {
        for item in (try? context.fetch(FetchDescriptor<GroceryItem>())) ?? []
        where item.store?.persistentModelID == store.persistentModelID {
            item.store = nil
        }
        context.delete(store)
        save()
        renumber()
    }

    private func renumber() {
        for (index, store) in stores.enumerated() where store.sortOrder != index {
            store.sortOrder = index
        }
        try? context.save()
        load()
    }

    private func save() {
        try? context.save()
        load()
    }
}
