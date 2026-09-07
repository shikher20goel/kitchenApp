import Foundation

/// One meal in a planned week, as the engine sees it.
struct PlannedMeal: Hashable, Sendable {
    var date: Date
    var mealType: MealType
    var recipeID: String?
    /// Why this recipe is here — shown as "why this" (SPEC R5).
    var reasons: [String]
    var isLocked: Bool

    init(date: Date, mealType: MealType, recipeID: String?, reasons: [String] = [], isLocked: Bool = false) {
        self.date = Calendar.rasoi.startOfDay(for: date)
        self.mealType = mealType
        self.recipeID = recipeID
        self.reasons = reasons
        self.isLocked = isLocked
    }
}

/// Something the household cooked recently — the planner keeps the week from repeating it.
struct PlannerHistoryEntry: Hashable, Sendable {
    var recipeID: String
    var date: Date
}

/// Everything the planner needs. Plain values only: no SwiftData, no clock of its own.
struct MealPlannerInput: Sendable {
    var weekStart: Date
    /// Already filtered: diet-eligible, not hidden, not resting.
    var recipes: [RecipeSummary]
    var pantry: PantrySnapshot
    /// Household kid score per recipe id, −1…+1.
    var kidScores: [String: Double]
    /// Recipes nobody has reacted to yet.
    var newRecipeIDs: Set<String>
    /// What was cooked in the last three weeks.
    var history: [PlannerHistoryEntry]
    var weekdayMaxCookMinutes: Int
    /// Slots the household pinned; the planner copies them through untouched.
    var lockedSlots: [PlannedMeal]
    /// The day planning happens, for "use it up" decisions.
    var today: Date

    init(
        weekStart: Date,
        recipes: [RecipeSummary],
        pantry: PantrySnapshot = PantrySnapshot(items: []),
        kidScores: [String: Double] = [:],
        newRecipeIDs: Set<String> = [],
        history: [PlannerHistoryEntry] = [],
        weekdayMaxCookMinutes: Int = 35,
        lockedSlots: [PlannedMeal] = [],
        today: Date? = nil
    ) {
        self.weekStart = MealPlan.weekStart(containing: weekStart)
        self.recipes = recipes
        self.pantry = pantry
        self.kidScores = kidScores
        self.newRecipeIDs = newRecipeIDs
        self.history = history
        self.weekdayMaxCookMinutes = weekdayMaxCookMinutes
        self.lockedSlots = lockedSlots
        self.today = today ?? weekStart
    }
}

/// Fills a week of meals (SPEC §5).
///
/// The rules, in the order they are applied:
///  1. Nothing repeats within three days, and the same cuisine does not land on two dinners running.
///  2. A weeknight dinner fits the household's time cap; the weekend is where a long cook goes.
///  3. Recipes the pantry already covers come first, and anything about to expire is used up.
///  4. Recipes the children actually eat rank higher, with at least two sure things a week and at
///     most two brand-new dishes — unless the catalog offers nothing else, in which case a full
///     week beats a strict quota.
///  5. Each day is nudged towards fruit, two vegetable dishes, a protein and a whole grain.
///  6. Breakfasts rotate, and the snack slot leans towards fruit.
///
/// Everything is deterministic: identical input gives an identical plan, and equal candidates are
/// broken by recipe id ascending (SPEC R5).
enum MealPlanner {
    /// How much each factor is worth when ranking candidates.
    /// The order of the numbers mirrors the order of the rules in SPEC §5: using something up
    /// beats cooking from the pantry, which beats the kid score, which beats a nutrition nudge.
    private enum Weight {
        static let kidScore = 1.0
        static let pantryCoverage = 1.2
        static let useItUp = 1.6
        static let nutritionGap = 0.25
        static let weekendLongCook = 0.4
        static let favourite = 0.2
        /// Large enough to act as a rule while still yielding when there is no alternative.
        static let cuisineRepeat = -10.0
        static let repeatedBreakfast = -2.0
    }

    static let sureThingDinnersPerWeek = 2
    static let newRecipesPerWeek = 2
    static let repeatWindowDays = 3
    /// Food groups a day is nudged to cover (SPEC §5 rule 5).
    static let dailyVegetableTarget = 2

    /// A swap option for one slot: the recipe, and why the planner would pick it.
    struct Alternative: Hashable, Sendable {
        var recipeID: String
        var reasons: [String]
    }

