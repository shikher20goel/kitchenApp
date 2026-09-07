import SwiftData
import SwiftUI

/// The week (SPEC §4.2): seven day sections, four meals each, with a summary at the top.
/// Vertical days keep every tap in reach of one thumb.
struct PlanView: View {
    /// Built once by `ContentView` and handed in. Building it here instead would rebuild it
    /// every time the tab bar's body ran, which is far more often than a tab is opened.
    let model: PlanViewModel
    @State private var editingSlot: MealSlot?

    var body: some View {
        content(model)
        .sheet(item: $editingSlot) { slot in
            SlotSheet(slot: slot, model: model)
        }
    }

    @ViewBuilder
    private func content(_ model: PlanViewModel) -> some View {
        List {
            Section {
                WeekSummaryCard(model: model)
                    .listRowInsets(EdgeInsets(top: Theme.Spacing.s, leading: Theme.Spacing.l,
                                              bottom: Theme.Spacing.s, trailing: Theme.Spacing.l))
                    .listRowBackground(Color.clear)

            }

            ForEach(Array(model.days.enumerated()), id: \.element) { index, day in
                Section {
                    ForEach(MealType.allCases.sorted { $0.sortOrder < $1.sortOrder }, id: \.self) { mealType in
                        slotRow(model: model, day: day, mealType: mealType, dayIndex: index)
                    }
                } header: {
                    HStack {
                        Text(dayTitle(day))
                        Spacer()
                        CoverageDots(coverage: model.coverage(on: day), showsLabels: false)
                    }
                }
            }
        }
        .navigationTitle("Plan")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    model.showPreviousWeek()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Previous week")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    model.showNextWeek()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .accessibilityLabel("Next week")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    model.generateWeek()
                    Haptics.success()
                } label: {
                    Label(model.hasPlan ? "Regenerate week" : "Generate week", systemImage: "wand.and.stars")
                }
                .accessibilityIdentifier("plan.generate")
                .accessibilityLabel(model.hasPlan ? "Regenerate week" : "Generate week")
            }
        }
        .task { model.load() }
    }

    private func slotRow(model: PlanViewModel, day: Date, mealType: MealType, dayIndex: Int) -> some View {
        let slot = model.slot(on: day, mealType: mealType)
        // Reading the open slot here both tints the row and, just as importantly, makes the body
        // depend on it — a presentation driven by state nothing in the body reads does not stick.
        let isOpen = slot != nil && slot === editingSlot
        return Button {
            editingSlot = slot
        } label: {
            HStack(alignment: .top, spacing: Theme.Spacing.m) {
                Image(systemName: mealType.symbolName)
                    .foregroundStyle(Theme.saffron)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mealType.label)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Text(slot?.recipe?.title ?? "Nothing planned")
                        .font(.body)
                        .foregroundStyle(slot?.recipe == nil ? Theme.textSecondary : Theme.textPrimary)
                    if let slot, slot.status != .planned {
                        Text(slot.status.label)
                            .font(.caption)
                            .foregroundStyle(Theme.terracotta)
                    } else if let reason = slot?.reasons.first {
                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
                if slot?.lockedByUser == true {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .accessibilityLabel("Kept")
                }
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .listRowBackground(isOpen ? Theme.saffron.opacity(0.10) : nil)
        .accessibilityIdentifier("plan.slot.\(dayIndex).\(mealType.rawValue)")
    }

    private func dayTitle(_ day: Date) -> String {
        day.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
    }

}

/// What kind of week this is: how much is planned, how many are sure things, how many are new.
struct WeekSummaryCard: View {
    let model: PlanViewModel

    var body: some View {
        let summary = model.summary
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(weekLabel)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            if summary.plannedMeals == 0 {
                Text("Nothing planned yet. Generate a week and Rasoi will start from your pantry and what the children eat.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                Button {
                    model.generateWeek()
                    Haptics.success()
                } label: {
                    Label("Generate this week", systemImage: "wand.and.stars")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: Theme.largeTapTarget)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.saffron)
                .accessibilityIdentifier("plan.generate.empty")
            } else {
                HStack(spacing: Theme.Spacing.l) {
                    stat("\(summary.plannedMeals)", "meals")
                    stat("\(summary.sureThings)", "sure things")
                    stat("\(summary.newRecipes)", "new")
                }
                if let hint = model.weeklyHint {
                    Label(hint, systemImage: "leaf")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
                Text(AppCopy.coverageDotsExplanation)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .rasoiCard()
    }

    private var weekLabel: String {
        let end = Calendar.rasoi.date(byAdding: .day, value: 6, to: model.weekStart) ?? model.weekStart
        return "\(model.weekStart.formatted(.dateTime.day().month(.abbreviated))) – \(end.formatted(.dateTime.day().month(.abbreviated)))"
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.saffron)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }
}
