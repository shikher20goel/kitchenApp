import SwiftData
import SwiftUI

/// One recipe: what it needs, what you already have, how to make it, and how to make it work for
/// a young child.
struct RecipeDetailView: View {
    @Bindable var recipe: Recipe
    let model: RecipesViewModel

    @Environment(\.modelContext) private var context
    @State private var isEditing = false
    @State private var isCooking = false

    private var pantryNames: Set<String> { model.pantryCoverage(for: recipe) }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text(recipe.title)
                        .font(.title2.weight(.semibold))
                    // Horizontal scroll rather than a squeezed row: "American" must never
                    // hyphenate into "Ameri-can".
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.s) {
                            chip(recipe.cuisine, symbol: "globe")
                            chip("\(recipe.totalMinutes) min", symbol: "clock")
                            chip("serves \(recipe.servings)", symbol: "person.2")
                        }
                    }
                    ForEach(Array(recipe.applianceSet).sorted { $0.rawValue < $1.rawValue }, id: \.self) { appliance in
                        Label(appliance.label, systemImage: appliance.symbolName)
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    if let reason = model.unavailableReason(for: recipe) {
                        Label(reason, systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(Theme.terracotta)
                    }
                }
                .padding(.vertical, Theme.Spacing.xs)

                Button {
                    isCooking = true
                } label: {
                    Label("Cook this", systemImage: "flame")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: Theme.largeTapTarget)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.saffron)
                .disabled(isCooking)
                .accessibilityIdentifier("recipe.cook")
            }

            Section("Ingredients") {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                        Image(systemName: pantryNames.contains(Ingredient.fold(line.ingredientName))
                              ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(pantryNames.contains(Ingredient.fold(line.ingredientName))
                                             ? Theme.sage : Theme.separator)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(line.ingredientName)
                            if !line.note.isEmpty || line.isOptional {
                                Text([line.isOptional ? "optional" : nil, line.note.isEmpty ? nil : line.note]
                                    .compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        Spacer()
                        Text(quantityText(line))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }

            Section("Steps") {
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                        Text("\(index + 1)")
                            .font(.footnote.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Theme.saffron)
                        Text(step)
                    }
                }
            }

            if !recipe.kidFriendlyNote.isEmpty {
                Section("Make it kid-friendly") {
                    Text(recipe.kidFriendlyNote)
                }
            }

            if !recipe.nutritionTags.isEmpty {
                Section("Food groups") {
                    FlowLayout(spacing: Theme.Spacing.s) {
                        ForEach(recipe.nutritionTags, id: \.self) { tag in
                            Text(NutritionTag.label(for: tag))
                                .font(.caption)
                                .padding(.horizontal, Theme.Spacing.m)
                                .padding(.vertical, Theme.Spacing.xs)
                                .background(Theme.sage.opacity(0.18), in: Capsule())
                        }
                    }
                }
            }
        }
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isEditing, onDismiss: { model.load() }) {
            RecipeEditView(context: context, recipe: recipe)
        }
        .fullScreenCover(isPresented: $isCooking) {
            CookModeView(recipe: recipe)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        model.toggleFavorite(recipe)
                    } label: {
                        Label(recipe.isFavorite ? "Remove favourite" : "Favourite",
                              systemImage: recipe.isFavorite ? "heart.slash" : "heart")
                    }
                    Button {
                        model.toggleHidden(recipe)
                    } label: {
                        Label(recipe.isHidden ? "Show again" : "Hide from suggestions",
                              systemImage: recipe.isHidden ? "eye" : "eye.slash")
                    }
                    if recipe.source == .user {
                        Button {
                            isEditing = true
                        } label: {
                            Label("Edit recipe", systemImage: "pencil")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Recipe options")
            }
        }
    }

    private func chip(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.caption)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.xs)
            .background(Theme.surfaceElevated, in: Capsule())
    }

    private func quantityText(_ line: RecipeIngredient) -> String {
        let value = line.quantity
        let text = abs(value - value.rounded()) < 0.01
            ? String(Int(value.rounded()))
            : String(format: "%.1f", value)
        return line.unit.shortLabel.isEmpty ? "×\(text)" : "\(text) \(line.unit.shortLabel)"
    }
}

/// Friendly names for the tags the catalog uses. Food groups only — never a quantity or a target
/// for a person (SPEC R2).
enum NutritionTag {
    static func label(for tag: String) -> String {
        switch tag {
        case "protein": return "Protein"
        case "iron": return "Iron"
        case "calcium": return "Calcium"
        case "fibre": return "Fibre"
        case "vitaminC": return "Vitamin C"
        case "vitaminA": return "Vitamin A"
        case "wholeGrain": return "Whole grain"
        case "healthyFat": return "Healthy fat"
        case "fruit": return "Fruit"
        case "vegetable": return "Vegetables"
        case "grain": return "Grains"
        default: return tag.capitalized
        }
    }
}
