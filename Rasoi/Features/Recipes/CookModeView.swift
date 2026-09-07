import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Cooking, one step at a time (SPEC §4.1): big type readable from a metre away, the screen stays
/// awake, and the ingredient list rescales with a stepper for however many are eating.
struct CookModeView: View {
    @Environment(\.dismiss) private var dismiss

    let recipe: Recipe
    /// Called when the household taps Done, with the servings they actually cooked.
    var onFinish: ((Int) -> Void)?

    @State private var step = 0
    @State private var servings: Int

    init(recipe: Recipe, servings: Int? = nil, onFinish: ((Int) -> Void)? = nil) {
        self.recipe = recipe
        self.onFinish = onFinish
        _servings = State(initialValue: servings ?? recipe.servings)
    }

    private var scaledIngredients: [RecipeIngredient] {
        Scaling.scale(recipe.ingredients, from: recipe.servings, to: servings)
    }

    private var pages: Int { recipe.steps.count + 1 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $step) {
                    ingredientsPage.tag(0)
                    ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, text in
                        stepPage(number: index + 1, text: text).tag(index + 1)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                footer
            }
            .background(Theme.background)
            .navigationTitle(recipe.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Haptics.success()
                        onFinish?(servings)
                        dismiss()
                    }
                    .accessibilityIdentifier("cook.done")
                }
            }
        }
        .onAppear { setIdleTimer(disabled: true) }
        .onDisappear { setIdleTimer(disabled: false) }
    }

    private var ingredientsPage: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                Text("What you need")
                    .font(.largeTitle.weight(.semibold))
                Stepper("Serves \(servings)", value: $servings, in: 1...20)
                    .font(.title3)
                    .accessibilityIdentifier("cook.servings")

                ForEach(Array(scaledIngredients.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .firstTextBaseline) {
                        Text(line.ingredientName)
                            .font(.title3)
                        if line.isOptional {
                            Text("optional")
                                .font(.footnote)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        Text(quantityText(line))
                            .font(.title3.monospacedDigit())
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Divider()
                }
            }
            .padding(Theme.Spacing.xl)
        }
        .accessibilityIdentifier("cook.ingredients")
    }

    private func stepPage(number: Int, text: String) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                Text("Step \(number) of \(recipe.steps.count)")
                    .font(.headline)
                    .foregroundStyle(Theme.saffron)
                Text(text)
                    .font(.system(.largeTitle, design: .rounded).weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.xl)
        }
    }

    private var footer: some View {
        HStack {
            Button {
                withAnimation { step = max(0, step - 1) }
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .frame(minWidth: Theme.largeTapTarget, minHeight: Theme.largeTapTarget)
            }
            .disabled(step == 0)

            Spacer()
            Text(step == 0 ? "Ingredients" : "\(step) / \(recipe.steps.count)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
                // Without this the old and new labels cross-fade on top of each other mid-swipe.
                .contentTransition(.identity)
                .animation(nil, value: step)
            Spacer()

            Button {
                withAnimation { step = min(pages - 1, step + 1) }
            } label: {
                Label("Next", systemImage: "chevron.right")
                    .labelStyle(.titleAndIcon)
                    .frame(minWidth: Theme.largeTapTarget, minHeight: Theme.largeTapTarget)
            }
            .disabled(step >= pages - 1)
            .accessibilityIdentifier("cook.next")
        }
        .font(.title3)
        .tint(Theme.saffron)
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.m)
        .background(Theme.surface)
    }

    private func quantityText(_ line: RecipeIngredient) -> String {
        let value = line.quantity
        let text = abs(value - value.rounded()) < 0.01
            ? String(Int(value.rounded()))
            : String(format: "%.2f", value).replacingOccurrences(of: "0$", with: "", options: .regularExpression)
        return line.unit.shortLabel.isEmpty ? "×\(text)" : "\(text) \(line.unit.shortLabel)"
    }

    /// Hands stay busy while cooking, so the screen must not lock mid-step.
    private func setIdleTimer(disabled: Bool) {
        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = disabled
        #endif
    }
}
