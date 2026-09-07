import SwiftData
import XCTest
@testable import Rasoi

final class IngredientTests: XCTestCase {
    @MainActor
    private func makeToorDal() -> Ingredient {
        Ingredient(
            name: "Toor dal",
            aliases: ["arhar dal", "split pigeon peas", "tuvar dal"],
            category: .legume,
            defaultUnit: .gram,
            typicalShelfLifeDays: 365,
            isStaple: true,
            defaultStoreKind: .indian,
            nutritionTags: ["protein", "iron", "fibre"]
        )
    }

    @MainActor
    func testCategoryAndStoreKindRoundTrip() throws {
        let stack = try TestContainer.makeStack()
        stack.context.insert(makeToorDal())
        try stack.context.save()

        let fetched = try XCTUnwrap(try stack.context.fetch(FetchDescriptor<Ingredient>()).first)
        XCTAssertEqual(fetched.category, .legume)
        XCTAssertEqual(fetched.defaultStoreKind, .indian)
        XCTAssertEqual(fetched.defaultUnit, .gram)
        XCTAssertEqual(fetched.nutritionTags, ["protein", "iron", "fibre"])
        XCTAssertTrue(fetched.isStaple)
        XCTAssertFalse(fetched.isQuickHealthySnack)
    }

    @MainActor
    func testNameIsUnique() throws {
        let stack = try TestContainer.makeStack()
        stack.context.insert(makeToorDal())
        try stack.context.save()
        stack.context.insert(
            Ingredient(name: "Toor dal", category: .legume, defaultUnit: .gram, typicalShelfLifeDays: 400)
        )
        try stack.context.save()

        let all = try stack.context.fetch(FetchDescriptor<Ingredient>())
        XCTAssertEqual(all.count, 1, "Ingredient names are unique — a second insert upserts.")
        XCTAssertEqual(all.first?.typicalShelfLifeDays, 400)
    }

    @MainActor
    func testLookupByExactName() throws {
        let stack = try TestContainer.makeStack()
        stack.context.insert(makeToorDal())
        try stack.context.save()

        XCTAssertEqual(Ingredient.named("Toor dal", in: stack.context)?.name, "Toor dal")
        XCTAssertEqual(Ingredient.named("toor dal", in: stack.context)?.name, "Toor dal",
                       "Name lookup ignores case so seed data and typed text meet.")
        XCTAssertNil(Ingredient.named("Chicken", in: stack.context))
    }

    @MainActor
    func testTypeAheadFindsToorDalFromAPartialName() throws {
        let stack = try TestContainer.makeStack()
        let toor = makeToorDal()
        let tofu = Ingredient(name: "Tofu", category: .legume, defaultUnit: .gram, typicalShelfLifeDays: 10)
        stack.context.insert(toor)
        stack.context.insert(tofu)
        try stack.context.save()

        let all = try stack.context.fetch(FetchDescriptor<Ingredient>())
        XCTAssertEqual(Ingredient.search("toor", in: all).map(\.name), ["Toor dal"])
        XCTAssertEqual(Ingredient.search("Toor", in: all).map(\.name), ["Toor dal"])
        XCTAssertEqual(Ingredient.search("to", in: all).map(\.name), ["Tofu", "Toor dal"],
                       "Prefix matches come back alphabetically so the list never jumps around.")
    }

    @MainActor
    func testTypeAheadMatchesAliases() throws {
        let stack = try TestContainer.makeStack()
        stack.context.insert(makeToorDal())
        try stack.context.save()

        let all = try stack.context.fetch(FetchDescriptor<Ingredient>())
        XCTAssertEqual(Ingredient.search("arhar", in: all).map(\.name), ["Toor dal"])
        XCTAssertEqual(Ingredient.search("pigeon peas", in: all).map(\.name), ["Toor dal"])
        XCTAssertTrue(Ingredient.search("beef", in: all).isEmpty)
    }

    @MainActor
    func testExactNameOutranksAliasMatch() throws {
        let stack = try TestContainer.makeStack()
        let dal = makeToorDal()
        let confusable = Ingredient(name: "Dal makhani mix", aliases: ["toor blend"], category: .legume,
                                    defaultUnit: .gram, typicalShelfLifeDays: 200)
        stack.context.insert(dal)
        stack.context.insert(confusable)
        try stack.context.save()

        let all = try stack.context.fetch(FetchDescriptor<Ingredient>())
        XCTAssertEqual(Ingredient.search("toor", in: all).map(\.name), ["Toor dal", "Dal makhani mix"])
    }

    @MainActor
    func testAllergenFlagsRoundTrip() throws {
        let stack = try TestContainer.makeStack()
        let paneer = Ingredient(name: "Paneer", category: .dairy, defaultUnit: .gram,
                                typicalShelfLifeDays: 7, containsDairy: true)
        stack.context.insert(paneer)
        try stack.context.save()

        let fetched = try XCTUnwrap(try stack.context.fetch(FetchDescriptor<Ingredient>()).first)
        XCTAssertTrue(fetched.containsDairy)
        XCTAssertFalse(fetched.containsEgg)
        XCTAssertFalse(fetched.containsNuts)
        XCTAssertFalse(fetched.containsGluten)
    }
}
