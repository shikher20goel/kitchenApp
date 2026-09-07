import Foundation

/// The five USDA MyPlate food groups (SPEC §5). Rasoi only ever says whether a group is *present*
/// in a day's meals — never how much of it anyone ate (SPEC R2).
enum MyPlateGroup: String, CaseIterable, Sendable {
    case fruit
    case vegetable
    case grain
    case protein
    case dairy

    var label: String {
        switch self {
        case .fruit: return "Fruit"
        case .vegetable: return "Vegetables"
        case .grain: return "Grains"
        case .protein: return "Protein"
        case .dairy: return "Dairy"
        }
    }

    var symbolName: String {
        switch self {
        case .fruit: return "apple.logo"
        case .vegetable: return "carrot"
        case .grain: return "fork.knife"
        case .protein: return "circle.grid.3x3"
        case .dairy: return "drop"
        }
    }
}

/// Which groups a day's meals covered.
struct DayCoverage: Hashable, Sendable {
    var date: Date
    var covered: Set<MyPlateGroup>
    var hasWholeGrain: Bool

    func covers(_ group: MyPlateGroup) -> Bool { covered.contains(group) }

    /// Groups the day did not touch — the dots that stay hollow.
    var missing: [MyPlateGroup] {
        MyPlateGroup.allCases.filter { !covered.contains($0) }
    }
}

/// A week of coverage, and the one gentle nudge Rasoi is willing to make.
struct WeekCoverage: Sendable {
    var days: [DayCoverage]

    func daysCovering(_ group: MyPlateGroup) -> Int {
        days.filter { $0.covers(group) }.count
    }

    var wholeGrainDays: Int { days.filter(\.hasWholeGrain).count }

    /// The group missing on the most days, or nil when the week covers everything. Ties are broken
    /// by the group's declaration order so the hint never flickers between runs (SPEC R5).
    var lightestGroup: MyPlateGroup? {
        let gaps = MyPlateGroup.allCases.map { (group: $0, missing: days.count - daysCovering($0)) }
        guard let worst = gaps.filter({ $0.missing > 0 }).max(by: { left, right in
            left.missing == right.missing
                ? indexOf(left.group) > indexOf(right.group)
                : left.missing < right.missing
        }) else { return nil }
        return worst.group
    }

    private func indexOf(_ group: MyPlateGroup) -> Int {
        MyPlateGroup.allCases.firstIndex(of: group) ?? MyPlateGroup.allCases.count
    }
}

/// MyPlate daily amounts for an age band (SPEC §5).
///
/// This table exists so the engine has a documented basis, and so a future version can use it.
/// **v1 never shows these numbers to anyone** — the UI gets coverage dots only, because putting a
/// quantity next to a child's name is exactly what R2 forbids.
struct MyPlateTargets: Sendable {
    var fruitCups: ClosedRange<Double>
    var vegetableCups: ClosedRange<Double>
    var grainOunceEquivalents: ClosedRange<Double>
    var proteinOunceEquivalents: ClosedRange<Double>
    var dairyCups: ClosedRange<Double>
}

/// Which food groups a day's meals cover (SPEC §5).
///
/// A group counts when the recipe carries its tag or uses an ingredient from a matching category,
/// so both a well-tagged seeded recipe and a hand-written one with known ingredients are read
/// correctly. Nothing here counts portions.
enum NutritionCoverage {
    /// Recipe/ingredient tags that map onto a MyPlate group.
    private static let tagGroups: [String: MyPlateGroup] = [
        "fruit": .fruit,
        "vegetable": .vegetable,
        "grain": .grain,
        "wholeGrain": .grain,
        "protein": .protein,
    ]

    /// Ingredient categories that map onto a MyPlate group.
    private static let categoryGroups: [IngredientCategory: [MyPlateGroup]] = [
        .fruit: [.fruit],
        .vegetable: [.vegetable],
        .leafyGreen: [.vegetable],
        .grain: [.grain],
        .flourBread: [.grain],
        .legume: [.protein],
        .egg: [.protein],
        .nutSeed: [.protein],
        .dairy: [.dairy],
    ]

