import SwiftData
import XCTest
@testable import Rasoi

final class DietProfileTests: XCTestCase {
    @MainActor
    func testDefaultsMatchSpec() throws {
        let stack = try TestContainer.makeStack()
        let profile = DietProfile.current(in: stack.context)

        XCTAssertTrue(profile.isVegetarian, "Vegetarian is a hard filter in v1 (SPEC R4).")
        XCTAssertTrue(profile.eggsOK)
        XCTAssertTrue(profile.dairyOK)
        XCTAssertFalse(profile.nutFree)
        XCTAssertFalse(profile.glutenFree)
        XCTAssertEqual(profile.excludedIngredients, [])
        XCTAssertEqual(profile.preferredCuisines,
                       ["Indian", "Mexican", "Italian", "Chinese-style", "American"])
        XCTAssertEqual(profile.appliances, ["instantPot", "vitamix", "stovetop", "oven"])
        XCTAssertEqual(profile.zipCode, "07302")
        XCTAssertEqual(profile.shoppingWeekday, 1, "Sunday, in Gregorian weekday numbering.")
        XCTAssertEqual(profile.weekdayMaxCookMinutes, 35)
        XCTAssertFalse(profile.hasCompletedOnboarding)
        XCTAssertEqual(profile.seedVersion, 0, "No seed applied yet.")
    }

    @MainActor
    func testCurrentIsIdempotent() throws {
        let stack = try TestContainer.makeStack()
        let first = DietProfile.current(in: stack.context)
        first.zipCode = "07030"
        try stack.context.save()

        let second = DietProfile.current(in: stack.context)
        XCTAssertEqual(second.zipCode, "07030", "The singleton is fetched, not recreated.")
        XCTAssertEqual(try stack.context.fetch(FetchDescriptor<DietProfile>()).count, 1)
    }

    @MainActor
    func testExcludedIngredientsRoundTrip() throws {
        let stack = try TestContainer.makeStack()
        let profile = DietProfile.current(in: stack.context)
        profile.excludedIngredients = ["Bitter gourd", "Mushroom"]
        try stack.context.save()

        let reloaded = try XCTUnwrap(try stack.context.fetch(FetchDescriptor<DietProfile>()).first)
        XCTAssertEqual(reloaded.excludedIngredients, ["Bitter gourd", "Mushroom"])
        XCTAssertTrue(reloaded.excludes(ingredientNamed: "bitter gourd"),
                      "Exclusion matching ignores case.")
        XCTAssertFalse(reloaded.excludes(ingredientNamed: "Paneer"))
    }

    @MainActor
    func testApplianceSetReflectsStoredStrings() throws {
        let stack = try TestContainer.makeStack()
        let profile = DietProfile.current(in: stack.context)
        XCTAssertTrue(profile.applianceSet.contains(.instantPot))
        XCTAssertTrue(profile.applianceSet.contains(.vitamix))
        XCTAssertFalse(profile.applianceSet.contains(.airFryer))

        profile.applianceSet = [.stovetop, .airFryer]
        XCTAssertEqual(profile.appliances, ["stovetop", "airFryer"],
                       "Appliances are stored in the enum's declaration order, not insertion order.")
    }

    func testApplianceVocabularyCoversTheSpecOptions() {
        XCTAssertEqual(Appliance.allCases.map(\.rawValue),
                       ["instantPot", "vitamix", "stovetop", "oven", "airFryer", "microwave", "blenderBasic"])
    }
}
