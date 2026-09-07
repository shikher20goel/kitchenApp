import XCTest
@testable import Rasoi

/// The planner is the heart of the app, so each SPEC §5 rule gets its own test over a tiny
/// synthetic catalog, plus a smoke test over the real seeded one.
final class MealPlannerTests: XCTestCase {
    private let monday = D.date(2026, 9, 7)   // a Monday
    private let ira = "ira"

    // MARK: - Catalog helpers

    private func dinner(
        _ id: String,
        cuisine: String = "Indian",
        minutes: Int = 30,
        tags: [String] = ["protein", "vegetable"],
        ingredients: [(String, Double, MeasurementUnit, Bool)] = [("Rice", 200, .gram, false)]
    ) -> RecipeSummary {
        Fixtures.recipe(id: id, cuisine: cuisine, mealTypes: [.dinner],
                        prepMinutes: 10, cookMinutes: minutes - 10,
                        ingredients: ingredients, nutritionTags: tags)
    }

    private func breakfast(_ id: String) -> RecipeSummary {
        Fixtures.recipe(id: id, mealTypes: [.breakfast], prepMinutes: 5, cookMinutes: 5,
                        nutritionTags: ["grain", "calcium"])
    }

    private func lunch(_ id: String, tags: [String] = ["protein", "vegetable"]) -> RecipeSummary {
        Fixtures.recipe(id: id, mealTypes: [.lunch], prepMinutes: 10, cookMinutes: 10, nutritionTags: tags)
    }

    private func snack(_ id: String, tags: [String] = ["fruit"]) -> RecipeSummary {
        Fixtures.recipe(id: id, mealTypes: [.snack], prepMinutes: 5, cookMinutes: 0, nutritionTags: tags)
    }

    /// Enough of every meal that the planner is never forced into a corner.
    private func fullCatalog() -> [RecipeSummary] {
        (1...6).map { breakfast("b\($0)") }
            + (1...6).map { lunch("l\($0)") }
            + (1...6).map { snack("s\($0)") }
            + (1...8).map { dinner("d\($0)", cuisine: $0 % 2 == 0 ? "Indian" : "Italian") }
    }

    private func input(
        recipes: [RecipeSummary],
        pantry: PantrySnapshot = PantrySnapshot(items: []),
        kidScores: [String: Double] = [:],
        newRecipeIDs: Set<String> = [],
        history: [PlannerHistoryEntry] = [],
        weekdayMaxCookMinutes: Int = 35,
        locked: [PlannedMeal] = [],
        today: Date? = nil
    ) -> MealPlannerInput {
        MealPlannerInput(
            weekStart: monday,
            recipes: recipes,
            pantry: pantry,
            kidScores: kidScores,
            newRecipeIDs: newRecipeIDs,
            history: history,
            weekdayMaxCookMinutes: weekdayMaxCookMinutes,
            lockedSlots: locked,
            today: today ?? monday
        )
    }

    private func dinners(_ plan: [PlannedMeal]) -> [PlannedMeal] {
        plan.filter { $0.mealType == .dinner }.sorted { $0.date < $1.date }
    }

    // MARK: - Shape

    func testAWeekIsSevenDaysOfFourMeals() {
        let plan = MealPlanner.plan(input(recipes: fullCatalog()))
        XCTAssertEqual(plan.count, 28)
        XCTAssertEqual(Set(plan.map(\.date)).count, 7)
        XCTAssertEqual(dinners(plan).count, 7)
        XCTAssertTrue(dinners(plan).allSatisfy { $0.recipeID != nil }, "Every dinner is filled.")
    }

    func testEverySlotExplainsItself() {
        let plan = MealPlanner.plan(input(recipes: fullCatalog()))
        for meal in plan where meal.recipeID != nil {
            XCTAssertFalse(meal.reasons.isEmpty, "\(meal.mealType) on \(meal.date) has no reason")
        }
    }