    /// Ranked alternatives for one slot. `input.lockedSlots` should carry the rest of the week so
    /// variety and time rules are judged in context; the slot being swapped is simply left out.
    static func alternatives(
        _ input: MealPlannerInput,
        on day: Date,
        mealType: MealType,
        limit: Int = 6
    ) -> [Alternative] {
        let state = PlanState(input: input, days: MealPlan.days(ofWeekContaining: input.weekStart))
        return state.rankedCandidates(day: day, mealType: mealType)
            .prefix(limit)
            .map { Alternative(recipeID: $0.id, reasons: state.explanation(for: $0, day: day, mealType: mealType)) }
    }

    static func plan(_ input: MealPlannerInput) -> [PlannedMeal] {
        let days = MealPlan.days(ofWeekContaining: input.weekStart)
        var state = PlanState(input: input, days: days)

        // Dinners first: they carry the tightest rules, so they get the best of the catalog.
        for day in days { state.fill(day: day, mealType: .dinner) }
        for day in days { state.fill(day: day, mealType: .lunch) }
        for day in days { state.fill(day: day, mealType: .breakfast) }
        for day in days { state.fill(day: day, mealType: .snack) }

        return state.result()
    }

    // MARK: - Planning state

    private struct PlanState {
        let input: MealPlannerInput
        let days: [Date]
        let byID: [String: RecipeSummary]
        var chosen: [Key: PlannedMeal] = [:]

        struct Key: Hashable {
            var date: Date
            var mealType: MealType
        }

