import Foundation
import SwiftData

/// What the household's own history says (SPEC §4.5).
///
/// Everything here is descriptive: what went down well, what has not lately, what gets cooked
/// most. No scores are shown as numbers to a child, there are no streaks, and nothing frames a
/// child or a cook as a problem (R2, R3).
@MainActor
@Observable
final class InsightsViewModel {
    struct RecipeInsight: Identifiable, Hashable {
        var id: String
        var title: String
        /// A plain description of what happened, e.g. "ate it all twice".
        var detail: String
    }

    struct ChildInsights: Identifiable, Hashable {
        var id: String
        var name: String
        var favourites: [RecipeInsight]
        var notLately: [RecipeInsight]
    }

    struct CookedInsight: Identifiable, Hashable {
        var id: String
        var title: String
        var times: Int
    }

    private let context: ModelContext
    private let now: () -> Date

    private(set) var children: [ChildInsights] = []
    private(set) var mostCooked: [CookedInsight] = []
    private(set) var cuisineCount = 0
    private(set) var distinctRecipeCount = 0
    private(set) var plannedCount = 0
    private(set) var cookedCount = 0
    /// "This week is light on fruit" — or nil when the week covers everything.
    private(set) var weeklyHint: String?

    /// How far back the insights look.
    static let windowDays = 28
    static let listLength = 5

    init(context: ModelContext, now: @escaping () -> Date = { .now }) {
        self.context = context
        self.now = now
        load()
    }

    var hasAnything: Bool {
        !children.isEmpty || !mostCooked.isEmpty || plannedCount > 0
    }

    func load() {
        let today = now()
        guard let cutoff = Calendar.rasoi.date(byAdding: .day, value: -Self.windowDays, to: today) else { return }

        let slots = ((try? context.fetch(FetchDescriptor<MealSlot>())) ?? [])
            .filter { $0.date >= cutoff && $0.date <= today }
        let cooked = slots.filter { $0.status == .cooked }

        plannedCount = slots.filter { $0.recipe != nil }.count
        cookedCount = cooked.count

        var counts: [String: (title: String, times: Int)] = [:]
        for slot in cooked {
            guard let recipe = slot.recipe else { continue }
            let key = RecipeSummary(recipe: recipe).id
            counts[key] = (title: recipe.title, times: (counts[key]?.times ?? 0) + 1)
        }
        var ranked: [CookedInsight] = []
        for (key, value) in counts {
            ranked.append(CookedInsight(id: key, title: value.title, times: value.times))
        }
        ranked.sort { left, right in
            if left.times != right.times { return left.times > right.times }
            return left.title < right.title
        }
        mostCooked = Array(ranked.prefix(Self.listLength))

        let cookedRecipes = cooked.compactMap(\.recipe)
        cuisineCount = Set(cookedRecipes.map(\.cuisine)).count
        distinctRecipeCount = Set(cookedRecipes.map { RecipeSummary(recipe: $0).id }).count

        children = makeChildInsights(on: today)
        weeklyHint = makeWeeklyHint(on: today)
    }

    // MARK: - Per child

    private func makeChildInsights(on date: Date) -> [ChildInsights] {
        let members = ((try? context.fetch(FetchDescriptor<HouseholdMember>())) ?? [])
            .filter { $0.isActive && $0.isChild }
            .sorted { $0.sortOrder < $1.sortOrder }
        guard !members.isEmpty else { return [] }

        let feedback = ((try? context.fetch(FetchDescriptor<MealFeedback>())) ?? [])
        var byMember: [String: [(recipe: Recipe, reaction: MealReaction, date: Date)]] = [:]
        for entry in feedback {
            guard let member = entry.member, let recipe = entry.slot?.recipe else { continue }
            byMember[member.name, default: []].append((recipe, entry.reaction, entry.createdAt))
        }

        return members.compactMap { member in
            let entries = byMember[member.name] ?? []
            guard !entries.isEmpty else { return nil }

            var summary: [String: (title: String, baseline: Int, ateAll: Int, ateSome: Int, notToday: Int)] = [:]
            for entry in entries {
                let key = RecipeSummary(recipe: entry.recipe).id
                var current = summary[key] ?? (entry.recipe.title, entry.recipe.kidBaseline, 0, 0, 0)
                switch entry.reaction {
                case .ateAll: current.ateAll += 1
                case .ateSome: current.ateSome += 1
                case .notToday: current.notToday += 1
                }
                summary[key] = current
            }

            let scored = summary.map { key, value -> (id: String, title: String, score: Double, value: (title: String, baseline: Int, ateAll: Int, ateSome: Int, notToday: Int)) in
                let score = KidScore.score(
                    recipeID: key,
                    baseline: value.baseline,
                    memberID: member.name,
                    feedback: entries.filter { RecipeSummary(recipe: $0.recipe).id == key }
                        .map { FeedbackEntry(recipeID: key, memberID: member.name, reaction: $0.reaction, date: $0.date) },
                    on: date
                )
                return (key, value.title, score, value)
            }

            // "Goes down well" and "not lately" are decided by what actually happened at the
            // table, not by a blended score — a single refusal of a dish the catalog rates highly
            // still scores positive, and the household would not call that a favourite.
            let favourites = scored
                .filter { $0.value.ateAll + $0.value.ateSome >= $0.value.notToday
                          && $0.value.ateAll + $0.value.ateSome > 0 }
                .sorted { $0.score == $1.score ? $0.title < $1.title : $0.score > $1.score }
                .prefix(Self.listLength)
                .map { RecipeInsight(id: $0.id, title: $0.title, detail: detail(for: $0.value)) }

            let notLately = scored
                .filter { $0.value.notToday > $0.value.ateAll + $0.value.ateSome }
                .sorted { $0.score == $1.score ? $0.title < $1.title : $0.score < $1.score }
                .prefix(Self.listLength)
                .map { RecipeInsight(id: $0.id, title: $0.title, detail: detail(for: $0.value)) }

            return ChildInsights(id: member.name, name: member.name,
                                 favourites: Array(favourites), notLately: Array(notLately))
        }
    }

    /// Plain counting, in the same warm words the feedback sheet uses (R3).
    private func detail(for value: (title: String, baseline: Int, ateAll: Int, ateSome: Int, notToday: Int)) -> String {
        var parts: [String] = []
        if value.ateAll > 0 { parts.append("\(AppCopy.reactionAteAll.lowercased()) \(times(value.ateAll))") }
        if value.ateSome > 0 { parts.append("\(AppCopy.reactionAteSome.lowercased()) \(times(value.ateSome))") }
        if value.notToday > 0 { parts.append("\(AppCopy.reactionNotToday.lowercased()) \(times(value.notToday))") }
        return parts.joined(separator: ", ")
    }

    private func times(_ count: Int) -> String {
        switch count {
        case 1: return "once"
        case 2: return "twice"
        default: return "\(count) times"
        }
    }

    // MARK: - This week's food groups

    private func makeWeeklyHint(on date: Date) -> String? {
        let plan = MealPlan.plan(forWeekContaining: date, in: context)
        let ingredients = (try? context.fetch(FetchDescriptor<Ingredient>())) ?? []
        let index = IngredientIndex(ingredients: ingredients)
        let meals: [(Date, RecipeSummary)] = plan.slots.compactMap { slot in
            guard let recipe = slot.recipe else { return nil }
            return (slot.date, RecipeSummary(recipe: recipe))
        }
        guard !meals.isEmpty else { return nil }
        guard let group = NutritionCoverage.week(meals, index: index).lightestGroup else { return nil }
        return AppCopy.lightOnHint(group.label)
    }
}