    func testAnEmptyCatalogLeavesEmptySlotsRatherThanCrashing() {
        let plan = MealPlanner.plan(input(recipes: []))
        XCTAssertEqual(plan.count, 28)
        XCTAssertTrue(plan.allSatisfy { $0.recipeID == nil })
    }

    // MARK: - Rule 1: variety

    func testNoRecipeRepeatsWithinThreeDays() {
        let plan = MealPlanner.plan(input(recipes: fullCatalog()))
        let byDate = plan.filter { $0.recipeID != nil }.sorted { $0.date < $1.date }
        for meal in byDate {
            let clashes = byDate.filter {
                $0.recipeID == meal.recipeID
                    && $0.date != meal.date
                    && abs(Calendar.rasoi.dateComponents([.day], from: $0.date, to: meal.date).day ?? 0) < 3
            }
            XCTAssertTrue(clashes.isEmpty, "\(meal.recipeID ?? "") repeats within three days")
        }
    }

    func testRecentHistoryAlsoBlocksARepeat() {
        let catalog = (1...8).map { dinner("d\($0)") } + (1...4).map { breakfast("b\($0)") }
        let yesterday = Calendar.rasoi.date(byAdding: .day, value: -1, to: monday)!
        let plan = MealPlanner.plan(input(
            recipes: catalog,
            history: [PlannerHistoryEntry(recipeID: "d1", date: yesterday)]
        ))
        XCTAssertNotEqual(dinners(plan).first?.recipeID, "d1", "It was on the table yesterday.")
    }

    func testTheSameCuisineIsNotServedTwoDinnersRunning() {
        let catalog = (1...4).map { dinner("i\($0)", cuisine: "Indian") }
            + (1...4).map { dinner("m\($0)", cuisine: "Mexican") }
        let plan = dinners(MealPlanner.plan(input(recipes: catalog)))
        let cuisines = plan.compactMap { meal in catalog.first { $0.id == meal.recipeID }?.cuisine }
        for (index, cuisine) in cuisines.enumerated() where index > 0 {
            XCTAssertNotEqual(cuisine, cuisines[index - 1], "Two \(cuisine) dinners in a row")
        }
    }

    // MARK: - Rule 2: weeknight time cap

    func testWeekdayDinnersFitTheCapAndWeekendsMayNot() {
        let catalog = (1...4).map { dinner("quick\($0)", minutes: 30) }
            + (1...4).map { dinner("slow\($0)", minutes: 90) }
        let plan = dinners(MealPlanner.plan(input(recipes: catalog, weekdayMaxCookMinutes: 35)))

        for meal in plan {
            guard let recipe = catalog.first(where: { $0.id == meal.recipeID }) else { continue }
            let weekday = Calendar.rasoi.component(.weekday, from: meal.date)
            let isWeekday = weekday >= 2 && weekday <= 6
            if isWeekday {
                XCTAssertLessThanOrEqual(recipe.totalMinutes, 35,
                                         "A 90-minute dinner landed on a school night")
            }
        }
    }

    func testASlowDinnerIsStillReachableAtTheWeekend() {
        let catalog = (1...3).map { dinner("quick\($0)", minutes: 30) }
            + [dinner("slow1", minutes: 90), dinner("slow2", minutes: 80)]
        let plan = dinners(MealPlanner.plan(input(recipes: catalog, weekdayMaxCookMinutes: 35)))
        let weekendIDs = plan.filter {
            let weekday = Calendar.rasoi.component(.weekday, from: $0.date)
            return weekday == 7 || weekday == 1
        }.compactMap(\.recipeID)
        XCTAssertTrue(weekendIDs.contains { $0.hasPrefix("slow") },
                      "The weekend is where the long cook belongs.")
    }

    // MARK: - Rule 3: pantry first, then use it up

