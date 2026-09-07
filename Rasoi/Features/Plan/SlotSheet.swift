import SwiftData
import SwiftUI

/// One meal, up close: why it is here, what else could be, and the ways to change it.
struct SlotSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var slot: MealSlot
    let model: PlanViewModel

    @State private var alternatives: [(recipe: Recipe, reasons: [String])] = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let recipe = slot.recipe {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(recipe.title)
                                .font(.title3.weight(.semibold))
                            Text("\(recipe.cuisine) · \(recipe.totalMinutes) min")
                                .font(.footnote)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.vertical, Theme.Spacing.xs)
                    } else {
                        Text("Nothing planned")
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                if !slot.reasons.isEmpty {
                    Section("Why this") {
                        ForEach(slot.reasons, id: \.self) { reason in
                            Label(reason, systemImage: "sparkles")
                                .font(.subheadline)
                        }
                    }
                }

                Section("This meal") {
                    Toggle("Keep this one", isOn: Binding(
                        get: { slot.lockedByUser },
                        set: { _ in model.toggleLock(slot) }
                    ))
                    Stepper("Serves \(slot.servings)", value: Binding(
                        get: { slot.servings },
                        set: { model.setServings($0, for: slot) }
                    ), in: 1...20)
                    Picker("Status", selection: Binding(
                        get: { slot.status },
                        set: { model.setStatus($0, for: slot) }
                    )) {
                        ForEach(MealSlotStatus.allCases, id: \.self) { status in
                            Text(status.label).tag(status)
                        }
                    }
                }

                Section("Swap for") {
                    if alternatives.isEmpty {
                        Text("Nothing else fits this slot right now.")
                            .foregroundStyle(Theme.textSecondary)
                    }
                    ForEach(alternatives, id: \.recipe.persistentModelID) { option in
                        Button {
                            model.swap(slot, to: option.recipe, reasons: option.reasons)
                            Haptics.success()
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.recipe.title)
                                    .foregroundStyle(Theme.textPrimary)
                                if let reason = option.reasons.first {
                                    Text(reason)
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                        }
                        .accessibilityIdentifier("slot.alternative")
                    }
                }
            }
            .navigationTitle(slot.mealType.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                alternatives = model.alternatives(for: slot).filter { $0.recipe !== slot.recipe }
            }
        }
    }
}