    static let wholeGrainTag = "wholeGrain"

    /// The groups one recipe contributes.
    static func groups(for recipe: RecipeSummary, index: IngredientIndex) -> Set<MyPlateGroup> {
        var groups: Set<MyPlateGroup> = []
        for tag in recipe.nutritionTags {
            if let group = tagGroups[tag] { groups.insert(group) }
        }
        for line in recipe.ingredients {
            guard let facts = index.facts(for: line.ingredientName) else { continue }
            for group in categoryGroups[facts.category] ?? [] { groups.insert(group) }
            for tag in facts.nutritionTags {
                if let group = tagGroups[tag] { groups.insert(group) }
            }
        }
        return groups
    }

    /// Whether a recipe brings a whole grain to the day.
    static func includesWholeGrain(_ recipe: RecipeSummary, index: IngredientIndex) -> Bool {
        if recipe.nutritionTags.contains(wholeGrainTag) { return true }
        return recipe.ingredients.contains { line in
            index.facts(for: line.ingredientName)?.nutritionTags.contains(wholeGrainTag) == true
        }
    }

    /// Coverage for one day's meals.
    static func day(_ recipes: [RecipeSummary], on date: Date, index: IngredientIndex) -> DayCoverage {
        var covered: Set<MyPlateGroup> = []
        var wholeGrain = false
        for recipe in recipes {
            covered.formUnion(groups(for: recipe, index: index))
            wholeGrain = wholeGrain || includesWholeGrain(recipe, index: index)
        }
        return DayCoverage(date: Calendar.rasoi.startOfDay(for: date), covered: covered, hasWholeGrain: wholeGrain)
    }

    /// Coverage for a week of (day, recipe) pairs, in date order.
    static func week(_ meals: [(Date, RecipeSummary)], index: IngredientIndex) -> WeekCoverage {
        var byDay: [Date: [RecipeSummary]] = [:]
        for (date, recipe) in meals {
            byDay[Calendar.rasoi.startOfDay(for: date), default: []].append(recipe)
        }
        let days = byDay.keys.sorted().map { day in
            NutritionCoverage.day(byDay[day] ?? [], on: day, index: index)
        }
        return WeekCoverage(days: days)
    }

    /// The MyPlate daily amounts behind the dots. Never rendered in v1 (R2).
    static func targets(for band: AgeBand) -> MyPlateTargets {
        switch band {
        case .preschool:
            return MyPlateTargets(fruitCups: 1...1.5, vegetableCups: 1...1.5,
                                  grainOunceEquivalents: 3...5, proteinOunceEquivalents: 2...4,
                                  dairyCups: 2...2.5)
        case .child:
            return MyPlateTargets(fruitCups: 1...1.5, vegetableCups: 1.5...2,
                                  grainOunceEquivalents: 5...6, proteinOunceEquivalents: 4...5,
                                  dairyCups: 2.5...2.5)
        case .preteen:
            return MyPlateTargets(fruitCups: 1.5...2, vegetableCups: 2...2.5,
                                  grainOunceEquivalents: 5...6, proteinOunceEquivalents: 5...5.5,
                                  dairyCups: 3...3)
        case .teen:
            return MyPlateTargets(fruitCups: 1.5...2, vegetableCups: 2.5...3,
                                  grainOunceEquivalents: 6...8, proteinOunceEquivalents: 5...6.5,
                                  dairyCups: 3...3)
        case .adult:
            return MyPlateTargets(fruitCups: 1.5...2, vegetableCups: 2.5...3,
                                  grainOunceEquivalents: 6...8, proteinOunceEquivalents: 5...6.5,
                                  dairyCups: 3...3)
        }
    }
}
