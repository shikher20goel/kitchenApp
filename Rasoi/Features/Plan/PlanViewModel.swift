import Foundation
import SwiftData

/// The week of meals on screen (SPEC §4.2): builds the planner's input from the store, writes the
/// result back into `MealSlot` rows, and handles the household's edits.
///
/// All the thinking lives in `MealPlanner`; this type only translates between SwiftData and the
/// engine's plain values.
@MainActor
@Observable
final class PlanViewModel {
    private let context: ModelContext
    private let now: () -> Date

    /// The Monday of the week being shown.
    private(set) var weekStart: Date
    private(set) var slots: [MealSlot] = []
    private(set) var recipesByPlannerID: [String: Recipe] = [:]
    /// Recomputed on `load()`. Never computed inside a view body: it reads the whole store, and
    /// SwiftUI evaluates a body far more often than the data changes.
    private(set) var summary = Summary(plannedMeals: 0, sureThings: 0, newRecipes: 0, totalSlots: 0)
    /// Food-group coverage per day, and the week's one gentle hint (SPEC §5, R2).
    private(set) var coverageByDay: [Date: DayCoverage] = [:]
    private(set) var weeklyHint: String?
    private var cachedFeedback: [FeedbackEntry] = []
    private var cachedNewRecipeIDs: Set<String> = []

    init(context: ModelContext, weekContaining date: Date? = nil, now: @escaping () -> Date = { .now }) {
        self.context = context
        self.now = now
        self.weekStart = MealPlan.weekStart(containing: date ?? now())
        load()
    }

    // MARK: - Loading

    func load() {
        let plan = MealPlan.plan(forWeekContaining: weekStart, in: context)
        slots = plan.slots.sorted { left, right in
            left.date == right.date
                ? left.mealType.sortOrder < right.mealType.sortOrder
                : left.date < right.date
        }
        var byID: [String: Recipe] = [:]
        for recipe in (try? context.fetch(FetchDescriptor<Recipe>())) ?? [] {
            byID[RecipeSummary(recipe: recipe).id] = recipe
        }
        recipesByPlannerID = byID
        cachedFeedback = fetchFeedbackEntries()
        cachedNewRecipeIDs = Set(byID.keys).subtracting(Set(cachedFeedback.map(\.recipeID)))
        summary = makeSummary()
        refreshCoverage()
    }

    /// Coverage dots for one day of the week.
    func coverage(on day: Date) -> DayCoverage {
        coverageByDay[Calendar.rasoi.startOfDay(for: day)]
            ?? DayCoverage(date: Calendar.rasoi.startOfDay(for: day), covered: [], hasWholeGrain: false)
    }

    private func refreshCoverage() {
        let ingredients = (try? context.fetch(FetchDescriptor<Ingredient>())) ?? []
        let index = IngredientIndex(ingredients: ingredients)
        var meals: [(Date, RecipeSummary)] = []
        for slot in slots {
            guard let recipe = slot.recipe else { continue }
            meals.append((slot.date, RecipeSummary(recipe: recipe)))
        }
        var byDay: [Date: DayCoverage] = [:]
        for day in MealPlan.days(ofWeekContaining: weekStart) {
            let start = Calendar.rasoi.startOfDay(for: day)
            let recipes = meals.filter { Calendar.rasoi.startOfDay(for: $0.0) == start }.map(\.1)
            byDay[start] = NutritionCoverage.day(recipes, on: start, index: index)
        }
        coverageByDay = byDay
        weeklyHint = meals.isEmpty
            ? nil
            : NutritionCoverage.week(meals, index: index).lightestGroup.map { AppCopy.lightOnHint($0.label) }
    }

    var days: [Date] { MealPlan.days(ofWeekContaining: weekStart) }

    func slots(on day: Date) -> [MealSlot] {
        let start = Calendar.rasoi.startOfDay(for: day)
        return slots.filter { $0.date == start }
    }

    func slot(on day: Date, mealType: MealType) -> MealSlot? {
        slots(on: day).first { $0.mealType == mealType }
    }

    func showWeek(containing date: Date) {
        weekStart = MealPlan.weekStart(containing: date)
        load()
    }

