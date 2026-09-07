import SwiftData
import SwiftUI

/// The Today tab (SPEC §4.1): what is for dinner, what else is on today, what needs using up,
/// and three snacks a child can have now.
struct TodayView: View {
    /// Built once by `ContentView` and handed in. Building it here instead would rebuild it
    /// every time the tab bar's body ran, which is far more often than a tab is opened.
    let model: TodayViewModel
    @Environment(\.modelContext) private var context

    /// Cook mode and the feedback that follows it are both full-screen, and a view can only own
    /// ONE presentation of a kind — a second `fullScreenCover` on the same view never opens. So
    /// there is one presentation here, and this says which page it is showing.
    /// Cook mode is the one presentation this screen owns; the feedback that follows is pushed,
    /// so it never has to wait for a cover to finish sliding away.
    enum Presentation: Identifiable, Equatable {
        case cooking(MealSlot)

        var id: String {
            switch self {
            case .cooking(let slot): return "cooking-\(slot.persistentModelID.hashValue)"
            }
        }
    }

    @State private var presentation: Presentation?
    @State private var showsWhy = false

    var body: some View {
        content
            .fullScreenCover(item: $presentation, onDismiss: { model.load() }) { presentation in
                switch presentation {
                case .cooking(let slot):
                    if let recipe = slot.recipe {
                        CookModeView(recipe: recipe, servings: slot.servings) { servings in
                            model.setServings(servings, for: slot)
                            model.markCooked(slot)
                        }
                    }
                }
            }
    }

    private var content: some View {
        List {
            if let headline = model.expiringHeadline {
                Section {
                    Label(headline, systemImage: "clock.arrow.circlepath")
                        .font(.subheadline)
                        .foregroundStyle(Theme.terracotta)
                }
            }

            Section {
                dinnerCard
                    .listRowInsets(EdgeInsets(top: Theme.Spacing.s, leading: Theme.Spacing.l,
                                              bottom: Theme.Spacing.s, trailing: Theme.Spacing.l))
                    .listRowBackground(Color.clear)
            }

            if !model.otherMeals.isEmpty {
                Section("The rest of today") {
                    ForEach(model.otherMeals, id: \.persistentModelID) { slot in
                        mealRow(slot)
                    }
                }
            }

            if !model.snacks.isEmpty {
                Section("Quick snacks") {
                    ForEach(model.snacks) { snack in
                        HStack(spacing: Theme.Spacing.m) {
                            Image(systemName: snack.symbolName)
                                .foregroundStyle(Theme.sage)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(snack.title)
                                Text(snack.detail)
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }

            Section("Food groups today") {
                CoverageDots(coverage: model.coverage)
                    .padding(.vertical, Theme.Spacing.xs)
            }
        }
        .navigationTitle(model.today.formatted(.dateTime.weekday(.wide).day().month(.wide)))
        .navigationBarTitleDisplayMode(.inline)
        .task { model.load() }
    }

    @ViewBuilder
    private var dinnerCard: some View {
        if let dinner = model.dinner, let recipe = dinner.recipe {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                Text("Tonight")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Text(recipe.title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                HStack(spacing: Theme.Spacing.s) {
                    Label(recipe.cuisine, systemImage: "globe")
                    Label("\(recipe.totalMinutes) min", systemImage: "clock")
                    Label("serves \(dinner.servings)", systemImage: "person.2")
                }
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)

                if !dinner.reasons.isEmpty {
                    DisclosureGroup("Why this", isExpanded: $showsWhy) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            ForEach(dinner.reasons, id: \.self) { reason in
                                Label(reason, systemImage: "sparkles")
                                    .font(.footnote)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .padding(.top, Theme.Spacing.xs)
                    }
                    .font(.subheadline)
                    .accessibilityIdentifier("today.why")
                }

                if dinner.status == .cooked {
                    Label("Cooked", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Theme.sage)
                    NavigationLink {
                        FeedbackView(slot: dinner, context: context)
                    } label: {
                        Label("How did it go?", systemImage: "text.bubble")
                            .frame(maxWidth: .infinity, minHeight: Theme.largeTapTarget)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("today.feedback")
                } else {
                    Button {
                        presentation = .cooking(dinner)
                    } label: {
                        Label("Cook", systemImage: "flame")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: Theme.largeTapTarget)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.saffron)
                    .disabled(presentation != nil)
                    .accessibilityIdentifier("today.cook")
                }
            }
            .rasoiCard()
        } else {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("Nothing planned for tonight")
                    .font(.headline)
                Text("Open Plan and generate the week — it takes a second and starts from your pantry.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            .rasoiCard()
        }
    }

    private func mealRow(_ slot: MealSlot) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: slot.mealType.symbolName)
                .foregroundStyle(Theme.saffron)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(slot.mealType.label)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                Text(slot.recipe?.title ?? "Nothing planned")
                    .foregroundStyle(slot.recipe == nil ? Theme.textSecondary : Theme.textPrimary)
            }
            Spacer()
            if slot.status == .cooked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.sage)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Five dots, one per MyPlate group: filled when the day's meals cover it. No numbers, ever (R2).
struct CoverageDots: View {
    let coverage: DayCoverage
    var showsLabels = true

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            ForEach(MyPlateGroup.allCases, id: \.self) { group in
                VStack(spacing: Theme.Spacing.xs) {
                    Circle()
                        .fill(coverage.covers(group) ? Theme.sage : Color.clear)
                        .overlay(Circle().strokeBorder(coverage.covers(group) ? Theme.sage : Theme.separator,
                                                       lineWidth: 1.5))
                        .frame(width: 14, height: 14)
                    if showsLabels {
                        Text(group.label)
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(group.label): \(coverage.covers(group) ? "covered" : "not yet")")
            }
        }
    }
}
