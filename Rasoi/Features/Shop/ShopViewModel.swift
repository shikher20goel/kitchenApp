import Foundation
import SwiftData

/// This week's shopping (SPEC §4.4).
///
/// Building the list is idempotent — it merges into whatever is there, so a list half ticked off
/// never loses the household's progress. Ticking an item is what moves it into the pantry.
@MainActor
@Observable
final class ShopViewModel {
    private let context: ModelContext
    private let now: () -> Date

    private(set) var weekStart: Date
    private(set) var items: [GroceryItem] = []
    private(set) var stores: [Store] = []

    init(context: ModelContext, weekContaining date: Date? = nil, now: @escaping () -> Date = { .now }) {
        self.context = context
        self.now = now
        self.weekStart = MealPlan.weekStart(containing: date ?? now())
        load()
    }

    func load() {
        let list = GroceryList.list(forWeekContaining: weekStart, in: context)
        stores = (try? context.fetch(FetchDescriptor<Store>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        items = list.items.sorted(by: ordering)
    }

    func showWeek(containing date: Date) {
        weekStart = MealPlan.weekStart(containing: date)
        load()
    }

    var list: GroceryList { GroceryList.list(forWeekContaining: weekStart, in: context) }

    var remainingCount: Int { items.filter { !$0.isChecked }.count }
    var isEmpty: Bool { items.isEmpty }

    // MARK: - Building

    /// Builds (or rebuilds) the list from the week's plan. Safe to run as often as you like.
    func buildFromPlan() {
        let list = self.list
        let built = GroceryBuilder.build(
            meals: plannedMeals(),
            pantry: PantrySnapshot(pantryItems: (try? context.fetch(FetchDescriptor<PantryItem>())) ?? []),
            index: ingredientIndex,
            stores: (try? context.fetch(FetchDescriptor<Store>()))?.map(StoreSnapshot.init(store:)) ?? [],
            includeStaples: true
        )
        let existing = list.items.map {
            ExistingGroceryLine(
                ingredientName: $0.ingredient?.name ?? "",
                quantity: $0.quantity,
                unit: $0.unit,
                isChecked: $0.isChecked,
                addedManually: $0.addedManually,
                neededFor: $0.neededFor
            )
        }
        let plan = GroceryBuilder.merge(built, into: existing)

        for line in plan.inserts {
            guard let ingredient = Ingredient.named(line.ingredientName, in: context) else { continue }
            let item = GroceryItem(
                list: list,
                ingredient: ingredient,
                quantity: line.quantity,
                unit: line.unit,
                store: store(withID: line.storeID),
                neededFor: line.neededFor,
                isStapleTopUp: line.isStapleTopUp
            )
            context.insert(item)
            list.items.append(item)
        }

        for update in plan.updates {
            guard let item = list.items.first(where: {
                Ingredient.fold($0.ingredient?.name ?? "") == Ingredient.fold(update.ingredientName)
            }) else { continue }
            item.quantity = update.quantity
            item.unit = update.unit
            item.neededFor = update.neededFor
            item.isStapleTopUp = update.isStapleTopUp
            if item.store == nil { item.store = store(withID: update.storeID) }
        }

        for name in plan.removals {
            guard let item = list.items.first(where: {
                Ingredient.fold($0.ingredient?.name ?? "") == Ingredient.fold(name)
            }) else { continue }
            list.items.removeAll { $0 === item }
            context.delete(item)
        }

        list.generatedAt = now()
        save()
    }

    /// Meals still to be cooked this week — anything already cooked has been bought and eaten.
    private func plannedMeals() -> [PlannedRecipe] {
        let plan = MealPlan.plan(forWeekContaining: weekStart, in: context)
        return plan.slots.compactMap { slot in
            guard let recipe = slot.recipe else { return nil }
            guard slot.status == .planned else { return nil }
            return PlannedRecipe(
                recipeID: RecipeSummary(recipe: recipe).id,
                title: recipe.title,
                ingredients: recipe.ingredients,
                recipeServings: recipe.servings,
                servings: slot.servings
            )
        }
    }

    // MARK: - Shopping

    /// Ticking an item puts it in the kitchen; unticking takes it back out again.
    func setChecked(_ checked: Bool, for item: GroceryItem) {
        guard item.isChecked != checked else { return }
        let date = now()
        item.setChecked(checked, on: date)

        if let ingredient = item.ingredient {
            let location = Self.location(for: ingredient.category)
            if checked {
                PantryItem.add(ingredient, quantity: item.quantity, unit: item.unit,
                               location: location, on: date, source: .shop, in: context)
            } else if let stocked = PantryItem.existing(for: ingredient, location: location, in: context) {
                stocked.consume(quantity: item.quantity, unit: item.unit)
                if stocked.quantity <= 0, !ingredient.isStaple {
                    context.delete(stocked)
                }
            }
        }
        save()
    }

    /// Where a category is kept, so an expiry date can be worked out on the way in.
    static func location(for category: IngredientCategory) -> PantryLocation {
        switch category {
        case .frozen: return .freezer
        case .fruit, .vegetable, .leafyGreen, .dairy, .egg: return .fridge
        default: return .pantry
        }
    }

    @discardableResult
    func addManualItem(_ ingredient: Ingredient, quantity: Double, unit: MeasurementUnit? = nil,
                       store: Store? = nil) -> GroceryItem {
        let list = self.list
        if let existing = list.items.first(where: { $0.ingredient?.persistentModelID == ingredient.persistentModelID }) {
            existing.addedManually = true
            save()
            return existing
        }
        let assignedStore = store ?? self.store(
            withID: GroceryBuilder.store(
                for: ingredient.category,
                in: stores.map(StoreSnapshot.init(store:))
            )?.id
        )
        let item = GroceryItem(
            list: list,
            ingredient: ingredient,
            quantity: quantity,
            unit: unit ?? ingredient.defaultUnit,
            store: assignedStore,
            neededFor: [],
            addedManually: true
        )
        context.insert(item)
        list.items.append(item)
        save()
        return item
    }

    func remove(_ item: GroceryItem) {
        let list = self.list
        list.items.removeAll { $0 === item }
        context.delete(item)
        save()
    }

    func searchCatalog(_ query: String) -> [Ingredient] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        return Ingredient.search(trimmed, in: (try? context.fetch(FetchDescriptor<Ingredient>())) ?? [])
    }

    // MARK: - Sections

    /// The list grouped by store, then by category — the order you actually walk a shop in.
    struct StoreSection: Identifiable {
        var id: String { storeName }
        var storeName: String
        var store: Store?
        var categories: [CategorySection]
    }

    struct CategorySection: Identifiable {
        var id: String { category.rawValue }
        var category: IngredientCategory
        var items: [GroceryItem]
    }

    var sections: [StoreSection] {
        var byStore: [String: [GroceryItem]] = [:]
        for item in items {
            byStore[item.store?.name ?? "Any store", default: []].append(item)
        }
        let order = Dictionary(uniqueKeysWithValues: stores.map { ($0.name, $0.sortOrder) })
        return byStore.keys
            .sorted { left, right in
                let leftOrder = order[left] ?? Int.max
                let rightOrder = order[right] ?? Int.max
                return leftOrder == rightOrder ? left < right : leftOrder < rightOrder
            }
            .map { name in
                let storeItems = byStore[name] ?? []
                var byCategory: [IngredientCategory: [GroceryItem]] = [:]
                for item in storeItems {
                    byCategory[item.ingredient?.category ?? .other, default: []].append(item)
                }
                let categories = IngredientCategory.allCases.compactMap { category -> CategorySection? in
                    guard let items = byCategory[category], !items.isEmpty else { return nil }
                    return CategorySection(category: category, items: items.sorted(by: ordering))
                }
                return StoreSection(storeName: name, store: stores.first { $0.name == name },
                                    categories: categories)
            }
    }

    /// The list as plain text, ready for the share sheet. Nothing is sent anywhere by Rasoi (R1).
    func shareText() -> String {
        var lines: [String] = ["Rasoi — shopping for \(weekStart.formatted(.dateTime.day().month(.wide)))"]
        for section in sections {
            lines.append("")
            lines.append(section.storeName)
            for category in section.categories {
                for item in category.items {
                    let quantity = Units.display(Quantity(item.quantity, item.unit))
                    let tick = item.isChecked ? "[x]" : "[ ]"
                    lines.append("\(tick) \(item.ingredient?.name ?? "Item") — \(quantity)")
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private var ingredientIndex: IngredientIndex {
        IngredientIndex(ingredients: (try? context.fetch(FetchDescriptor<Ingredient>())) ?? [])
    }

    private func store(withID id: String?) -> Store? {
        guard let id else { return nil }
        return stores.first { $0.name == id }
    }

    /// Unchecked first, then by name — the order a shopper wants.
    private func ordering(_ left: GroceryItem, _ right: GroceryItem) -> Bool {
        if left.isChecked != right.isChecked { return !left.isChecked }
        return (left.ingredient?.name ?? "").localizedCaseInsensitiveCompare(right.ingredient?.name ?? "")
            == .orderedAscending
    }

    private func save() {
        try? context.save()
        load()
    }
}
