import SwiftData
import XCTest
@testable import Rasoi

final class StoreTests: XCTestCase {
    @MainActor
    func testSeedInsertsTheSixDefaultStores() throws {
        let stack = try TestContainer.makeStack()
        StoreSeeder.seedDefaultsIfEmpty(in: stack.context)
        try stack.context.save()

        let stores = try stack.context.fetch(
            FetchDescriptor<Store>(sortBy: [SortDescriptor(\.sortOrder)])
        )
        XCTAssertEqual(stores.map(\.name),
                       ["Walmart", "Costco", "Stop & Shop", "Indian grocery", "Spanish grocery", "Chinese grocery"])
        XCTAssertEqual(stores.map(\.kind),
                       [.supermarket, .warehouse, .supermarket, .indian, .hispanic, .eastAsian])
    }

    @MainActor
    func testReSeedInsertsNothing() throws {
        let stack = try TestContainer.makeStack()
        StoreSeeder.seedDefaultsIfEmpty(in: stack.context)
        try stack.context.save()
        StoreSeeder.seedDefaultsIfEmpty(in: stack.context)
        try stack.context.save()

        XCTAssertEqual(try stack.context.fetch(FetchDescriptor<Store>()).count, 6)
    }

    @MainActor
    func testSortOrderIsStableAcrossSeeds() throws {
        let stack = try TestContainer.makeStack()
        StoreSeeder.seedDefaultsIfEmpty(in: stack.context)
        try stack.context.save()
        let before = try stack.context.fetch(FetchDescriptor<Store>(sortBy: [SortDescriptor(\.sortOrder)])).map(\.name)

        StoreSeeder.seedDefaultsIfEmpty(in: stack.context)
        try stack.context.save()
        let after = try stack.context.fetch(FetchDescriptor<Store>(sortBy: [SortDescriptor(\.sortOrder)])).map(\.name)

        XCTAssertEqual(before, after)
        XCTAssertEqual(Set(try stack.context.fetch(FetchDescriptor<Store>()).map(\.sortOrder)).count, 6,
                       "Every store has its own sort position.")
    }

    @MainActor
    func testGeneralStoresArePreferredAndSpecialityStoresAreNot() throws {
        let stack = try TestContainer.makeStack()
        StoreSeeder.seedDefaultsIfEmpty(in: stack.context)
        try stack.context.save()

        let byName = Dictionary(uniqueKeysWithValues: try stack.context.fetch(FetchDescriptor<Store>()).map { ($0.name, $0) })
        for name in ["Walmart", "Costco", "Stop & Shop"] {
            XCTAssertTrue(byName[name]?.isPreferred == true, "\(name) is a default weekly stop.")
        }
        for name in ["Indian grocery", "Spanish grocery", "Chinese grocery"] {
            XCTAssertFalse(byName[name]?.isPreferred == true,
                           "\(name) has no address yet — the household opts in from the store finder.")
        }
    }

    @MainActor
    func testCategoryAffinityRoutesSpecialityIngredients() throws {
        let stack = try TestContainer.makeStack()
        StoreSeeder.seedDefaultsIfEmpty(in: stack.context)
        try stack.context.save()

        let byName = Dictionary(uniqueKeysWithValues: try stack.context.fetch(FetchDescriptor<Store>()).map { ($0.name, $0) })
        let indian = try XCTUnwrap(byName["Indian grocery"])
        XCTAssertTrue(indian.handles(.legume))
        XCTAssertTrue(indian.handles(.spice))
        XCTAssertTrue(indian.handles(.flourBread))
        XCTAssertTrue(indian.handles(.dairy))
        XCTAssertFalse(indian.handles(.frozen))

        let walmart = try XCTUnwrap(byName["Walmart"])
        XCTAssertTrue(walmart.handles(.fruit))
        XCTAssertTrue(walmart.handles(.frozen))

        let chinese = try XCTUnwrap(byName["Chinese grocery"])
        XCTAssertTrue(chinese.handles(.oilCondiment))
    }

    @MainActor
    func testCoordinatesAreEmptyUntilTheUserConfirmsAStore() throws {
        let stack = try TestContainer.makeStack()
        StoreSeeder.seedDefaultsIfEmpty(in: stack.context)
        try stack.context.save()

        let stores = try stack.context.fetch(FetchDescriptor<Store>())
        XCTAssertTrue(stores.allSatisfy { $0.latitude == nil && $0.longitude == nil },
                      "Nothing is geocoded until the household taps a result in the store finder.")
        XCTAssertTrue(stores.allSatisfy { $0.address.isEmpty })
    }
}
