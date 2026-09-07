import XCTest
@testable import Rasoi

final class KidScoreTests: XCTestCase {
    private let today = D.date(2026, 9, 6)
    private let ira = "ira"
    private let aarav = "aarav"

    private func entry(_ reaction: MealReaction, _ member: String, daysAgo: Int, recipe: String = "dal") -> FeedbackEntry {
        FeedbackEntry(
            recipeID: recipe,
            memberID: member,
            reaction: reaction,
            date: Calendar.rasoi.date(byAdding: .day, value: -daysAgo, to: today) ?? today
        )
    }

    // MARK: - Baseline

    func testWithNoFeedbackTheScoreIsTheBaselineAlone() {
        // baseline 5 → (5 − 3) / 2 = 1, and with n = 0 the blend is entirely baseline.
        XCTAssertEqual(KidScore.score(recipeID: "dal", baseline: 5, memberID: ira, feedback: [], on: today),
                       1.0, accuracy: 0.0001)
        XCTAssertEqual(KidScore.score(recipeID: "dal", baseline: 3, memberID: ira, feedback: [], on: today),
                       0.0, accuracy: 0.0001)
        XCTAssertEqual(KidScore.score(recipeID: "dal", baseline: 1, memberID: ira, feedback: [], on: today),
                       -1.0, accuracy: 0.0001)
    }

    func testOneAteAllMovesTheScoreByTheBlendedAmount() {
        // n = 1: (1/4)·1 + (3/4)·((4−3)/2) = 0.25 + 0.375 = 0.625
        let score = KidScore.score(
            recipeID: "dal", baseline: 4, memberID: ira,
            feedback: [entry(.ateAll, ira, daysAgo: 0)], on: today
        )
        XCTAssertEqual(score, 0.625, accuracy: 0.0001)
    }

    func testOneNotTodayPullsTheScoreDownByTheBlendedAmount() {
        // n = 1: (1/4)·(−1) + (3/4)·((4−3)/2) = −0.25 + 0.375 = 0.125
        let score = KidScore.score(
            recipeID: "dal", baseline: 4, memberID: ira,
            feedback: [entry(.notToday, ira, daysAgo: 0)], on: today
        )
        XCTAssertEqual(score, 0.125, accuracy: 0.0001)
    }

    func testAteSomeCountsAsAPartialYes() {
        let score = KidScore.score(
            recipeID: "dal", baseline: 3, memberID: ira,
            feedback: [entry(.ateSome, ira, daysAgo: 0)], on: today
        )
        XCTAssertEqual(score, 0.25 * 0.4, accuracy: 0.0001)
    }

    func testMoreFeedbackOutweighsTheBaseline() {
        let feedback = (0..<9).map { entry(.ateAll, ira, daysAgo: $0) }
        let score = KidScore.score(recipeID: "dal", baseline: 1, memberID: ira, feedback: feedback, on: today)
        XCTAssertGreaterThan(score, 0.4, "Nine happy meals should outweigh a pessimistic baseline.")
        XCTAssertLessThanOrEqual(score, 1.0)
    }

    // MARK: - Decay

    func testWeightHalvesAtSixtyDays() {
        XCTAssertEqual(KidScore.weight(ageDays: 0), 1, accuracy: 0.0001)
        XCTAssertEqual(KidScore.weight(ageDays: 60), 0.5, accuracy: 0.0001)
        XCTAssertEqual(KidScore.weight(ageDays: 120), 0.25, accuracy: 0.0001)
    }

    func testAnOldRefusalCountsLessThanARecentYes() {
        let score = KidScore.score(
            recipeID: "dal", baseline: 3, memberID: ira,
            feedback: [entry(.notToday, ira, daysAgo: 120), entry(.ateAll, ira, daysAgo: 0)],
            on: today
        )
        XCTAssertGreaterThan(score, 0, "A meal that landed today matters more than one refused four months ago.")
    }

    func testFeedbackForAnotherRecipeOrChildIsIgnored() {
        let feedback = [
            entry(.notToday, aarav, daysAgo: 1),
            entry(.notToday, ira, daysAgo: 1, recipe: "pasta"),
        ]
        XCTAssertEqual(KidScore.score(recipeID: "dal", baseline: 3, memberID: ira, feedback: feedback, on: today),
                       0, accuracy: 0.0001)
    }

    // MARK: - Household

