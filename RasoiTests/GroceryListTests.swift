import SwiftData
import XCTest
@testable import Rasoi

final class GroceryListTests: XCTestCase {
    @MainActor
    private func makeList(_ stack: TestStack) -> GroceryList {
        GroceryList.list(forWeekContaining: D.date(2026, 9, 9), in: stack.context)
    }

    @MainActor
    func testListIsCreatedForTheMondayOfTheWeek() throws {
        let stack = try TestContainer.makeStack()
        let list = makeList(stack)
        try stack.context.save()

        XCTAssertEqual(list.weekStart, Calendar.rasoi.startOfDay(for: D.date(2026, 9, 7)))
        XCTAssertFalse(list.isFinalized)
        XCTAssertTrue(list.items.isEmpty)
    }

    @MainActor
    func testWeekStartIsUnique() throws {
        let stack = try TestContainer.makeStack()
        _ = makeList(stack)
        try stack.context.save()
        let second = GroceryList.list(forWeekContaining: D.date(2026, 9, 12), in: stack.context)
        second.isFinalized = true
        try stack.context.save()

        let lists = try stack.context.fetch(FetchDescriptor<GroceryList>())
        XCTAssertEqual(lists.count, 1, "One list per week.")
        XCTAssertTrue(lists.first?.isFinalized == true)
    }

    @MainActor
    func testItemsBelongToTheList() throws {
        let stack = try TestContainer.makeStack()
        let list = makeList(stack)
        let spinach = Ingredient(name: "Spinach", category: .leafyGreen, defaultUnit: .gram, typicalShelfLifeDays: 5)
        stack.context.insert(spinach)

        let item = GroceryItem(list: list, ingredient: spinach, quantity: 300, unit: .gram,
                               neededFor: ["Palak paneer", "Green smoothie"])
        stack.context.insert(item)
        list.items.append(item)
        try stack.context.save()

        let reloaded = try XCTUnwrap(try stack.context.fetch(FetchDescriptor<GroceryList>()).first)
        XCTAssertEqual(reloaded.items.count, 1)
        XCTAssertEqual(reloaded.items.first?.neededFor, ["Palak paneer", "Green smoothie"])
        XCTAssertEqual(reloaded.items.first?.ingredient?.name, "Spinach")
        XCTAssertNil(reloaded.items.first?.store, "A store is assigned by the builder, not required.")
        XCTAssertFalse(reloaded.items.first?.isStapleTopUp == true)
        XCTAssertFalse(reloaded.items.first?.addedManually == true)
    }

    @MainActor
    func testCheckingAnItemStampsTheTime() throws {
        let stack = try TestContainer.makeStack()
        let list = makeList(stack)
        let rice = Ingredient(name: "Basmati rice", category: .grain, defaultUnit: .gram, typicalShelfLifeDays: 365)
        stack.context.insert(rice)
        let item = GroceryItem(list: list, ingredient: rice, quantity: 1000, unit: .gram)
        stack.context.insert(item)
        list.items.append(item)

        let checkedAt = D.date(2026, 9, 13, hour: 11)
        item.setChecked(true, on: checkedAt)
        XCTAssertTrue(item.isChecked)
        XCTAssertEqual(item.checkedAt, checkedAt)

        item.setChecked(false, on: D.date(2026, 9, 13, hour: 12))
        XCTAssertFalse(item.isChecked)
        XCTAssertNil(item.checkedAt, "Unchecking clears the time so nothing restocks twice.")
    }

    @MainActor
    func testDeletingAListRemovesItsItems() throws {
        let stack = try TestContainer.makeStack()
        let list = makeList(stack)
        let oats = Ingredient(name: "Rolled oats", category: .grain, defaultUnit: .gram, typicalShelfLifeDays: 180)
        stack.context.insert(oats)
        let item = GroceryItem(list: list, ingredient: oats, quantity: 500, unit: .gram)
        stack.context.insert(item)
        list.items.append(item)
        try stack.context.save()

        stack.context.delete(list)
        try stack.context.save()
        XCTAssertEqual(try stack.context.fetch(FetchDescriptor<GroceryItem>()).count, 0)
    }

    @MainActor
    func testStoreAssignmentAndManualItems() throws {
        let stack = try TestContainer.makeStack()
        let list = makeList(stack)
        StoreSeeder.seedDefaultsIfEmpty(in: stack.context)
        try stack.context.save()
        let walmart = try XCTUnwrap(try stack.context.fetch(FetchDescriptor<Store>()).first { $0.name == "Walmart" })

        let batteries = Ingredient(name: "Paper towels", category: .other, defaultUnit: .count, typicalShelfLifeDays: 3650)
        stack.context.insert(batteries)
        let item = GroceryItem(list: list, ingredient: batteries, quantity: 1, unit: .count,
                               store: walmart, addedManually: true)
        stack.context.insert(item)
        list.items.append(item)
        try stack.context.save()

        let reloaded = try XCTUnwrap(try stack.context.fetch(FetchDescriptor<GroceryItem>()).first)
        XCTAssertEqual(reloaded.store?.name, "Walmart")
        XCTAssertTrue(reloaded.addedManually)
    }
}
