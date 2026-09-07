import XCTest
@testable import Rasoi

/// The seeded catalog is data, not code: these tests are the contract `seed/*.json` has to keep.
final class SeedLoaderTests: XCTestCase {
    private var ingredients: [IngredientDTO] = []
    private var recipes: [RecipeDTO] = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        ingredients = try SeedLoader.loadIngredients().ingredients
        recipes = try SeedLoader.loadRecipes().recipes
    }

    func testBothFilesDecodeFromTheAppBundle() throws {
        XCTAssertGreaterThanOrEqual(ingredients.count, 180)
        XCTAssertGreaterThanOrEqual(recipes.count, 50)
        XCTAssertEqual(try SeedLoader.loadIngredients().version, try SeedLoader.loadRecipes().version,
                       "Both files move forward together so one seedVersion covers the catalog.")
    }

    func testIngredientVocabularyIsKnown() {
        for ingredient in ingredients {
            XCTAssertNotNil(IngredientCategory(rawValue: ingredient.category),
                            "\(ingredient.name): unknown category \(ingredient.category)")
            XCTAssertNotNil(MeasurementUnit(rawValue: ingredient.defaultUnit),
                            "\(ingredient.name): unknown unit \(ingredient.defaultUnit)")
            XCTAssertNotNil(StoreKind(rawValue: ingredient.defaultStoreKind),
                            "\(ingredient.name): unknown store kind \(ingredient.defaultStoreKind)")
            XCTAssertGreaterThan(ingredient.typicalShelfLifeDays, 0, "\(ingredient.name) needs a shelf life")
        }
    }

    func testIngredientNamesAreUnique() {
        let names = ingredients.map { Ingredient.fold($0.name) }
        XCTAssertEqual(Set(names).count, names.count, "Ingredient names are the join key and must be unique.")
    }

    func testEveryRecipeIngredientResolvesToTheCatalog() {
        let known = Set(ingredients.map { Ingredient.fold($0.name) })
        for recipe in recipes {
            for line in recipe.ingredients {
                XCTAssertTrue(known.contains(Ingredient.fold(line.ingredientName)),
                              "\(recipe.seedID) references unknown ingredient '\(line.ingredientName)'")
            }
        }
    }

    func testCatalogIsVegetarian() {
        // SPEC R4: zero meat, poultry, fish or gelatin anywhere in the seeded catalog.
        let forbidden = ["chicken", "beef", "pork", "fish", "shrimp", "mutton", "lamb", "bacon",
                         "ham", "gelatin", "turkey", "anchovy", "prawn", "crab", "salmon", "tuna"]
        for word in forbidden {
            for ingredient in ingredients {
                XCTAssertFalse(Ingredient.fold(ingredient.name).contains(word),
                               "Ingredient '\(ingredient.name)' contains '\(word)'")
            }
            for recipe in recipes {
                let haystack = ([recipe.title] + recipe.steps + recipe.ingredients.map(\.ingredientName))
                    .map(Ingredient.fold)
                    .joined(separator: " ")
                XCTAssertFalse(haystack.contains(word), "Recipe '\(recipe.title)' mentions '\(word)'")
            }
        }
    }

    func testEggRecipesAreFlaggedAndFew() {
        let eggIngredientNames = Set(
            ingredients.filter { $0.category == IngredientCategory.egg.rawValue || $0.containsEgg }
                .map { Ingredient.fold($0.name) }
        )
        let usingEgg = recipes.filter { recipe in
            recipe.ingredients.contains {
                !$0.isOptional && eggIngredientNames.contains(Ingredient.fold($0.ingredientName))
            }
        }
        for recipe in usingEgg {
            XCTAssertTrue(recipe.containsEgg, "\(recipe.seedID) uses egg but is not flagged containsEgg")
        }
        XCTAssertLessThanOrEqual(recipes.filter(\.containsEgg).count, 5, "SPEC §6 caps egg recipes at 5.")
    }

    func testAllergenFlagsAgreeWithTheIngredientCatalog() {
        let byName = Dictionary(uniqueKeysWithValues: ingredients.map { (Ingredient.fold($0.name), $0) })
        for recipe in recipes {
            // Only required ingredients decide a recipe's allergen flags: an optional swirl of
            // yogurt or a side of naan can simply be left off, and flagging the recipe for it
            // would hide a perfectly good dish from a household that avoids dairy or gluten.
            let used = recipe.ingredients
                .filter { !$0.isOptional }
                .compactMap { byName[Ingredient.fold($0.ingredientName)] }
            if used.contains(where: \.containsDairy) {
                XCTAssertTrue(recipe.containsDairy, "\(recipe.seedID) uses dairy but is not flagged")
            }
            if used.contains(where: \.containsNuts) {
                XCTAssertTrue(recipe.containsNuts, "\(recipe.seedID) uses nuts but is not flagged")
            }
            if used.contains(where: \.containsGluten) {
                XCTAssertTrue(recipe.containsGluten, "\(recipe.seedID) uses gluten but is not flagged")
            }
        }
    }

    func testMealCoverageMatchesTheSpec() {
        func count(_ meal: MealType) -> Int {
            recipes.filter { $0.mealTypes.contains(meal.rawValue) }.count
        }
        XCTAssertGreaterThanOrEqual(count(.breakfast), 10)
        XCTAssertGreaterThanOrEqual(count(.lunch) + count(.dinner), 30)
        XCTAssertGreaterThanOrEqual(count(.snack), 8)
    }

    func testApplianceCoverageMatchesTheSpec() {
        func count(_ appliance: Appliance) -> Int {
            recipes.filter { $0.appliances.contains(appliance.rawValue) }.count
        }
        XCTAssertGreaterThanOrEqual(count(.instantPot), 12)
        XCTAssertGreaterThanOrEqual(count(.vitamix), 5)
        XCTAssertGreaterThanOrEqual(recipes.filter { $0.prepMinutes + $0.cookMinutes <= 15 }.count, 8)
    }

    func testRecipeVocabularyAndShapeAreValid() {
        for recipe in recipes {
            XCTAssertFalse(recipe.title.isEmpty)
            XCTAssertFalse(recipe.mealTypes.isEmpty, "\(recipe.seedID) has no meal type")
            XCTAssertFalse(recipe.steps.isEmpty, "\(recipe.seedID) has no steps")
            XCTAssertFalse(recipe.ingredients.isEmpty, "\(recipe.seedID) has no ingredients")
            XCTAssertGreaterThan(recipe.servings, 0)
            XCTAssertTrue((1...5).contains(recipe.kidBaseline), "\(recipe.seedID) kidBaseline out of range")
            XCTAssertFalse(recipe.kidFriendlyNote.isEmpty, "SPEC §6: every recipe carries a kid note")
            for meal in recipe.mealTypes {
                XCTAssertNotNil(MealType(rawValue: meal), "\(recipe.seedID): unknown meal type \(meal)")
            }
            for appliance in recipe.appliances {
                XCTAssertNotNil(Appliance(rawValue: appliance), "\(recipe.seedID): unknown appliance \(appliance)")
            }
            for line in recipe.ingredients {
                XCTAssertNotNil(MeasurementUnit(rawValue: line.unit), "\(recipe.seedID): unknown unit \(line.unit)")
                XCTAssertGreaterThan(line.quantity, 0, "\(recipe.seedID): \(line.ingredientName) has no quantity")
            }
        }
    }

    func testSeedIDsAreUnique() {
        let ids = recipes.map(\.seedID)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertFalse(ids.contains(where: \.isEmpty))
    }

    func testQuickFlagAgreesWithTheClock() {
        for recipe in recipes {
            XCTAssertEqual(recipe.isQuick, recipe.prepMinutes + recipe.cookMinutes <= 15,
                           "\(recipe.seedID): isQuick disagrees with prep + cook")
        }
    }
}
