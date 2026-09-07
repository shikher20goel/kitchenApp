import XCTest
@testable import Rasoi

final class DietFilterTests: XCTestCase {
    private let index = Fixtures.index

    private func rules(
        eggsOK: Bool = true,
        dairyOK: Bool = true,
        nutFree: Bool = false,
        glutenFree: Bool = false,
        excluded: [String] = [],
        appliances: Set<Appliance> = [.instantPot, .vitamix, .stovetop, .oven]
    ) -> DietRules {
        DietRules(
            isVegetarian: true,
            eggsOK: eggsOK,
            dairyOK: dairyOK,
            nutFree: nutFree,
            glutenFree: glutenFree,
            excludedIngredients: excluded,
            appliances: appliances
        )
    }

    // MARK: - One rule at a time

    func testAPlainRecipePasses() {
        let dal = Fixtures.recipe(id: "dal", ingredients: [("Toor dal", 200, .gram, false)])
        XCTAssertTrue(DietFilter.eligible(dal, rules: rules(), index: index, youngestAgeYears: 4))
        XCTAssertNil(DietFilter.reasonRejected(dal, rules: rules(), index: index, youngestAgeYears: 4))
    }

    func testEggRecipeIsHiddenWhenEggsAreOff() {
        let bhurji = Fixtures.recipe(id: "bhurji", ingredients: [("Egg", 4, .count, false)], egg: true)
        XCTAssertTrue(DietFilter.eligible(bhurji, rules: rules(), index: index, youngestAgeYears: 4))
        XCTAssertFalse(DietFilter.eligible(bhurji, rules: rules(eggsOK: false), index: index, youngestAgeYears: 4))
        XCTAssertEqual(
            DietFilter.reasonRejected(bhurji, rules: rules(eggsOK: false), index: index, youngestAgeYears: 4),
            "Has egg"
        )
    }

    func testDairyRecipeIsHiddenWhenDairyIsOff() {
        let paneer = Fixtures.recipe(id: "paneer", ingredients: [("Paneer", 300, .gram, false)], dairy: true)
        XCTAssertFalse(DietFilter.eligible(paneer, rules: rules(dairyOK: false), index: index, youngestAgeYears: 4))
        XCTAssertEqual(
            DietFilter.reasonRejected(paneer, rules: rules(dairyOK: false), index: index, youngestAgeYears: 4),
            "Has dairy"
        )
    }

    func testNutFreeHidesNutRecipes() {
        let korma = Fixtures.recipe(id: "korma", ingredients: [("Cashews", 40, .gram, false)], nuts: true)
        XCTAssertFalse(DietFilter.eligible(korma, rules: rules(nutFree: true), index: index, youngestAgeYears: 4))
        XCTAssertEqual(
            DietFilter.reasonRejected(korma, rules: rules(nutFree: true), index: index, youngestAgeYears: 4),
            "Has nuts"
        )
    }

    func testGlutenFreeHidesGlutenRecipes() {
        let pasta = Fixtures.recipe(id: "pasta", ingredients: [("Whole wheat pasta", 350, .gram, false)], gluten: true)
        XCTAssertFalse(DietFilter.eligible(pasta, rules: rules(glutenFree: true), index: index, youngestAgeYears: 4))
    }

    func testExcludedIngredientHidesTheRecipeThroughAnAlias() {
        // The household types "palak"; the recipe lists "Spinach".
        let palakPaneer = Fixtures.recipe(
            id: "palak-paneer",
            title: "Palak Paneer",
            ingredients: [("Spinach", 400, .gram, false), ("Paneer", 300, .gram, false)],
            dairy: true
        )
        let excluding = rules(excluded: ["palak"])
        XCTAssertFalse(DietFilter.eligible(palakPaneer, rules: excluding, index: index, youngestAgeYears: 4))
        XCTAssertEqual(
            DietFilter.reasonRejected(palakPaneer, rules: excluding, index: index, youngestAgeYears: 4),
            "You've excluded Spinach"
        )
    }

    func testExcludingByTheCatalogNameAlsoWorks() {
        let dalPalak = Fixtures.recipe(id: "dal-palak", ingredients: [("Spinach", 200, .gram, false)])
        XCTAssertFalse(DietFilter.eligible(dalPalak, rules: rules(excluded: ["Spinach"]), index: index, youngestAgeYears: 4))
    }

