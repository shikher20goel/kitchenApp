import XCTest
@testable import Rasoi

final class NutritionCoverageTests: XCTestCase {
    private let index = IngredientIndex(facts: [
        Fixtures.facts("Moong dal", category: .legume, nutritionTags: ["protein", "iron"]),
        Fixtures.facts("Basmati rice", category: .grain, nutritionTags: ["grain"]),
        Fixtures.facts("Brown rice", category: .grain, nutritionTags: ["grain", "wholeGrain"]),
        Fixtures.facts("Carrot", category: .vegetable, nutritionTags: ["vegetable"]),
        Fixtures.facts("Spinach", category: .leafyGreen, nutritionTags: ["vegetable", "iron"]),
        Fixtures.facts("Banana", category: .fruit, unit: .count, nutritionTags: ["fruit"]),
        Fixtures.facts("Plain yogurt", category: .dairy, nutritionTags: ["calcium", "protein"]),
        Fixtures.facts("Whole wheat pasta", category: .grain, nutritionTags: ["grain", "wholeGrain"], gluten: true),
        Fixtures.facts("Tomato", category: .vegetable, nutritionTags: ["vegetable"]),
    ])

    private func recipe(_ id: String, ingredients: [String], tags: [String] = []) -> RecipeSummary {
        Fixtures.recipe(
            id: id,
            ingredients: ingredients.map { ($0, 100, MeasurementUnit.gram, false) },
            nutritionTags: tags
        )
    }

    private let khichdi = "khichdi"

    // MARK: - One recipe

    func testGroupsComeFromIngredientsAndTags() {
        let dish = recipe(khichdi, ingredients: ["Moong dal", "Basmati rice", "Carrot"])
        let groups = NutritionCoverage.groups(for: dish, index: index)
        XCTAssertEqual(groups, [.protein, .grain, .vegetable])
    }

    func testAWholeGrainIsNoticed() {
        let brown = recipe("brown", ingredients: ["Brown rice"])
        XCTAssertTrue(NutritionCoverage.includesWholeGrain(brown, index: index))
        let white = recipe("white", ingredients: ["Basmati rice"])
        XCTAssertFalse(NutritionCoverage.includesWholeGrain(white, index: index))
    }

    func testARecipeTagCountsEvenWhenTheIngredientIsUnknown() {
        let mystery = recipe("mystery", ingredients: ["Grandma's masala"], tags: ["fruit", "protein"])
        XCTAssertEqual(NutritionCoverage.groups(for: mystery, index: index), [.fruit, .protein])
    }

    func testDairyIsItsOwnGroupAndAlsoCountsAsProtein() {
        let yogurt = recipe("yogurt", ingredients: ["Plain yogurt"])
        let groups = NutritionCoverage.groups(for: yogurt, index: index)
        XCTAssertTrue(groups.contains(.dairy))
        XCTAssertTrue(groups.contains(.protein), "Yogurt is tagged protein in the catalog.")
    }

    // MARK: - One day

    func testAKhichdiDayCoversEveryGroup() {
        let day = NutritionCoverage.day(
            [
                recipe(khichdi, ingredients: ["Moong dal", "Basmati rice", "Carrot", "Spinach"]),
                recipe("fruit-snack", ingredients: ["Banana"]),
                recipe("yogurt", ingredients: ["Plain yogurt"]),
            ],
            on: D.date(2026, 9, 7),
            index: index
        )
        for group in MyPlateGroup.allCases {
            XCTAssertTrue(day.covers(group), "\(group) should be covered")
        }
        XCTAssertTrue(day.missing.isEmpty)
    }

    func testAPastaOnlyDayIsLightOnFruitAndProtein() {
        let day = NutritionCoverage.day(
            [recipe("pasta", ingredients: ["Whole wheat pasta", "Tomato"])],
            on: D.date(2026, 9, 7),
            index: index
        )
        XCTAssertTrue(day.covers(.grain))
        XCTAssertTrue(day.covers(.vegetable))
        XCTAssertFalse(day.covers(.fruit))
        XCTAssertFalse(day.covers(.protein))
        XCTAssertFalse(day.covers(.dairy))
        XCTAssertEqual(day.missing.sorted { $0.rawValue < $1.rawValue }, [.dairy, .fruit, .protein])
        XCTAssertTrue(day.hasWholeGrain)
    }