    func showNextWeek() {
        showWeek(containing: Calendar.rasoi.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart)
    }

    func showPreviousWeek() {
        showWeek(containing: Calendar.rasoi.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart)
    }

    var hasPlan: Bool { slots.contains { $0.recipe != nil } }

    // MARK: - Generating

    /// Fills every unlocked slot. Locked slots, and anything already cooked, are left alone.
    func generateWeek() {
        let input = makePlannerInput()
        let planned = MealPlanner.plan(input)
        let plan = MealPlan.plan(forWeekContaining: weekStart, in: context)

        for meal in planned {
            let slot = MealSlot.slot(in: plan, on: meal.date, mealType: meal.mealType, in: context)
            if slot.lockedByUser || slot.status == .cooked { continue }
            slot.recipe = meal.recipeID.flatMap { recipesByPlannerID[$0] }
            slot.reasons = meal.reasons
            slot.servings = defaultServings
            if slot.status != .planned { slot.status = .planned }
        }
        plan.generatedAt = now()
        save()
    }

    /// Same as generating: locked slots survive by definition.
    func regenerateUnlockedSlots() {
        generateWeek()
    }

    // MARK: - Editing one slot

    /// Ranked swap options for a slot, each with the reasons the planner would give.
    func alternatives(for slot: MealSlot, limit: Int = 6) -> [(recipe: Recipe, reasons: [String])] {
        var input = makePlannerInput()
        // Judge alternatives in the context of the rest of the week, minus this slot.
        input.lockedSlots = slots
            .filter { !($0.date == slot.date && $0.mealType == slot.mealType) }
            .compactMap { other in
                guard let recipe = other.recipe else { return nil }
                return PlannedMeal(date: other.date, mealType: other.mealType,
                                   recipeID: RecipeSummary(recipe: recipe).id,
                                   reasons: other.reasons, isLocked: true)
            }

        return MealPlanner.alternatives(input, on: slot.date, mealType: slot.mealType, limit: limit)
            .compactMap { alternative in
                guard let recipe = recipesByPlannerID[alternative.recipeID] else { return nil }
                return (recipe: recipe, reasons: alternative.reasons)
            }
    }

    func swap(_ slot: MealSlot, to recipe: Recipe, reasons: [String] = []) {
        slot.recipe = recipe
        slot.reasons = reasons.isEmpty ? ["You chose this"] : reasons
        if slot.status != .planned { slot.status = .planned }
        save()
    }

    func toggleLock(_ slot: MealSlot) {
        slot.lockedByUser.toggle()
        save()
    }

    func setStatus(_ status: MealSlotStatus, for slot: MealSlot) {
        slot.status = status
        if status == .skipped || status == .eatingOut {
            // The meal is not happening, so nothing should be bought or cooked for it.
            slot.lockedByUser = true
        }
        save()
    }

    func setServings(_ servings: Int, for slot: MealSlot) {
        slot.servings = max(1, servings)
        save()
    }

    func clear(_ slot: MealSlot) {
        slot.recipe = nil
        slot.reasons = []
        slot.status = .planned
        save()
    }

    // MARK: - Week summary

    struct Summary {
        var plannedMeals: Int
        var sureThings: Int
        var newRecipes: Int
        var totalSlots: Int
    }

    private func makeSummary() -> Summary {
        let scores = kidScores()
        let newIDs = cachedNewRecipeIDs
        var sureThings = 0
        var newOnes = 0
        var planned = 0
        for slot in slots {
            guard let recipe = slot.recipe else { continue }
            planned += 1
            let id = RecipeSummary(recipe: recipe).id
            if KidScore.isSureThing(scores[id] ?? 0) { sureThings += 1 }
            if newIDs.contains(id) { newOnes += 1 }
        }
        return Summary(plannedMeals: planned, sureThings: sureThings,
                       newRecipes: newOnes, totalSlots: slots.count)
    }

    // MARK: - Building the engine's input