    func testAnOptionalExcludedIngredientDoesNotHideTheRecipe() {
        let curry = Fixtures.recipe(
            id: "curry",
            ingredients: [("Rice", 200, .gram, false), ("Mushroom", 100, .gram, true)]
        )
        XCTAssertTrue(DietFilter.eligible(curry, rules: rules(excluded: ["mushroom"]), index: index, youngestAgeYears: 4),
                      "An optional ingredient can simply be left out.")
    }

    func testMissingApplianceHidesTheRecipe() {
        let smoothie = Fixtures.recipe(id: "smoothie", mealTypes: [.snack], appliances: [.vitamix])
        let noVitamix = rules(appliances: [.stovetop, .oven])
        XCTAssertFalse(DietFilter.eligible(smoothie, rules: noVitamix, index: index, youngestAgeYears: 4))
        XCTAssertEqual(
            DietFilter.reasonRejected(smoothie, rules: noVitamix, index: index, youngestAgeYears: 4),
            "Needs a Vitamix"
        )
    }

    func testRecipeNeedingEveryApplianceTheKitchenHasIsFine() {
        let both = Fixtures.recipe(id: "both", appliances: [.instantPot, .stovetop])
        XCTAssertTrue(DietFilter.eligible(both, rules: rules(), index: index, youngestAgeYears: 4))
    }

    func testMinimumAgeComparesAgainstTheYoungestAtTheTable() {
        let spicy = Fixtures.recipe(id: "spicy", minAgeYears: 6)
        XCTAssertFalse(DietFilter.eligible(spicy, rules: rules(), index: index, youngestAgeYears: 4))
        XCTAssertEqual(
            DietFilter.reasonRejected(spicy, rules: rules(), index: index, youngestAgeYears: 4),
            "Better from age 6"
        )
        XCTAssertTrue(DietFilter.eligible(spicy, rules: rules(), index: index, youngestAgeYears: 6))
    }

    func testNonVegetarianIngredientIsRejectedEvenIfItSlipsIntoTheCatalog() {
        let index = IngredientIndex(facts: Fixtures.index.allFacts + [Fixtures.facts("Chicken thigh")])
        let notVeg = Fixtures.recipe(id: "oops", ingredients: [("Chicken thigh", 200, .gram, false)])
        XCTAssertFalse(DietFilter.eligible(notVeg, rules: rules(), index: index, youngestAgeYears: 4))
        XCTAssertEqual(
            DietFilter.reasonRejected(notVeg, rules: rules(), index: index, youngestAgeYears: 4),
            "Not vegetarian"
        )
    }

    // MARK: - Combined

    func testCombinedRulesReportTheFirstReasonOnly() {
        let heavy = Fixtures.recipe(
            id: "heavy",
            appliances: [.vitamix],
            minAgeYears: 8,
            ingredients: [("Paneer", 200, .gram, false)],
            dairy: true
        )
        let strict = rules(dairyOK: false, appliances: [.stovetop])
        XCTAssertFalse(DietFilter.eligible(heavy, rules: strict, index: index, youngestAgeYears: 4))
        XCTAssertEqual(DietFilter.reasonRejected(heavy, rules: strict, index: index, youngestAgeYears: 4), "Has dairy",
                       "One clear reason is enough for the UI; diet comes before equipment.")
    }

    func testFilteringACollectionKeepsInputOrder() {
        let recipes = [
            Fixtures.recipe(id: "a"),
            Fixtures.recipe(id: "b", ingredients: [("Egg", 2, .count, false)], egg: true),
            Fixtures.recipe(id: "c"),
        ]
        let eligible = DietFilter.eligible(recipes, rules: rules(eggsOK: false), index: index, youngestAgeYears: 4)
        XCTAssertEqual(eligible.map(\.id), ["a", "c"])
    }

    func testUnknownIngredientsDoNotBlockARecipe() {
        let mystery = Fixtures.recipe(id: "mystery", ingredients: [("Grandma's masala", 10, .gram, false)])
        XCTAssertTrue(DietFilter.eligible(mystery, rules: rules(), index: index, youngestAgeYears: 4),
                      "A user recipe with an ingredient outside the catalog is still cookable.")
    }
}
