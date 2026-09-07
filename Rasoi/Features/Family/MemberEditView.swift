import SwiftData
import SwiftUI

/// Add or edit one person. Likes and dislikes are free text the household types — Rasoi never
/// classifies anyone or anything on its own.
struct MemberEditView: View {
    @Environment(\.dismiss) private var dismiss

    let model: FamilyViewModel
    let member: HouseholdMember?

    @State private var name: String
    @State private var dateOfBirth: Date
    @State private var role: MemberRole
    @State private var likes: [String]
    @State private var dislikes: [String]
    @State private var avatarSymbol: String
    @State private var colorHex: String
    @State private var isActive: Bool
    @State private var showRemoveConfirmation = false
    @State private var removalNote: String?

    init(model: FamilyViewModel, member: HouseholdMember?) {
        self.model = model
        self.member = member
        _name = State(initialValue: member?.name ?? "")
        _dateOfBirth = State(initialValue: member?.dateOfBirth ?? Calendar.rasoi.date(byAdding: .year, value: -30, to: .now) ?? .now)
        _role = State(initialValue: member?.role ?? .child)
        _likes = State(initialValue: member?.likes ?? [])
        _dislikes = State(initialValue: member?.dislikes ?? [])
        _avatarSymbol = State(initialValue: member?.avatarSymbol ?? "figure.child.circle")
        _colorHex = State(initialValue: member?.colorHex ?? FamilyViewModel.avatarColors[0])
        _isActive = State(initialValue: member?.isActive ?? true)
    }

    private var isNew: Bool { member == nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textContentType(.givenName)
                    DatePicker("Date of birth", selection: $dateOfBirth,
                               in: ...Date.now, displayedComponents: .date)
                    Picker("Role", selection: $role) {
                        ForEach(MemberRole.allCases, id: \.self) { role in
                            Text(role.label).tag(role)
                        }
                    }
                } footer: {
                    Text("Age decides which meals suit everyone at the table. It is never shown as a target or a number to hit.")
                }

                Section("Avatar") {
                    avatarPicker
                    colorPicker
                }

                Section("Likes") {
                    ChipField(title: "Likes", placeholder: "dosa, paneer…", values: $likes)
                }

                Section {
                    ChipField(title: "Dislikes", placeholder: "bitter gourd…", values: $dislikes)
                } header: {
                    Text("Dislikes")
                } footer: {
                    Text("Rasoi keeps these in mind when it suggests meals. Nothing is ever labelled a failure.")
                }

                if let member {
                    Section {
                        Toggle("At the table", isOn: $isActive)
                        Button("Remove from family", role: .destructive) {
                            showRemoveConfirmation = true
                        }
                    } footer: {
                        if let removalNote {
                            Text(removalNote)
                        } else {
                            Text("Someone with meal history is set aside rather than deleted, so the planner keeps what it learned.")
                        }
                    }
                    .onAppear { isActive = member.isActive }
                }
            }
            .navigationTitle(isNew ? "Add someone" : name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Remove \(name)?", isPresented: $showRemoveConfirmation, titleVisibility: .visible) {
                Button("Remove", role: .destructive) { remove() }
                Button("Keep", role: .cancel) {}
            } message: {
                Text("Meals you have already logged for them are kept either way.")
            }
        }
    }

    private var avatarPicker: some View {
        FlowLayout(spacing: Theme.Spacing.s) {
            ForEach(FamilyViewModel.avatarSymbols, id: \.self) { symbol in
                Button { avatarSymbol = symbol } label: {
                    Image(systemName: symbol)
                        .font(.title2)
                        .frame(width: Theme.minimumTapTarget, height: Theme.minimumTapTarget)
                        .background(
                            Circle().fill(avatarSymbol == symbol ? Theme.saffron.opacity(0.2) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(symbol)
                .accessibilityAddTraits(avatarSymbol == symbol ? .isSelected : [])
            }
        }
    }

    private var colorPicker: some View {
        FlowLayout(spacing: Theme.Spacing.s) {
            ForEach(FamilyViewModel.avatarColors, id: \.self) { hex in
                Button { colorHex = hex } label: {
                    Circle()
                        .fill(Color(hex: UInt32(hex, radix: 16) ?? 0xE8A33D))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle().strokeBorder(Theme.textPrimary.opacity(colorHex == hex ? 0.6 : 0), lineWidth: 2)
                        )
                        .frame(width: Theme.minimumTapTarget, height: Theme.minimumTapTarget)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Colour \(hex)")
                .accessibilityAddTraits(colorHex == hex ? .isSelected : [])
            }
        }
    }

    private func save() {
        if let member {
            model.update(member, name: name, dateOfBirth: dateOfBirth, role: role,
                         likes: likes, dislikes: dislikes,
                         avatarSymbol: avatarSymbol, colorHex: colorHex)
            model.setActive(isActive, for: member)
        } else {
            model.addMember(name: name, dateOfBirth: dateOfBirth, role: role,
                            likes: likes, dislikes: dislikes,
                            avatarSymbol: avatarSymbol, colorHex: colorHex)
        }
        Haptics.success()
        dismiss()
    }

    private func remove() {
        guard let member else { return }
        switch model.remove(member) {
        case .deleted:
            dismiss()
        case .deactivated:
            isActive = false
            removalNote = "\(member.name) has meal history, so they were set aside instead of deleted."
        }
    }
}