    func testAnEmptyDayCoversNothing() {
        let day = NutritionCoverage.day([], on: D.date(2026, 9, 7), index: index)
        XCTAssertTrue(day.covered.isEmpty)
        XCTAssertFalse(day.hasWholeGrain)
    }

    // MARK: - A week

    func testTheWeeklyHintNamesTheGroupMissingOnMostDays() {
        let week = MealPlan.days(ofWeekContaining: D.date(2026, 9, 7))
        var meals: [(Date, RecipeSummary)] = []
        for (offset, day) in week.enumerated() {
            meals.append((day, recipe("grain-\(offset)", ingredients: ["Basmati rice"])))
            meals.append((day, recipe("veg-\(offset)", ingredients: ["Carrot"])))
            meals.append((day, recipe("dal-\(offset)", ingredients: ["Moong dal"])))
            meals.append((day, recipe("dairy-\(offset)", ingredients: ["Plain yogurt"])))
            // Fruit only on two days out of seven.
            if offset < 2 {
                meals.append((day, recipe("fruit-\(offset)", ingredients: ["Banana"])))
            }
        }

        let coverage = NutritionCoverage.week(meals, index: index)
        XCTAssertEqual(coverage.days.count, 7)
        XCTAssertEqual(coverage.lightestGroup, .fruit)
        XCTAssertEqual(coverage.daysCovering(.fruit), 2)
        XCTAssertEqual(coverage.daysCovering(.vegetable), 7)
    }

    func testAWellCoveredWeekHasNoHint() {
        let week = MealPlan.days(ofWeekContaining: D.date(2026, 9, 7))
        let meals = week.flatMap { day in
            [
                (day, recipe("all-\(day.timeIntervalSince1970)",
                             ingredients: ["Moong dal", "Brown rice", "Carrot", "Banana", "Plain yogurt"])),
            ]
        }
        let coverage = NutritionCoverage.week(meals, index: index)
        XCTAssertNil(coverage.lightestGroup, "Nothing to nudge about.")
        XCTAssertEqual(coverage.wholeGrainDays, 7)
    }

    func testWeeklyCoverageIsDeterministic() {
        let day = D.date(2026, 9, 7)
        let meals = [(day, recipe("a", ingredients: ["Carrot"])), (day, recipe("b", ingredients: ["Banana"]))]
        XCTAssertEqual(NutritionCoverage.week(meals, index: index).lightestGroup,
                       NutritionCoverage.week(meals.reversed(), index: index).lightestGroup)
    }

    // MARK: - Age bands

    func testTargetsExistForEveryBand() {
        for band in AgeBand.allCases {
            let targets = NutritionCoverage.targets(for: band)
            XCTAssertGreaterThan(targets.fruitCups.lowerBound, 0, "\(band) needs fruit targets")
            XCTAssertGreaterThan(targets.vegetableCups.lowerBound, 0)
            XCTAssertGreaterThan(targets.grainOunceEquivalents.lowerBound, 0)
            XCTAssertGreaterThan(targets.proteinOunceEquivalents.lowerBound, 0)
            XCTAssertGreaterThan(targets.dairyCups.lowerBound, 0)
        }
    }

    func testTheSpecTablesForChildAndPreteen() {
        let child = NutritionCoverage.targets(for: .child)          // 6–8
        XCTAssertEqual(child.fruitCups.lowerBound, 1, accuracy: 0.001)
        XCTAssertEqual(child.fruitCups.upperBound, 1.5, accuracy: 0.001)
        XCTAssertEqual(child.vegetableCups.lowerBound, 1.5, accuracy: 0.001)
        XCTAssertEqual(child.grainOunceEquivalents.lowerBound, 5, accuracy: 0.001)
        XCTAssertEqual(child.proteinOunceEquivalents.lowerBound, 4, accuracy: 0.001)
        XCTAssertEqual(child.dairyCups.lowerBound, 2.5, accuracy: 0.001)

        let preteen = NutritionCoverage.targets(for: .preteen)      // 9–13
        XCTAssertEqual(preteen.fruitCups.lowerBound, 1.5, accuracy: 0.001)
        XCTAssertEqual(preteen.vegetableCups.lowerBound, 2, accuracy: 0.001)
        XCTAssertEqual(preteen.vegetableCups.upperBound, 2.5, accuracy: 0.001)
        XCTAssertEqual(preteen.proteinOunceEquivalents.lowerBound, 5, accuracy: 0.001)
        XCTAssertEqual(preteen.dairyCups.lowerBound, 3, accuracy: 0.001)
    }
}
