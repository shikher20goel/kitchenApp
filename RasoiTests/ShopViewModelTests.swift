import SwiftData
import XCTest
@testable import Rasoi

final class ShopViewModelTests: XCTestCase {
    private struct Harness {
        let stack: TestStack
        let plan: PlanViewModel
        let shop: ShopViewModel
    }

    private let monday = D.date(2026, 9, 7)

    @MainActor
    private func makeHarness() throws -> Harness {
        let stack = try TestContainer.makeStack()
        let context = stack.context
        try SeedImporter.reimport(in: context)
        StoreSeeder.seedDefaultsIfEmpty(in: context)
        context.insert(HouseholdMember(name: "Shikher", dateOfBirth: D.adultDOB, role: .adult, sortOrder: 0))
        context.insert(HouseholdMember(name: "Ira", dateOfBirth: D.youngChildDOB, role: .child, sortOrder: 1))
        try context.save()

        let clock = monday
        let plan = PlanViewModel(context: context, weekContaining: monday, now: { clock })
        let shop = ShopViewModel(context: context, weekContaining: monday, now: { clock })
        return Harness(stack: stack, plan: plan, shop: shop)
    }

    @MainActor
    func testBuildingFromThePlanFillsTheList() throws {
        let harness = try makeHarness()
        harness.plan.generateWeek()
        harness.shop.buildFromPlan()

        XCTAssertFalse(harness.shop.isEmpty)
        XCTAssertTrue(harness.shop.items.allSatisfy { $0.ingredient != nil })
        XCTAssertTrue(harness.shop.items.contains { !$0.neededFor.isEmpty },
                      "Most lines name the recipes that need them.")
        XCTAssertTrue(harness.shop.items.contains(where: \.isStapleTopUp), "Weekly staples are added.")
    }

    @MainActor
    func testBuildingTwiceNeverDuplicatesALine() throws {
        let harness = try makeHarness()
        harness.plan.generateWeek()
        harness.shop.buildFromPlan()
        let firstCount = harness.shop.items.count
        let names = harness.shop.items.compactMap { $0.ingredient?.name }

        harness.shop.buildFromPlan()

        XCTAssertEqual(harness.shop.items.count, firstCount)
        XCTAssertEqual(Set(harness.shop.items.compactMap { $0.ingredient?.name }), Set(names))
        XCTAssertEqual(try harness.stack.context.fetch(FetchDescriptor<GroceryList>()).count, 1)
    }

    @MainActor
    func testRebuildingKeepsCheckedItemsChecked() throws {
        let harness = try makeHarness()
        harness.plan.generateWeek()
        harness.shop.buildFromPlan()
        let item = try XCTUnwrap(harness.shop.items.first)
        let name = try XCTUnwrap(item.ingredient?.name)
        harness.shop.setChecked(true, for: item)

        harness.shop.buildFromPlan()

        let after = try XCTUnwrap(harness.shop.items.first { $0.ingredient?.name == name })
        XCTAssertTrue(after.isChecked, "A shopper who already grabbed it does not see it come back.")
        XCTAssertNotNil(after.checkedAt)
    }

    @MainActor
    func testCheckingAnItemPutsItInThePantryWithAnExpiry() throws {
        let harness = try makeHarness()
        harness.plan.generateWeek()
        harness.shop.buildFromPlan()

        let item = try XCTUnwrap(harness.shop.items.first { $0.ingredient?.category == .leafyGreen }
                                 ?? harness.shop.items.first)
        let ingredient = try XCTUnwrap(item.ingredient)
        harness.shop.setChecked(true, for: item)

        let location = ShopViewModel.location(for: ingredient.category)
        let stocked = try XCTUnwrap(PantryItem.existing(for: ingredient, location: location,
                                                        in: harness.stack.context))
        XCTAssertEqual(stocked.quantity, item.quantity, accuracy: 0.0001)
        XCTAssertEqual(stocked.source, .shop)
        XCTAssertEqual(stocked.expiresAt,
                       ShelfLife.expiry(shelfLifeDays: ingredient.typicalShelfLifeDays,
                                        addedAt: monday, location: location))
    }

    @MainActor
    func testUncheckingTakesItBackOutOfThePantry() throws {
        let harness = try makeHarness()
        harness.plan.generateWeek()
        harness.shop.buildFromPlan()

        let item = try XCTUnwrap(harness.shop.items.first)
        let ingredient = try XCTUnwrap(item.ingredient)
        harness.shop.setChecked(true, for: item)
        harness.shop.setChecked(false, for: item)

        let location = ShopViewModel.location(for: ingredient.category)
        let stocked = PantryItem.existing(for: ingredient, location: location, in: harness.stack.context)
        XCTAssertTrue(stocked == nil || stocked?.quantity == 0, "A mis-tap does not leave phantom stock.")
        XCTAssertFalse(item.isChecked)
        XCTAssertNil(item.checkedAt)
    }

