import SwiftData
import SwiftUI

/// Browse the catalog (SPEC §4.5). The default list is what this household can cook today.
struct RecipeListView: View {
    @Environment(\.modelContext) private var context
    @State private var model: RecipesViewModel
    @State private var isAddingRecipe = false
    @State private var editingRecipe: Recipe?

    init(context: ModelContext) {
        _model = State(initialValue: RecipesViewModel(context: context))
    }

    var body: some View {
        List {
            Section {
                filterRow
                    .listRowInsets(EdgeInsets(top: Theme.Spacing.s, leading: Theme.Spacing.l,
                                              bottom: Theme.Spacing.s, trailing: Theme.Spacing.l))
            }

            if model.results.isEmpty {
                ContentUnavailableView(
                    "Nothing matches",
                    systemImage: "magnifyingglass",
                    description: Text("Try fewer filters, or turn on “Show everything” to see recipes that are out for now.")
                )
            } else {
                ForEach(model.results, id: \.persistentModelID) { recipe in
                    NavigationLink {
                        RecipeDetailView(recipe: recipe, model: model)
                    } label: {
                        row(recipe)
                    }
                }
            }
        }
        .searchable(text: $model.searchText, prompt: "Search recipes and ingredients")
        .navigationTitle("Recipes")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { isAddingRecipe = true } label: { Image(systemName: "plus") }
                    .accessibilityIdentifier("recipes.add")
                    .accessibilityLabel("New recipe")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Toggle("Quick (≤15 min)", isOn: $model.quickOnly)
                    Toggle("Favourites", isOn: $model.favouritesOnly)
                    Toggle("Lunchbox friendly", isOn: $model.lunchboxOnly)
                    Toggle("Show everything", isOn: $model.showsEverything)
                    Picker("Meal", selection: $model.mealType) {
                        Text("Any meal").tag(MealType?.none)
                        ForEach(MealType.allCases, id: \.self) { Text($0.label).tag(MealType?.some($0)) }
                    }
                    Picker("Cuisine", selection: $model.cuisine) {
                        Text("Any cuisine").tag(String?.none)
                        ForEach(model.cuisines, id: \.self) { Text($0).tag(String?.some($0)) }
                    }
                    Picker("Appliance", selection: $model.appliance) {
                        Text("Any appliance").tag(Appliance?.none)
                        ForEach(Appliance.allCases, id: \.self) { Text($0.label).tag(Appliance?.some($0)) }
                    }
                    if model.hasActiveFilters {
                        Button("Clear filters") { model.clearFilters() }
                    }
                } label: {
                    Image(systemName: model.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel("Filter recipes")
            }
        }
        .sheet(isPresented: $isAddingRecipe, onDismiss: { model.load() }) {
            RecipeEditView(context: context)
        }
        .task { model.load() }
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.s) {
                pill("Quick", isOn: model.quickOnly) { model.quickOnly.toggle() }
                pill("Favourites", isOn: model.favouritesOnly) { model.favouritesOnly.toggle() }
                ForEach(MealType.allCases, id: \.self) { meal in
                    pill(meal.label, isOn: model.mealType == meal) {
                        model.mealType = model.mealType == meal ? nil : meal
                    }
                }
            }
        }
    }

    private func pill(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.selection()
        } label: {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, Theme.Spacing.s)
                .background(isOn ? Theme.saffron.opacity(0.25) : Theme.surfaceElevated, in: Capsule())
                .foregroundStyle(Theme.textPrimary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func row(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text(recipe.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                if recipe.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.terracotta)
                }
            }
            HStack(spacing: Theme.Spacing.s) {
                Text(recipe.cuisine)
                Text("· \(recipe.totalMinutes) min")
                if recipe.isQuick { Text("· quick") }
            }
            .font(.footnote)
            .foregroundStyle(Theme.textSecondary)

            if let reason = model.unavailableReason(for: recipe) {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(Theme.terracotta)
            }
        }
        .padding(.vertical, 2)
    }
}
