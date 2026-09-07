import SwiftData
import XCTest
@testable import Rasoi

final class PantryItemTests: XCTestCase {
    @MainActor
    private func spinach(in context: ModelContext) -> Ingredient {
        let ingredient = Ingredient(name: "Spinach", category: .leafyGreen, defaultUnit: .gram,
                                    typicalShelfLifeDays: 5)
        context.insert(ingredient)
        return ingredient
    }

    @MainActor
    func testUpsertCreatesThenAddsToTheSameRow() throws {
        let stack = try TestContainer.makeStack()
        let ingredient = spinach(in: stack.context)

        PantryItem.add(ingredient, quantity: 200, unit: .gram, location: .fridge,
                       on: D.date(2026, 9, 1), source: .manual, in: stack.context)
        PantryItem.add(ingredient, quantity: 150, unit: .gram, location: .fridge,
                       on: D.date(2026, 9, 3), source: .shop, in: stack.context)
        try stack.context.save()

        let items = try stack.context.fetch(FetchDescriptor<PantryItem>())
        XCTAssertEqual(items.count, 1, "One row per ingredient + location.")
        XCTAssertEqual(items.first?.quantity, 350)
        XCTAssertEqual(items.first?.expiresAt, D.date(2026, 9, 8),
                       "Restocking pushes the expiry out from the newest addition.")
    }

    @MainActor
    func testSameIngredientInADifferentLocationIsASeparateRow() throws {
        let stack = try TestContainer.makeStack()
        let ingredient = spinach(in: stack.context)

        PantryItem.add(ingredient, quantity: 200, unit: .gram, location: .fridge,
                       on: D.date(2026, 9, 1), in: stack.context)
        PantryItem.add(ingredient, quantity: 500, unit: .gram, location: .freezer,
                       on: D.date(2026, 9, 1), in: stack.context)
        try stack.context.save()

        let items = try stack.context.fetch(FetchDescriptor<PantryItem>())
        XCTAssertEqual(items.count, 2)
        let freezer = try XCTUnwrap(items.first { $0.location == .freezer })
        XCTAssertEqual(freezer.expiresAt, D.date(2026, 10, 1), "5 days × 6 in the freezer.")
    }

    @MainActor
    func testAddingInADifferentUnitConvertsToTheStoredUnit() throws {
        let stack = try TestContainer.makeStack()
        let ingredient = spinach(in: stack.context)

        PantryItem.add(ingredient, quantity: 200, unit: .gram, location: .fridge,
                       on: D.date(2026, 9, 1), in: stack.context)
        PantryItem.add(ingredient, quantity: 1, unit: .kilogram, location: .fridge,
                       on: D.date(2026, 9, 1), in: stack.context)
        try stack.context.save()

        let item = try XCTUnwrap(try stack.context.fetch(FetchDescriptor<PantryItem>()).first)
        XCTAssertEqual(item.quantity, 1200)
        XCTAssertEqual(item.unit, .gram)
    }

    @MainActor
    func testConsumeFloorsAtZeroAndRemovesNonStaples() throws {
        let stack = try TestContainer.makeStack()
        let ingredient = spinach(in: stack.context)
        PantryItem.add(ingredient, quantity: 200, unit: .gram, location: .fridge,
                       on: D.date(2026, 9, 1), in: stack.context)
        try stack.context.save()

        let item = try XCTUnwrap(try stack.context.fetch(FetchDescriptor<PantryItem>()).first)
        item.consume(quantity: 250, unit: .gram)
        XCTAssertEqual(item.quantity, 0, "Quantities never go negative.")
        XCTAssertTrue(item.isEmpty)
    }

    @MainActor
    func testExpiringSoonUsesTheStoredExpiry() throws {
        let stack = try TestContainer.makeStack()
        let ingredient = spinach(in: stack.context)
        PantryItem.add(ingredient, quantity: 200, unit: .gram, location: .fridge,
                       on: D.date(2026, 9, 5), in: stack.context)
        try stack.context.save()

        let item = try XCTUnwrap(try stack.context.fetch(FetchDescriptor<PantryItem>()).first)
        XCTAssertEqual(item.expiresAt, D.date(2026, 9, 10))
        XCTAssertTrue(item.isExpiringSoon(on: D.date(2026, 9, 8)))
        XCTAssertFalse(item.isExpiringSoon(on: D.date(2026, 9, 7)))
    }

    @MainActor
    func testSourceAndLowThresholdRoundTrip() throws {
        let stack = try TestContainer.makeStack()
        let ingredient = spinach(in: stack.context)
        PantryItem.add(ingredient, quantity: 200, unit: .gram, location: .pantry,
                       on: D.date(2026, 9, 1), source: .seed, in: stack.context)
        try stack.context.save()

        let item = try XCTUnwrap(try stack.context.fetch(FetchDescriptor<PantryItem>()).first)
        item.lowThreshold = 50
        try stack.context.save()

        let reloaded = try XCTUnwrap(try stack.context.fetch(FetchDescriptor<PantryItem>()).first)
        XCTAssertEqual(reloaded.source, .seed)
        XCTAssertEqual(reloaded.lowThreshold, 50)
        XCTAssertFalse(reloaded.isLow, "200 g is well above the 50 g threshold.")
    }
}
