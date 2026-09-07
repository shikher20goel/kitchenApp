import SwiftData
import XCTest
@testable import Rasoi

final class DataManagerTests: XCTestCase {
    @MainActor
    func testDeleteEverythingClearsHouseholdDataAndRestoresTheCatalog() throws {
        let stack = try TestContainer.makeStack()
        let context = stack.context

        StoreSeeder.seedDefaultsIfEmpty(in: context)
        try SeedImporter.reimport(in: context)
        let profile = DietProfile.current(in: context)
        profile.hasCompletedOnboarding = true
        profile.excludedIngredients = ["Spinach"]

        let child = HouseholdMember(name: "Ira", dateOfBirth: D.youngChildDOB, role: .child)
        context.insert(child)
        let spinach = try XCTUnwrap(Ingredient.named("Spinach", in: context))
        PantryItem.add(spinach, quantity: 200, unit: .gram, location: .fridge, on: D.date(2026, 9, 1), in: context)
        let plan = MealPlan.plan(forWeekContaining: D.date(2026, 9, 9), in: context)
        let slot = MealSlot.slot(in: plan, on: D.date(2026, 9, 9), mealType: .dinner, in: context)
        MealFeedback.record(.ateAll, for: slot, member: child, on: D.date(2026, 9, 9), in: context)
        let list = GroceryList.list(forWeekContaining: D.date(2026, 9, 9), in: context)
        context.insert(GroceryItem(list: list, ingredient: spinach, quantity: 100, unit: .gram))
        try context.save()

        try DataManager.deleteEverything(in: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<HouseholdMember>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PantryItem>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<MealPlan>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<MealSlot>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<MealFeedback>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<GroceryList>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<GroceryItem>()).count, 0)

        XCTAssertGreaterThanOrEqual(try context.fetch(FetchDescriptor<Ingredient>()).count, 180,
                                    "The catalog is put back as it shipped.")
        XCTAssertGreaterThanOrEqual(try context.fetch(FetchDescriptor<Recipe>()).count, 50)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Store>()).count, 6)

        let fresh = DietProfile.current(in: context)
        XCTAssertFalse(fresh.hasCompletedOnboarding, "The app returns to onboarding, like a new install.")
        XCTAssertEqual(fresh.excludedIngredients, [])
        XCTAssertEqual(try context.fetch(FetchDescriptor<DietProfile>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<AppSettings>()).count, 1)
    }

    @MainActor
    func testDeleteEverythingOnAnEmptyStoreStillLeavesAWorkingApp() throws {
        let stack = try TestContainer.makeStack()
        try DataManager.deleteEverything(in: stack.context)

        XCTAssertEqual(try stack.context.fetch(FetchDescriptor<Store>()).count, 6)
        XCTAssertGreaterThanOrEqual(try stack.context.fetch(FetchDescriptor<Recipe>()).count, 50)
    }
}
