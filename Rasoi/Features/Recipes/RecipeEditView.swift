import SwiftData
import SwiftUI

/// Write or edit one of the household's own recipes. Allergen flags are worked out from the
/// ingredients — there is nothing to tick and nothing to get wrong.
struct RecipeEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: RecipeEditorViewModel
    @State private var ingredientQuery = ""
    @State private var showValidation = false

    init(context: ModelContext, recipe: Recipe? = nil) {
        _model = State(initialValue: RecipeEditorViewModel(context: context, recipe: recipe))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipe") {
                    TextField("Name", text: $model.draft.title)
                        .accessibilityIdentifier("recipe.title")
                    Picker("Cuisine", selection: $model.draft.cuisine) {
                        ForEach(model.cuisines, id: \.self) { Text($0).tag($0) }
                    }
                    Stepper("Serves \(model.draft.servings)", value: $model.draft.servings, in: 1...20)
                    Stepper("Prep \(model.draft.prepMinutes) min", value: $model.draft.prepMinutes, in: 0...240, step: 5)
                    Stepper("Cook \(model.draft.cookMinutes) min", value: $model.draft.cookMinutes, in: 0...240, step: 5)
                    Stepper("Suits ages \(model.draft.minAgeYears)+", value: $model.draft.minAgeYears, in: 1...18)
                }

                Section("Meals") {
                    ForEach(MealType.allCases, id: \.self) { meal in
                        Toggle(meal.label, isOn: Binding(
                            get: { model.draft.mealTypes.contains(meal) },
                            set: { isOn in
                                if isOn { model.draft.mealTypes.insert(meal) } else { model.draft.mealTypes.remove(meal) }
                            }
                        ))
                    }
                    Toggle("Good in a lunchbox", isOn: $model.draft.lunchboxOK)
                }

                Section("Equipment") {
                    ForEach(Appliance.allCases, id: \.self) { appliance in
                        Toggle(appliance.label, isOn: Binding(
                            get: { model.draft.appliances.contains(appliance) },
                            set: { isOn in
                                if isOn { model.draft.appliances.insert(appliance) } else { model.draft.appliances.remove(appliance) }
                            }
                        ))
                    }
                }

                ingredientsSection

                Section("Steps") {
                    ForEach(model.draft.steps.indices, id: \.self) { index in
                        TextField("Step \(index + 1)", text: $model.draft.steps[index], axis: .vertical)
                    }
                    .onDelete { model.draft.steps.remove(atOffsets: $0) }
                    .onMove { model.draft.steps.move(fromOffsets: $0, toOffset: $1) }
                    Button("Add a step") { model.draft.steps.append("") }
                        .accessibilityIdentifier("recipe.addStep")
                }

                Section {
                    TextField("How to make it work for a young child", text: $model.draft.kidFriendlyNote, axis: .vertical)
                } header: {
                    Text("Make it kid-friendly")
                } footer: {
                    Text("Milder spice, served on the side, cut small — whatever helps at your table.")
                }

                if showValidation, !model.draft.validationErrors.isEmpty {
                    Section {
                        ForEach(model.draft.validationErrors, id: \.self) { error in
                            Label(error, systemImage: "exclamationmark.circle")
                                .foregroundStyle(Theme.terracotta)
                        }
                    }
                }
            }
            .navigationTitle(model.isEditing ? "Edit recipe" : "New recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if model.save() != nil {
                            Haptics.success()
                            dismiss()
                        } else {
                            showValidation = true
                        }
                    }
                    .accessibilityIdentifier("recipe.save")
                }
            }
        }
    }

    private var ingredientsSection: some View {
        Section("Ingredients") {
            ForEach(model.draft.ingredients.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    TextField("Ingredient", text: $model.draft.ingredients[index].ingredientName)
                    HStack {
                        TextField("Quantity", value: $model.draft.ingredients[index].quantity, format: .number)
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                        Picker("Unit", selection: $model.draft.ingredients[index].unit) {
                            ForEach(MeasurementUnit.allCases, id: \.self) { unit in
                                Text(unit == .count ? "count" : unit.rawValue).tag(unit)
                            }
                        }
                        .labelsHidden()
                        Spacer()
                        Toggle("Optional", isOn: $model.draft.ingredients[index].isOptional)
                            .labelsHidden()
                        Text("optional")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .onDelete { model.draft.ingredients.remove(atOffsets: $0) }

            HStack {
                TextField("Add an ingredient", text: $ingredientQuery)
                    .textInputAutocapitalization(.never)
                Button("Add") { addIngredient(named: ingredientQuery) }
                    .disabled(ingredientQuery.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("recipe.addIngredient")
            }
            ForEach(model.ingredientSuggestions(for: ingredientQuery), id: \.persistentModelID) { suggestion in
                Button(suggestion.name) { addIngredient(named: suggestion.name, unit: suggestion.defaultUnit) }
                    .font(.subheadline)
            }
        }
    }

    private func addIngredient(named name: String, unit: MeasurementUnit = .gram) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        model.draft.ingredients.append(
            RecipeIngredient(ingredientName: trimmed, quantity: unit == .count ? 1 : 100, unit: unit)
        )
        ingredientQuery = ""
        Haptics.tap()
    }
}