    func testHouseholdScoreIsTheMeanOverChildren() {
        let feedback = [entry(.ateAll, ira, daysAgo: 0), entry(.notToday, aarav, daysAgo: 0)]
        let iraScore = KidScore.score(recipeID: "dal", baseline: 4, memberID: ira, feedback: feedback, on: today)
        let aaravScore = KidScore.score(recipeID: "dal", baseline: 4, memberID: aarav, feedback: feedback, on: today)

        let household = KidScore.householdScore(recipeID: "dal", baseline: 4, childIDs: [ira, aarav],
                                                feedback: feedback, on: today)
        XCTAssertEqual(household, (iraScore + aaravScore) / 2, accuracy: 0.0001)
    }

    func testHouseholdScoreWithNoChildrenFallsBackToTheBaseline() {
        XCTAssertEqual(
            KidScore.householdScore(recipeID: "dal", baseline: 5, childIDs: [], feedback: [], on: today),
            1.0, accuracy: 0.0001
        )
    }

    func testSureThingThreshold() {
        XCTAssertTrue(KidScore.isSureThing(0.6))
        XCTAssertFalse(KidScore.isSureThing(0.59))
    }

    // MARK: - Resting

    func testThreeRefusalsFromEveryChildPutsARecipeToRest() {
        let feedback = [
            entry(.notToday, ira, daysAgo: 3), entry(.notToday, ira, daysAgo: 2), entry(.notToday, ira, daysAgo: 1),
            entry(.notToday, aarav, daysAgo: 3), entry(.notToday, aarav, daysAgo: 2), entry(.notToday, aarav, daysAgo: 1),
        ]
        XCTAssertTrue(KidScore.isResting(recipeID: "dal", childIDs: [ira, aarav], feedback: feedback, on: today))
    }

    func testOneChildStillEatingItKeepsARecipeInRotation() {
        let feedback = [
            entry(.notToday, ira, daysAgo: 3), entry(.notToday, ira, daysAgo: 2), entry(.notToday, ira, daysAgo: 1),
            entry(.notToday, aarav, daysAgo: 3), entry(.ateAll, aarav, daysAgo: 2), entry(.notToday, aarav, daysAgo: 1),
        ]
        XCTAssertFalse(KidScore.isResting(recipeID: "dal", childIDs: [ira, aarav], feedback: feedback, on: today))
    }

    func testTwoRefusalsAreNotEnough() {
        let feedback = [
            entry(.notToday, ira, daysAgo: 2), entry(.notToday, ira, daysAgo: 1),
        ]
        XCTAssertFalse(KidScore.isResting(recipeID: "dal", childIDs: [ira], feedback: feedback, on: today))
    }

    func testRestingExpiresAfterThirtyDays() {
        let feedback = [
            entry(.notToday, ira, daysAgo: 40), entry(.notToday, ira, daysAgo: 35), entry(.notToday, ira, daysAgo: 31),
        ]
        XCTAssertFalse(KidScore.isResting(recipeID: "dal", childIDs: [ira], feedback: feedback, on: today),
                       "After a month, it is worth another try.")

        let recent = [
            entry(.notToday, ira, daysAgo: 40), entry(.notToday, ira, daysAgo: 35), entry(.notToday, ira, daysAgo: 29),
        ]
        XCTAssertTrue(KidScore.isResting(recipeID: "dal", childIDs: [ira], feedback: recent, on: today))
    }

    func testARecipeNobodyHasTriedIsNotResting() {
        XCTAssertFalse(KidScore.isResting(recipeID: "dal", childIDs: [ira, aarav], feedback: [], on: today))
    }

    // MARK: - Bulk

    func testScoresForManyRecipes() {
        let recipes = [
            Fixtures.recipe(id: "dal", kidBaseline: 4),
            Fixtures.recipe(id: "pasta", kidBaseline: 2),
        ]
        let feedback = [entry(.ateAll, ira, daysAgo: 0)]
        let scores = KidScore.scores(for: recipes, childIDs: [ira], feedback: feedback, on: today)

        XCTAssertEqual(scores["dal"] ?? 0, 0.625, accuracy: 0.0001)
        XCTAssertEqual(scores["pasta"] ?? 0, -0.5, accuracy: 0.0001)
    }

    func testScoringIsDeterministic() {
        let feedback = [entry(.ateAll, ira, daysAgo: 3), entry(.ateSome, aarav, daysAgo: 10)]
        let first = KidScore.householdScore(recipeID: "dal", baseline: 4, childIDs: [ira, aarav], feedback: feedback, on: today)
        let second = KidScore.householdScore(recipeID: "dal", baseline: 4, childIDs: [aarav, ira], feedback: feedback.reversed(), on: today)
        XCTAssertEqual(first, second, accuracy: 0.000001, "Order of inputs never changes a score.")
    }
}