    @MainActor
    func testCheckingTwiceDoesNotDoubleStock() throws {
        let harness = try makeHarness()
        harness.plan.generateWeek()
        harness.shop.buildFromPlan()
        let item = try XCTUnwrap(harness.shop.items.first)
        let ingredient = try XCTUnwrap(item.ingredient)

        harness.shop.setChecked(true, for: item)
        harness.shop.setChecked(true, for: item)

        let location = ShopViewModel.location(for: ingredient.category)
        let stocked = try XCTUnwrap(PantryItem.existing(for: ingredient, location: location,
                                                        in: harness.stack.context))
        XCTAssertEqual(stocked.quantity, item.quantity, accuracy: 0.0001)
    }

    @MainActor
    func testAManualItemIsKeptThroughARebuild() throws {
        let harness = try makeHarness()
        harness.plan.generateWeek()
        harness.shop.buildFromPlan()

        let towels = Ingredient(name: "Paper towels", category: .other, defaultUnit: .count,
                                typicalShelfLifeDays: 3650)
        harness.stack.context.insert(towels)
        harness.shop.addManualItem(towels, quantity: 2)

        harness.shop.buildFromPlan()
        let manual = try XCTUnwrap(harness.shop.items.first { $0.ingredient?.name == "Paper towels" })
        XCTAssertTrue(manual.addedManually)
        XCTAssertEqual(manual.quantity, 2, accuracy: 0.0001)
    }

    @MainActor
    func testCookedMealsAreNotShoppedFor() throws {
        let harness = try makeHarness()
        harness.plan.generateWeek()
        // Pick a meal whose recipe is planned only once, so "cooked" really does remove it.
        let counts = harness.plan.slots.compactMap { $0.recipe?.title }
            .reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        let slot = try XCTUnwrap(harness.plan.slots.first {
            $0.mealType == .dinner && counts[$0.recipe?.title ?? ""] == 1
        })
        let title = try XCTUnwrap(slot.recipe?.title)
        harness.plan.setStatus(.cooked, for: slot)

        harness.shop.buildFromPlan()
        XCTAssertFalse(harness.shop.items.contains { $0.neededFor.contains(title) },
                       "Dinner that is already on the table is not on the list.")
    }

    @MainActor
    func testSectionsAreGroupedByStoreThenCategory() throws {
        let harness = try makeHarness()
        harness.plan.generateWeek()
        harness.shop.buildFromPlan()

        let sections = harness.shop.sections
        XCTAssertFalse(sections.isEmpty)
        XCTAssertEqual(sections.map(\.storeName), sections.map(\.storeName).sorted { left, right in
            let order = Dictionary(uniqueKeysWithValues: harness.shop.stores.map { ($0.name, $0.sortOrder) })
            let leftOrder = order[left] ?? Int.max
            let rightOrder = order[right] ?? Int.max
            return leftOrder == rightOrder ? left < right : leftOrder < rightOrder
        })
        for section in sections {
            XCTAssertFalse(section.categories.isEmpty)
            for category in section.categories {
                XCTAssertTrue(category.items.allSatisfy { $0.ingredient?.category == category.category })
            }
        }
    }

    @MainActor
    func testShareTextIsGroupedAndReadable() throws {
        let harness = try makeHarness()
        harness.plan.generateWeek()
        harness.shop.buildFromPlan()
        let item = try XCTUnwrap(harness.shop.items.first)
        harness.shop.setChecked(true, for: item)

        let text = harness.shop.shareText()
        XCTAssertTrue(text.hasPrefix("Rasoi — shopping for"))
        XCTAssertTrue(text.contains("[x]"), "Checked items are ticked.")
        XCTAssertTrue(text.contains("[ ]"))
        for section in harness.shop.sections {
            XCTAssertTrue(text.contains(section.storeName))
        }
    }

    @MainActor
    func testRemovingALine() throws {
        let harness = try makeHarness()
        harness.plan.generateWeek()
        harness.shop.buildFromPlan()
        let item = try XCTUnwrap(harness.shop.items.first)
        let name = try XCTUnwrap(item.ingredient?.name)

        harness.shop.remove(item)
        XCTAssertFalse(harness.shop.items.contains { $0.ingredient?.name == name })
    }
}
