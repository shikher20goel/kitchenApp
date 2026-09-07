import SwiftData
import SwiftUI

/// After cooking: three big buttons per person (SPEC §4.1). No scores, no streaks, nothing a
/// child could read as a mark against them (R3).
///
/// This is a plain screen rather than a sheet: it is pushed from Today, so it works whether or not
/// something else was just presented.
struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: FeedbackViewModel

    init(slot: MealSlot, context: ModelContext, depleter: FeedbackViewModel.Depleting = PantryDepletionService()) {
        _model = State(initialValue: FeedbackViewModel(slot: slot, context: context, depleter: depleter))
    }

    var body: some View {
        Group {
            List {
                Section {
                    Text(AppCopy.feedbackPrompt)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    if let title = model.slot.recipe?.title {
                        Text(title)
                            .font(.headline)
                    }
                }

                ForEach(model.members) { member in
                    Section(member.name) {
                        HStack(spacing: Theme.Spacing.s) {
                            ForEach(MealReaction.allCases, id: \.self) { reaction in
                                reactionButton(reaction, for: member)
                            }
                        }
                        .padding(.vertical, Theme.Spacing.xs)

                        TextField(AppCopy.feedbackNotePlaceholder, text: Binding(
                            get: { model.notes[member.name] ?? "" },
                            set: { model.notes[member.name] = $0 }
                        ), axis: .vertical)
                        .font(.subheadline)
                    }
                }

                Section {
                    Text(AppCopy.feedbackFooter)
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .navigationTitle(AppCopy.feedbackTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.save()
                        Haptics.success()
                        dismiss()
                    }
                    .disabled(!model.canSave)
                    .accessibilityIdentifier("feedback.save")
                }
            }
        }
    }

    private func reactionButton(_ reaction: MealReaction, for member: HouseholdMember) -> some View {
        let isSelected = model.reaction(for: member) == reaction
        return Button {
            model.select(reaction, for: member)
            Haptics.tap()
        } label: {
            VStack(spacing: Theme.Spacing.xs) {
                Image(systemName: reaction.symbolName)
                    .font(.title2)
                Text(reaction.label)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: Theme.largeTapTarget)
            .padding(.vertical, Theme.Spacing.s)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(isSelected ? Theme.sage.opacity(0.25) : Theme.surfaceElevated)
            )
            .foregroundStyle(Theme.textPrimary)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("feedback.\(member.name).\(reaction.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