    func testARecipeAlreadyInThePantryWins() {
        let stocked = dinner("stocked", ingredients: [("Toor dal", 200, .gram, false), ("Tomato", 2, .count, false)])
        let unstocked = dinner("unstocked", cuisine: "Italian",
                               ingredients: [("Paneer", 200, .gram, false), ("Cashews", 40, .gram, false)])
        let pantry = PantrySnapshot(items: [
            PantryStock(name: "Toor dal", quantity: 500, unit: .gram, expiresAt: nil),
            PantryStock(name: "Tomato", quantity: 6, unit: .count, expiresAt: nil),
        ])
        let plan = dinners(MealPlanner.plan(input(recipes: [unstocked, stocked], pantry: pantry)))
        XCTAssertEqual(plan.first?.recipeID, "stocked")
        XCTAssertTrue(plan.first?.reasons.contains { $0.localizedCaseInsensitiveContains("pantry") } == true)
    }

    func testSomethingAboutToExpireIsUsedUpFirst() {
        let usesSpinach = dinner("spinach", ingredients: [("Spinach", 200, .gram, false)])
        let other = dinner("other", cuisine: "Italian", ingredients: [("Rice", 200, .gram, false)])
        let pantry = PantrySnapshot(items: [
            PantryStock(name: "Spinach", quantity: 300, unit: .gram, expiresAt: D.date(2026, 9, 8)),
            PantryStock(name: "Rice", quantity: 2000, unit: .gram, expiresAt: D.date(2027, 1, 1)),
        ])
        let plan = dinners(MealPlanner.plan(input(recipes: [other, usesSpinach], pantry: pantry)))
        XCTAssertEqual(plan.first?.recipeID, "spinach")
        XCTAssertTrue(plan.first?.reasons.contains { $0.localizedCaseInsensitiveContains("spinach") } == true,
                      "The reason names what is being used up.")
    }

    // MARK: - Rule 4: kid scores and quotas

    func testHigherKidScoresAreServedFirst() {
        let catalog = (1...6).map { dinner("d\($0)") }
        let scores = ["d1": -0.8, "d2": -0.5, "d3": 0.2, "d4": 0.9, "d5": 0.7, "d6": 0.0]
        let plan = dinners(MealPlanner.plan(input(recipes: catalog, kidScores: scores)))
        let firstTwo = plan.prefix(2).compactMap(\.recipeID)
        XCTAssertTrue(firstTwo.allSatisfy { ["d4", "d5"].contains($0) },
                      "The meals the children actually eat come first, got \(firstTwo)")
    }

    func testAtLeastTwoSureThingDinnersAWeek() {
        let catalog = (1...8).map { dinner("d\($0)") }
        var scores: [String: Double] = [:]
        for index in 1...8 { scores["d\(index)"] = index <= 2 ? 0.9 : 0.1 }
        let plan = dinners(MealPlanner.plan(input(recipes: catalog, kidScores: scores)))
        let sureThings = plan.compactMap(\.recipeID).filter { KidScore.isSureThing(scores[$0] ?? 0) }
        XCTAssertGreaterThanOrEqual(sureThings.count, 2)
    }

    func testAtMostTwoBrandNewRecipesAWeek() {
        let catalog = (1...10).map { dinner("d\($0)") }
        let newIDs = Set(catalog.map(\.id))
        let plan = dinners(MealPlanner.plan(input(recipes: catalog, newRecipeIDs: newIDs)))
        let planned = plan.compactMap(\.recipeID)
        XCTAssertLessThanOrEqual(planned.filter(newIDs.contains).count, 2,
                                 "A week of nothing but new dishes is a hard sell.")
    }

    func testNewRecipesAreStillTriedWhenThereIsRoom() {
        let known = (1...6).map { dinner("k\($0)") }
        let fresh = [dinner("new1", cuisine: "Mexican"), dinner("new2", cuisine: "Italian")]
        let plan = dinners(MealPlanner.plan(input(
            recipes: known + fresh,
            kidScores: Dictionary(uniqueKeysWithValues: known.map { ($0.id, 0.8) }),
            newRecipeIDs: ["new1", "new2"]
        )))
        let planned = Set(plan.compactMap(\.recipeID))
        XCTAssertTrue(planned.contains("new1") || planned.contains("new2"),
                      "Something new should get a turn.")
    }