    func makePlannerInput() -> MealPlannerInput {
        let profile = DietProfile.current(in: context)
        let members = ((try? context.fetch(FetchDescriptor<HouseholdMember>())) ?? []).filter(\.isActive)
        let children = members.filter(\.isChild)
        let today = now()
        let youngest = members.map { $0.ageYears(on: today) }.min() ?? Int.max

        let ingredients = (try? context.fetch(FetchDescriptor<Ingredient>())) ?? []
        let index = IngredientIndex(ingredients: ingredients)
        let rules = DietRules(profile: profile)
        let feedback = feedbackEntries()
        let childIDs = children.map(\.name)

        var eligible: [RecipeSummary] = []
        for recipe in (try? context.fetch(FetchDescriptor<Recipe>())) ?? [] {
            guard !recipe.isHidden else { continue }
            let summary = RecipeSummary(recipe: recipe)
            guard DietFilter.eligible(summary, rules: rules, index: index, youngestAgeYears: youngest) else { continue }
            guard !KidScore.isResting(recipeID: summary.id, childIDs: childIDs, feedback: feedback, on: today) else { continue }
            eligible.append(summary)
        }

        let pantry = PantrySnapshot(pantryItems: (try? context.fetch(FetchDescriptor<PantryItem>())) ?? [])

        return MealPlannerInput(
            weekStart: weekStart,
            recipes: eligible,
            pantry: pantry,
            kidScores: KidScore.scores(for: eligible, childIDs: childIDs, feedback: feedback, on: today),
            newRecipeIDs: newRecipeIDs(),
            history: history(),
            weekdayMaxCookMinutes: profile.weekdayMaxCookMinutes,
            lockedSlots: lockedSlots(),
            today: today
        )
    }

    /// Every reaction ever recorded, flattened for the engines. Cached by `load()`.
    private func feedbackEntries() -> [FeedbackEntry] {
        cachedFeedback
    }

    private func fetchFeedbackEntries() -> [FeedbackEntry] {
        ((try? context.fetch(FetchDescriptor<MealFeedback>())) ?? []).compactMap { entry in
            guard let recipe = entry.slot?.recipe, let member = entry.member else { return nil }
            return FeedbackEntry(
                recipeID: RecipeSummary(recipe: recipe).id,
                memberID: member.name,
                reaction: entry.reaction,
                date: entry.createdAt
            )
        }
    }

    /// Recipes nobody has reacted to yet.
    private func newRecipeIDs() -> Set<String> {
        cachedNewRecipeIDs
    }

    private func kidScores() -> [String: Double] {
        let members = ((try? context.fetch(FetchDescriptor<HouseholdMember>())) ?? []).filter { $0.isActive && $0.isChild }
        let summaries = recipesByPlannerID.values.map(RecipeSummary.init(recipe:))
        return KidScore.scores(for: summaries, childIDs: members.map(\.name),
                               feedback: feedbackEntries(), on: now())
    }

    /// What was on the table in the three weeks before this one.
    private func history() -> [PlannerHistoryEntry] {
        guard let cutoff = Calendar.rasoi.date(byAdding: .day, value: -21, to: weekStart) else { return [] }
        let descriptor = FetchDescriptor<MealSlot>(
            predicate: #Predicate { $0.date >= cutoff && $0.date < weekStart }
        )
        return ((try? context.fetch(descriptor)) ?? []).compactMap { slot in
            guard let recipe = slot.recipe else { return nil }
            return PlannerHistoryEntry(recipeID: RecipeSummary(recipe: recipe).id, date: slot.date)
        }
    }

    private func lockedSlots() -> [PlannedMeal] {
        slots.compactMap { slot in
            guard slot.lockedByUser || slot.status == .cooked else { return nil }
            let id = slot.recipe.map { RecipeSummary(recipe: $0).id }
            return PlannedMeal(date: slot.date, mealType: slot.mealType, recipeID: id,
                               reasons: slot.reasons, isLocked: true)
        }
    }

    private var defaultServings: Int {
        let active = ((try? context.fetch(FetchDescriptor<HouseholdMember>())) ?? []).filter(\.isActive).count
        return max(1, active)
    }

    private func save() {
        try? context.save()
        load()
    }
}
