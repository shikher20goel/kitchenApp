import SwiftData
import SwiftUI

/// Everyone Rasoi plans for (SPEC §4.5). Ages are shown as a plain number and band — never a
/// weight, a target or anything a child could read as a judgement (R2, R3).
struct FamilyListView: View {
    @State private var model: FamilyViewModel
    @State private var editing: HouseholdMember?
    @State private var isAdding = false

    init(context: ModelContext) {
        _model = State(initialValue: FamilyViewModel(context: context))
    }

    var body: some View {
        List {
            Section {
                if model.activeMembers.isEmpty {
                    ContentUnavailableView(
                        "No one here yet",
                        systemImage: "person.2",
                        description: Text("Add the people you cook for. Ages help Rasoi pick meals everyone can eat.")
                    )
                } else {
                    ForEach(model.activeMembers) { member in
                        Button { editing = member } label: { row(member) }
                            .buttonStyle(.plain)
                    }
                    .onMove { model.move(fromOffsets: $0, toOffset: $1) }
                }
            } header: {
                Text("Family")
            }

            if !model.inactiveMembers.isEmpty {
                Section {
                    ForEach(model.inactiveMembers) { member in
                        Button { editing = member } label: { row(member) }
                            .buttonStyle(.plain)
                    }
                } header: {
                    Text("Not at the table")
                } footer: {
                    Text("Their meal history is kept, so nothing you have logged is lost.")
                }
            }
        }
        .navigationTitle("Family")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { isAdding = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add someone")
            }
            ToolbarItem(placement: .topBarLeading) {
                if model.members.count > 1 { EditButton() }
            }
        }
        .sheet(isPresented: $isAdding) {
            MemberEditView(model: model, member: nil)
        }
        .sheet(item: $editing) { member in
            MemberEditView(model: model, member: member)
        }
        .onAppear { model.load() }
    }

    private func row(_ member: HouseholdMember) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: member.avatarSymbol)
                .font(.title2)
                .foregroundStyle(Color(hex: UInt32(member.colorHex, radix: 16) ?? 0xE8A33D))
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle(member))
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityElement(children: .combine)
    }

    private func subtitle(_ member: HouseholdMember) -> String {
        let years = member.ageYears()
        let band = member.ageBand().label
        let role = member.role.label.lowercased()
        return years >= 19 ? role.capitalized : "\(years) · \(band) \(role)"
    }
}