    // MARK: - Rule 5: nutrition balance

    func testEachDayGetsFruitVegetablesProteinAndAWholeGrain() {
        let catalog = [
            breakfast("b1"), breakfast("b2"), breakfast("b3"), breakfast("b4"),
            breakfast("b5"), breakfast("b6"), breakfast("b7"),
            lunch("l1"), lunch("l2"), lunch("l3"), lunch("l4"), lunch("l5"), lunch("l6"),
            snack("sf1"), snack("sf2"), snack("sf3"), snack("sf4"), snack("sf5"), snack("sf6"),
        ] + (1...8).map {
            dinner("d\($0)", cuisine: $0 % 2 == 0 ? "Indian" : "Italian",
                   tags: ["protein", "vegetable", "wholeGrain"])
        }
        let plan = MealPlanner.plan(input(recipes: catalog))
        let byRecipe = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })

        for day in MealPlan.days(ofWeekContaining: monday) {
            let meals = plan.filter { $0.date == Calendar.rasoi.startOfDay(for: day) }
            let tags = meals.compactMap { $0.recipeID }.compactMap { byRecipe[$0]?.nutritionTags }.flatMap { $0 }
            XCTAssertTrue(tags.contains("fruit"), "No fruit on \(day)")
            XCTAssertGreaterThanOrEqual(tags.filter { $0 == "vegetable" }.count, 2, "Not enough veg on \(day)")
            XCTAssertTrue(tags.contains("protein"), "No protein on \(day)")
            XCTAssertTrue(tags.contains("wholeGrain"), "No whole grain on \(day)")
        }
    }

    // MARK: - Rule 6: breakfast rotation

    func testAtLeastFourDifferentBreakfasts() {
        let plan = MealPlanner.plan(input(recipes: fullCatalog()))
        let breakfasts = Set(plan.filter { $0.mealType == .breakfast }.compactMap(\.recipeID))
        XCTAssertGreaterThanOrEqual(breakfasts.count, 4)
    }

    func testASmallBreakfastPoolStillFillsTheWeek() {
        let catalog = (1...4).map { breakfast("b\($0)") } + (1...8).map { dinner("d\($0)") }
        let plan = MealPlanner.plan(input(recipes: catalog))
        let breakfasts = plan.filter { $0.mealType == .breakfast }
        XCTAssertEqual(breakfasts.count, 7)
        XCTAssertTrue(breakfasts.allSatisfy { $0.recipeID != nil })
        XCTAssertEqual(Set(breakfasts.compactMap(\.recipeID)).count, 4)
    }

    // MARK: - Locking and regeneration

    func testLockedSlotsAreLeftAlone() {
        let locked = PlannedMeal(
            date: Calendar.rasoi.date(byAdding: .day, value: 2, to: monday)!,
            mealType: .dinner,
            recipeID: "d7",
            reasons: ["You chose this"],
            isLocked: true
        )
        let plan = MealPlanner.plan(input(recipes: fullCatalog(), locked: [locked]))
        let wednesday = plan.first { $0.date == Calendar.rasoi.startOfDay(for: locked.date) && $0.mealType == .dinner }
        XCTAssertEqual(wednesday?.recipeID, "d7")
        XCTAssertEqual(wednesday?.reasons, ["You chose this"])
        XCTAssertTrue(wednesday?.isLocked == true)
    }

    func testALockedRecipeStillBlocksARepeatNearby() {
        let locked = PlannedMeal(
            date: Calendar.rasoi.date(byAdding: .day, value: 2, to: monday)!,
            mealType: .dinner, recipeID: "d7", reasons: ["You chose this"], isLocked: true
        )
        let plan = dinners(MealPlanner.plan(input(recipes: fullCatalog(), locked: [locked])))
        let neighbours = plan.filter { $0.date != Calendar.rasoi.startOfDay(for: locked.date) }
        for meal in neighbours {
            let gap = abs(Calendar.rasoi.dateComponents([.day], from: meal.date, to: locked.date).day ?? 0)
            if gap < 3 {
                XCTAssertNotEqual(meal.recipeID, "d7")
            }
        }
    }

    // MARK: - Determinism (R5)

    func testTheSameInputAlwaysGivesTheSamePlan() {
        let catalog = fullCatalog()
        let scores = Dictionary(uniqueKeysWithValues: catalog.enumerated().map { ($0.element.id, Double($0.offset % 5) / 4) })
        let first = MealPlanner.plan(input(recipes: catalog, kidScores: scores))
        let second = MealPlanner.plan(input(recipes: catalog.reversed(), kidScores: scores))

        XCTAssertEqual(first.map(\.recipeID), second.map(\.recipeID),
                       "Neither catalog order nor a rerun may change the plan.")
        XCTAssertEqual(first.map(\.reasons), second.map(\.reasons))
    }

    func testTiesAreBrokenByRecipeIDAscending() {
        let catalog = [dinner("zeta"), dinner("alpha"), dinner("mid")]
        let plan = dinners(MealPlanner.plan(input(recipes: catalog)))
        XCTAssertEqual(plan.first?.recipeID, "alpha", "Equal candidates are ordered by id.")
    }

    // MARK: - The real catalog

    func testTheSeededCatalogPlansAFullWeek() throws {
        let seed = try SeedLoader.loadRecipes()
        let recipes = seed.recipes.map { dto in
            RecipeSummary(
                id: dto.seedID,
                seedID: dto.seedID,
                title: dto.title,
                cuisine: dto.cuisine,
                mealTypes: Set(dto.mealTypes.compactMap(MealType.init(rawValue:))),
                appliances: Set(dto.appliances.compactMap(Appliance.init(rawValue:))),
                prepMinutes: dto.prepMinutes,
                cookMinutes: dto.cookMinutes,
                servings: dto.servings,
                minAgeYears: dto.minAgeYears,
                ingredients: dto.ingredients.map {
                    RecipeIngredient(ingredientName: $0.ingredientName, quantity: $0.quantity,
                                     unit: MeasurementUnit(rawValue: $0.unit) ?? .gram,
                                     isOptional: $0.isOptional, note: $0.note)
                },
                nutritionTags: dto.nutritionTags,
                containsEgg: dto.containsEgg,
                containsDairy: dto.containsDairy,
                containsNuts: dto.containsNuts,
                containsGluten: dto.containsGluten,
                kidBaseline: dto.kidBaseline,
                isFavorite: false,
                isHidden: false,
                lunchboxOK: dto.lunchboxOK
            )
        }

        let plan = MealPlanner.plan(input(recipes: recipes))
        XCTAssertEqual(plan.count, 28)
        XCTAssertTrue(dinners(plan).allSatisfy { $0.recipeID != nil }, "Every dinner is filled from the real catalog.")
        XCTAssertTrue(plan.filter { $0.mealType == .breakfast }.allSatisfy { $0.recipeID != nil })
        XCTAssertTrue(plan.filter { $0.mealType == .lunch }.allSatisfy { $0.recipeID != nil })

        let filled = plan.filter { $0.recipeID != nil }
        for meal in filled {
            let clashes = filled.filter {
                $0.recipeID == meal.recipeID && $0.date != meal.date
                    && abs(Calendar.rasoi.dateComponents([.day], from: $0.date, to: meal.date).day ?? 0) < 3
            }
            XCTAssertTrue(clashes.isEmpty, "\(meal.recipeID ?? "") repeats within three days")
        }
    }
}