        init(input: MealPlannerInput, days: [Date]) {
            self.input = input
            self.days = days
            self.byID = Dictionary(input.recipes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

            for locked in input.lockedSlots {
                chosen[Key(date: locked.date, mealType: locked.mealType)] = PlannedMeal(
                    date: locked.date,
                    mealType: locked.mealType,
                    recipeID: locked.recipeID,
                    reasons: locked.reasons,
                    isLocked: true
                )
            }
        }

        // MARK: Filling one slot

        mutating func fill(day: Date, mealType: MealType) {
            let key = Key(date: Calendar.rasoi.startOfDay(for: day), mealType: mealType)
            if chosen[key] != nil { return } // locked

            let ranked = rankedCandidates(day: key.date, mealType: mealType)
            guard let best = ranked.first else {
                chosen[key] = PlannedMeal(date: key.date, mealType: mealType, recipeID: nil)
                return
            }

            chosen[key] = PlannedMeal(
                date: key.date,
                mealType: mealType,
                recipeID: best.id,
                reasons: reasons(for: best, on: key.date, mealType: mealType)
            )
        }

        /// Every recipe that could fill this slot, best first. Ties break by id ascending so the
        /// order never changes between runs (SPEC R5).
        func rankedCandidates(day: Date, mealType: MealType) -> [RecipeSummary] {
            let key = Key(date: Calendar.rasoi.startOfDay(for: day), mealType: mealType)
            let pool = input.recipes.filter { $0.serves(mealType) }
            guard !pool.isEmpty else { return [] }

            // Constraints are relaxed one at a time, softest first, so a thin catalog still
            // yields a full week rather than an empty slot — and dropping one rule never
            // quietly drops another.
            let tiers: [Constraints] = [
                Constraints(sureThingQuota: true, newRecipeCap: true, timeCap: true, noRepeat: true),
                Constraints(sureThingQuota: false, newRecipeCap: true, timeCap: true, noRepeat: true),
                Constraints(sureThingQuota: false, newRecipeCap: false, timeCap: true, noRepeat: true),
                Constraints(sureThingQuota: false, newRecipeCap: false, timeCap: false, noRepeat: true),
                Constraints(sureThingQuota: false, newRecipeCap: false, timeCap: false, noRepeat: false),
            ]

            var candidates: [RecipeSummary] = []
            for constraints in tiers {
                candidates = pool.filter {
                    allowed($0, on: key.date, mealType: mealType, constraints: constraints)
                }
                if !candidates.isEmpty { break }
            }
            guard !candidates.isEmpty else { return [] }

            var ranked: [(recipe: RecipeSummary, score: Double)] = []
            for candidate in candidates {
                ranked.append((recipe: candidate, score: rank(candidate, on: key.date, mealType: mealType)))
            }
            ranked.sort { left, right in
                if left.score != right.score { return left.score > right.score }
                return left.recipe.id < right.recipe.id     // ties break by id ascending
            }
            return ranked.map(\.recipe)
        }

        /// The reasons a given recipe would carry in this slot.
        func explanation(for recipe: RecipeSummary, day: Date, mealType: MealType) -> [String] {
            reasons(for: recipe, on: Calendar.rasoi.startOfDay(for: day), mealType: mealType)
        }

        // MARK: Constraints

        /// Which rules a candidate has to satisfy at this tier.
        struct Constraints {
            var sureThingQuota: Bool
            var newRecipeCap: Bool
            var timeCap: Bool
            var noRepeat: Bool
        }

        private func allowed(
            _ recipe: RecipeSummary,
            on day: Date,
            mealType: MealType,
            constraints: Constraints
        ) -> Bool {
            if constraints.noRepeat, isRepeat(recipe.id, near: day) { return false }

            if constraints.timeCap, mealType == .dinner, isWeekday(day),
               recipe.totalMinutes > input.weekdayMaxCookMinutes {
                return false
            }

            if constraints.newRecipeCap,
               input.newRecipeIDs.contains(recipe.id),
               newRecipesUsed >= newRecipesPerWeek {
                return false
            }

            if constraints.sureThingQuota, mealType == .dinner,
               mustPickASureThing(on: day), !isSureThing(recipe.id) {
                return false
            }
            return true
        }

        /// True when the remaining dinners are exactly the sure things still owed this week.
        private func mustPickASureThing(on day: Date) -> Bool {
            let owed = sureThingDinnersPerWeek - sureThingDinnersPlanned
            guard owed > 0 else { return false }
            let remaining = days.filter { $0 >= day }
                .filter { chosen[Key(date: $0, mealType: .dinner)] == nil }
                .count
            return remaining <= owed
        }

        private func isRepeat(_ recipeID: String, near day: Date) -> Bool {
            let plannedDates = chosen.values.filter { $0.recipeID == recipeID }.map(\.date)
            let historyDates = input.history.filter { $0.recipeID == recipeID }.map(\.date)
            return (plannedDates + historyDates).contains { other in
                let gap = Calendar.rasoi.dateComponents([.day], from: Calendar.rasoi.startOfDay(for: other),
                                                        to: day).day ?? 0
                return abs(gap) < repeatWindowDays
            }
        }

        // MARK: Ranking

        private func rank(_ recipe: RecipeSummary, on day: Date, mealType: MealType) -> Double {
            var score = (input.kidScores[recipe.id] ?? 0) * Weight.kidScore

            let coverage = input.pantry.coverage(for: recipe)
            score += (coverage >= 0.6 ? 1 : coverage) * Weight.pantryCoverage

            if !input.pantry.expiringIngredients(for: recipe, on: input.today).isEmpty {
                score += Weight.useItUp
            }

            score += nutritionBonus(recipe, on: day, mealType: mealType)

            if mealType == .dinner {
                if let previous = previousDinnerCuisine(before: day), previous == recipe.cuisine {
                    score += Weight.cuisineRepeat
                }
                if !isWeekday(day), recipe.totalMinutes > input.weekdayMaxCookMinutes {
                    score += Weight.weekendLongCook
                }
            }

            if mealType == .breakfast, usedThisWeek(recipe.id, mealType: .breakfast) {
                score += Weight.repeatedBreakfast
            }

            if recipe.isFavorite { score += Weight.favourite }

            return score
        }

        /// Nudges a day towards the food groups it is still missing (SPEC §5 rule 5).
        private func nutritionBonus(_ recipe: RecipeSummary, on day: Date, mealType: MealType) -> Double {
            let tags = Set(recipe.nutritionTags)
            let covered = tagsPlanned(on: day)
            var bonus = 0.0

            if !covered.contains("fruit"), tags.contains("fruit") { bonus += Weight.nutritionGap }
            if vegetableCount(on: day) < dailyVegetableTarget, tags.contains("vegetable") {
                bonus += Weight.nutritionGap
            }
            if !covered.contains("protein"), tags.contains("protein"), mealType == .lunch || mealType == .dinner {
                bonus += Weight.nutritionGap
            }
            if !covered.contains("wholeGrain"), tags.contains("wholeGrain") { bonus += Weight.nutritionGap }
            // The snack slot leans towards fruit (SPEC §5 rule 6).
            if mealType == .snack, tags.contains("fruit") { bonus += Weight.nutritionGap }

            return bonus
        }

        // MARK: Reasons

        private func reasons(for recipe: RecipeSummary, on day: Date, mealType: MealType) -> [String] {
            var reasons: [String] = []

            let expiring = input.pantry.expiringIngredients(for: recipe, on: input.today)
            if let first = expiring.first {
                reasons.append("Uses the \(first.lowercased()) before it turns")
            }

            let coverage = input.pantry.coverage(for: recipe)
            if coverage >= 0.6 {
                reasons.append(coverage >= 0.999 ? "Everything is already in your pantry"
                                                 : "Mostly in your pantry already")
            }

            if let score = input.kidScores[recipe.id] {
                if KidScore.isSureThing(score) {
                    reasons.append("A sure thing at your table")
                } else if score <= -0.4 {
                    reasons.append("Worth another try")
                }
            }

            if input.newRecipeIDs.contains(recipe.id) {
                reasons.append("Something new to try")
            }

            if mealType == .dinner {
                if isWeekday(day), recipe.totalMinutes <= min(input.weekdayMaxCookMinutes, 30) {
                    reasons.append("\(recipe.totalMinutes) minutes on a school night")
                } else if !isWeekday(day), recipe.totalMinutes > input.weekdayMaxCookMinutes {
                    reasons.append("Room for a longer cook at the weekend")
                }
            }

            let covered = tagsPlanned(on: day)
            let tags = Set(recipe.nutritionTags)
            if !covered.contains("fruit"), tags.contains("fruit") { reasons.append("Adds fruit to the day") }
            if !covered.contains("wholeGrain"), tags.contains("wholeGrain") { reasons.append("Adds a whole grain") }
            if !covered.contains("protein"), tags.contains("protein") { reasons.append("Adds a protein") }

            if recipe.isFavorite { reasons.append("One of your favourites") }

            if reasons.isEmpty {
                reasons.append("Keeps the week varied")
            }
            return reasons
        }

        // MARK: Small helpers

        private var newRecipesUsed: Int {
            chosen.values.compactMap(\.recipeID).filter(input.newRecipeIDs.contains).count
        }

        private var sureThingDinnersPlanned: Int {
            chosen.values
                .filter { $0.mealType == .dinner }
                .compactMap(\.recipeID)
                .filter(isSureThing)
                .count
        }

        private func isSureThing(_ recipeID: String) -> Bool {
            KidScore.isSureThing(input.kidScores[recipeID] ?? 0)
        }

        private func usedThisWeek(_ recipeID: String, mealType: MealType) -> Bool {
            chosen.values.contains { $0.mealType == mealType && $0.recipeID == recipeID }
        }

        private func previousDinnerCuisine(before day: Date) -> String? {
            guard let yesterday = Calendar.rasoi.date(byAdding: .day, value: -1, to: day) else { return nil }
            let key = Key(date: Calendar.rasoi.startOfDay(for: yesterday), mealType: .dinner)
            if let planned = chosen[key]?.recipeID, let recipe = byID[planned] {
                return recipe.cuisine
            }
            // The day before the week started may be in history.
            let yesterdayStart = Calendar.rasoi.startOfDay(for: yesterday)
            if let entry = input.history.first(where: { Calendar.rasoi.startOfDay(for: $0.date) == yesterdayStart }),
               let recipe = byID[entry.recipeID] {
                return recipe.cuisine
            }
            return nil
        }

        private func tagsPlanned(on day: Date) -> Set<String> {
            var tags: Set<String> = []
            for mealType in MealType.allCases {
                guard let id = chosen[Key(date: day, mealType: mealType)]?.recipeID,
                      let recipe = byID[id] else { continue }
                tags.formUnion(recipe.nutritionTags)
            }
            return tags
        }

        private func vegetableCount(on day: Date) -> Int {
            MealType.allCases.reduce(0) { count, mealType in
                guard let id = chosen[Key(date: day, mealType: mealType)]?.recipeID,
                      let recipe = byID[id], recipe.nutritionTags.contains("vegetable") else { return count }
                return count + 1
            }
        }

        private func isWeekday(_ day: Date) -> Bool {
            let weekday = Calendar.rasoi.component(.weekday, from: day)
            return weekday >= 2 && weekday <= 6
        }

        func result() -> [PlannedMeal] {
            var meals: [PlannedMeal] = []
            for day in days {
                for mealType in MealType.allCases.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                    let key = Key(date: day, mealType: mealType)
                    meals.append(chosen[key] ?? PlannedMeal(date: day, mealType: mealType, recipeID: nil))
                }
            }
            return meals
        }
    }
}
