import Foundation

/// One recorded reaction, flattened for the engines.
struct FeedbackEntry: Hashable, Sendable {
    /// The recipe's stable id (`RecipeSummary.id`).
    var recipeID: String
    /// The household member's stable id.
    var memberID: String
    var reaction: MealReaction
    var date: Date
}

/// How much a child likes a recipe, computed from what actually happened at the table (SPEC §5).
///
/// Nothing is stored: a score is always derived from `MealFeedback`, so history can never drift
/// out of step with the number, and no child ever has a saved "score" to be judged by (R3).
///
/// The formula, for one child and one recipe:
///
///     weight(entry)  = 0.5 ^ (ageInDays / 60)          — a reaction halves in weight every 60 days
///     feedbackMean   = Σ weight·value / Σ weight        — ateAll +1, ateSome +0.4, notToday −1
///     score          = n/(n+3) · feedbackMean + 3/(n+3) · (kidBaseline − 3) / 2
///
/// `n` is how many times this child has reacted to this recipe, so the editorial baseline carries
/// the score until real experience replaces it. The result is always in −1…+1.
enum KidScore {
    /// A reaction is worth half as much after this many days.
    static let halfLifeDays: Double = 60
    /// How much editorial baseline is worth, measured in reactions.
    static let baselineWeight: Double = 3
    /// A recipe every child has turned down three times running is rested this long.
    static let restingDays = 30
    static let consecutiveRefusalsForRest = 3
    /// At or above this, the planner counts a recipe as a "sure thing" (SPEC §5 rule 4).
    static let sureThingThreshold: Double = 0.6

    /// The weight a reaction of this age still carries.
    static func weight(ageDays: Double) -> Double {
        pow(0.5, max(0, ageDays) / halfLifeDays)
    }

    /// How much one child likes one recipe, in −1…+1.
    static func score(
        recipeID: String,
        baseline: Int,
        memberID: String,
        feedback: [FeedbackEntry],
        on date: Date
    ) -> Double {
        let entries = feedback.filter { $0.recipeID == recipeID && $0.memberID == memberID }
        let baselineTerm = (Double(baseline) - 3) / 2

        var weightSum: Double = 0
        var valueSum: Double = 0
        for entry in entries {
            let weight = weight(ageDays: days(from: entry.date, to: date))
            weightSum += weight
            valueSum += weight * entry.reaction.weight
        }

        let count = Double(entries.count)
        guard count > 0, weightSum > 0 else { return baselineTerm }
        let feedbackMean = valueSum / weightSum
        let experience = count / (count + baselineWeight)
        return experience * feedbackMean + (1 - experience) * baselineTerm
    }

    /// The mean over the children at the table. With no children, the baseline stands alone.
    static func householdScore(
        recipeID: String,
        baseline: Int,
        childIDs: [String],
        feedback: [FeedbackEntry],
        on date: Date
    ) -> Double {
        guard !childIDs.isEmpty else { return (Double(baseline) - 3) / 2 }
        let total = childIDs.reduce(0.0) { sum, childID in
            sum + score(recipeID: recipeID, baseline: baseline, memberID: childID, feedback: feedback, on: date)
        }
        return total / Double(childIDs.count)
    }

    /// Household scores for a whole catalog, keyed by recipe id.
    static func scores(
        for recipes: [RecipeSummary],
        childIDs: [String],
        feedback: [FeedbackEntry],
        on date: Date
    ) -> [String: Double] {
        var result: [String: Double] = [:]
        for recipe in recipes {
            result[recipe.id] = householdScore(
                recipeID: recipe.id,
                baseline: recipe.kidBaseline,
                childIDs: childIDs,
                feedback: feedback,
                on: date
            )
        }
        return result
    }

    static func isSureThing(_ score: Double) -> Bool {
        score >= sureThingThreshold
    }

    /// True while a recipe is resting: every child has turned it down three times running, and
    /// the most recent of those refusals was less than 30 days ago. Pushing a dish nobody wants
    /// helps no one — it comes back on its own after a month.
    static func isResting(
        recipeID: String,
        childIDs: [String],
        feedback: [FeedbackEntry],
        on date: Date
    ) -> Bool {
        guard !childIDs.isEmpty else { return false }
        var lastRefusal: Date?

        for childID in childIDs {
            let entries = feedback
                .filter { $0.recipeID == recipeID && $0.memberID == childID }
                .sorted { $0.date < $1.date }
            guard entries.count >= consecutiveRefusalsForRest else { return false }
            let recent = entries.suffix(consecutiveRefusalsForRest)
            guard recent.allSatisfy({ $0.reaction == .notToday }) else { return false }
            if let last = recent.last?.date, last > (lastRefusal ?? .distantPast) {
                lastRefusal = last
            }
        }

        guard let lastRefusal else { return false }
        return days(from: lastRefusal, to: date) < Double(restingDays)
    }

    private static func days(from: Date, to: Date) -> Double {
        to.timeIntervalSince(from) / 86_400
    }
}
