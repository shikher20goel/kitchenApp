import SwiftData
import SwiftUI

/// What the household's own history says (SPEC §4.5). Descriptive, never a scoreboard (R3).
struct InsightsView: View {
    @State private var model: InsightsViewModel

    init(context: ModelContext) {
        _model = State(initialValue: InsightsViewModel(context: context))
    }

    var body: some View {
        List {
            Section {
                Text(AppCopy.insightsIntro)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }

            if !model.hasAnything {
                ContentUnavailableView(
                    "Nothing yet",
                    systemImage: "chart.bar",
                    description: Text(AppCopy.insightsEmpty)
                )
            }

            if let hint = model.weeklyHint {
                Section {
                    Label(hint, systemImage: "leaf")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                }
            }

            ForEach(model.children) { child in
                Section(child.name) {
                    if !child.favourites.isEmpty {
                        Text(AppCopy.insightsFavouritesTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                        ForEach(child.favourites) { insight in
                            row(insight, symbol: "hand.thumbsup")
                        }
                    }
                    if !child.notLately.isEmpty {
                        Text(AppCopy.insightsNotLatelyTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                        ForEach(child.notLately) { insight in
                            row(insight, symbol: "arrow.uturn.left")
                        }
                    }
                }
            }

            if !model.mostCooked.isEmpty {
                Section(AppCopy.insightsMostCookedTitle) {
                    ForEach(model.mostCooked) { insight in
                        HStack {
                            Text(insight.title)
                            Spacer()
                            Text(insight.times == 1 ? "once" : "\(insight.times) times")
                                .font(.footnote)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }

            if model.plannedCount > 0 {
                Section(AppCopy.insightsVarietyTitle) {
                    Text(AppCopy.varietyLine(cuisines: model.cuisineCount, recipes: model.distinctRecipeCount))
                    Text(AppCopy.cookedLine(planned: model.plannedCount, cooked: model.cookedCount))
                }
            }

            Section {
                Text(AppCopy.notNutritionAdviceNote)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .navigationTitle("Insights")
        .task { model.load() }
    }

    private func row(_ insight: InsightsViewModel.RecipeInsight, symbol: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.sage)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                Text(insight.detail)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
