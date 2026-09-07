import SwiftData
import XCTest
@testable import Rasoi

final class StoresViewModelTests: XCTestCase {
    private struct Harness {
        let stack: TestStack
        let model: StoresViewModel
    }

    @MainActor
    private func makeHarness() throws -> Harness {
        let stack = try TestContainer.makeStack()
        StoreSeeder.seedDefaultsIfEmpty(in: stack.context)
        try stack.context.save()
        return Harness(stack: stack, model: StoresViewModel(context: stack.context))
    }

    @MainActor
    func testTheDefaultStoresAreListedInOrder() throws {
        let harness = try makeHarness()
        XCTAssertEqual(harness.model.stores.map(\.name).prefix(3).map { $0 },
                       ["Walmart", "Costco", "Stop & Shop"])
        XCTAssertEqual(harness.model.preferredStores.count, 3)
    }

    @MainActor
    func testReorderPersistsSortOrder() throws {
        let harness = try makeHarness()
        harness.model.move(fromOffsets: IndexSet(integer: 3), toOffset: 0)

        XCTAssertEqual(harness.model.stores.first?.name, "Indian grocery")
        XCTAssertEqual(harness.model.stores.map(\.sortOrder), Array(0..<6))

        let reloaded = StoresViewModel(context: harness.stack.context)
        XCTAssertEqual(reloaded.stores.first?.name, "Indian grocery", "The order sticks.")
    }

    @MainActor
    func testTogglingPreferred() throws {
        let harness = try makeHarness()
        let indian = try XCTUnwrap(harness.model.stores.first { $0.name == "Indian grocery" })
        XCTAssertFalse(indian.isPreferred)

        harness.model.togglePreferred(indian)
        XCTAssertTrue(indian.isPreferred)
        XCTAssertEqual(harness.model.preferredStores.count, 4)
    }

    @MainActor
    func testEditingAffinities() throws {
        let harness = try makeHarness()
        let indian = try XCTUnwrap(harness.model.stores.first { $0.name == "Indian grocery" })
        XCTAssertTrue(indian.handles(.spice))

        harness.model.toggleAffinity(.spice, for: indian)
        XCTAssertFalse(indian.handles(.spice))

        harness.model.toggleAffinity(.frozen, for: indian)
        XCTAssertTrue(indian.handles(.frozen))
    }

    @MainActor
    func testAddingAStoreGetsSensibleDefaults() throws {
        let harness = try makeHarness()
        let farmers = harness.model.addStore(name: "  Saturday market  ", kind: .farmers)

        XCTAssertEqual(farmers.name, "Saturday market")
        XCTAssertEqual(farmers.sortOrder, 6)
        XCTAssertTrue(farmers.isPreferred)
        XCTAssertTrue(farmers.handles(.fruit))
        XCTAssertTrue(farmers.handles(.vegetable))
        XCTAssertFalse(farmers.handles(.spice))
    }

    @MainActor
    func testEditingNameKindAndAddress() throws {
        let harness = try makeHarness()
        let store = try XCTUnwrap(harness.model.stores.first)
        harness.model.update(store, name: "Walmart Neighborhood", kind: .supermarket,
                             address: "123 Main St, Jersey City")

        XCTAssertEqual(store.name, "Walmart Neighborhood")
        XCTAssertEqual(store.address, "123 Main St, Jersey City")
    }

    @MainActor
    func testRemovingAStoreLeavesItsGroceryLinesBehind() throws {
        let harness = try makeHarness()
        let context = harness.stack.context
        let store = try XCTUnwrap(harness.model.stores.first { $0.name == "Costco" })
        let ingredient = Ingredient(name: "Olive oil", category: .oilCondiment, defaultUnit: .millilitre,
                                    typicalShelfLifeDays: 365)
        context.insert(ingredient)
        let list = GroceryList.list(forWeekContaining: D.date(2026, 9, 9), in: context)
        let item = GroceryItem(list: list, ingredient: ingredient, quantity: 500, unit: .millilitre, store: store)
        context.insert(item)
        list.items.append(item)
        try context.save()

        harness.model.remove(store)

        XCTAssertFalse(harness.model.stores.contains { $0.name == "Costco" })
        XCTAssertEqual(try context.fetch(FetchDescriptor<GroceryItem>()).count, 1)
        XCTAssertNil(try context.fetch(FetchDescriptor<GroceryItem>()).first?.store,
                     "The line falls back to any store rather than disappearing.")
        XCTAssertEqual(harness.model.stores.map(\.sortOrder), Array(0..<5))
    }
}
