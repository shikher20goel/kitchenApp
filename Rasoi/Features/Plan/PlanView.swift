import SwiftData
import SwiftUI

/// The week (SPEC §4.2): seven day sections, four meals each, with a summary at the top.
/// Vertical days keep every tap in reach of one thumb.
struct PlanView: View {
    @State private var model: PlanViewModel
    @State private var editingSlot: MealSlot?

    init(context: ModelContext) {
        _model = State(initialValue: PlanViewModel(context: context))
    }

    var body: some View {
        List {
            Section {
                WeekSummaryCard(model: model)
                    .listRowInsets(EdgeInsets(top: Theme.Spacing.s, leading: Theme.Spacing.l,
                                              bottom: Theme.Spacing.s, trailing: Theme.Spacing.l))
                    .listRowBackground(Color.clear)

                Button {
                    model.generateWeek()
                    Haptics.success()
                } label: {
                    Label(model.hasPlan ? "Regenerate week" : "Generate week", systemImage: "wand.and.stars")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: Theme.largeTapTarget)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.saffron)
                .accessibilityIdentifier("plan.generate")
                .listRowInsets(EdgeInsets(top: Theme.Spacing.xs, leading: Theme.Spacing.l,
                                          bottom: Theme.Spacing.m, trailing: Theme.Spacing.l))
                .listRowBackground(Color.clear)
            }

            ForEach(model.days, id: \.self) { day in
                Section {
                    ForEach(MealType.allCases.sorted { $0.sortOrder < $1.sortOrder }, id: \.self) { mealType in
                        slotRow(day: day, mealType: mealType)
                    }
                } header: {
                    Text(dayTitle(day))
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
        }
        .sheet(item: $editingSlot) { slot in
            SlotSheet(slot: slot, model: model)
        }
        .onAppear { model.load() }
    }

    private func slotRow(day: Date, mealType: MealType) -> some View {
        let slot = model.slot(on: day, mealType: mealType)
        return Button {
            if let slot { editingSlot = slot }
        } label: {
            HStack(alignment: .top, spacing: Theme.Spacing.m) {
                Image(systemName: mealType.symbolName)
                    .foregroundStyle(Theme.saffron)
                    .frame(width: 24)
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
                }
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("plan.\(shortDay(day)).\(mealType.rawValue)")
    }

    private func dayTitle(_ day: Date) -> String {
        day.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
    }

    private func shortDay(_ day: Date) -> String {
        day.formatted(.dateTime.weekday(.abbreviated)).lowercased()
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
            } else {
                HStack(spacing: Theme.Spacing.l) {
                    stat("\(summary.plannedMeals)", "meals")
                    stat("\(summary.sureThings)", "sure things")
                    stat("\(summary.newRecipes)", "new")
                }
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
