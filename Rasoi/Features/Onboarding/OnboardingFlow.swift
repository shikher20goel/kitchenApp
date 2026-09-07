import SwiftData
import SwiftUI

/// First launch, under two minutes (SPEC §4.6): who eats here, what you eat, what you cook with,
/// where you shop. Every page except the first can be skipped.
struct OnboardingFlow: View {
    @Environment(\.modelContext) private var environmentContext

    @State private var family: FamilyViewModel
    @State private var diet: DietSettingsViewModel
    @State private var page = 0
    @State private var name = ""
    @State private var role: MemberRole = .adult
    @State private var dateOfBirth = Calendar.rasoi.date(byAdding: .year, value: -35, to: .now) ?? .now
    @State private var zipDraft: String
    @Query(sort: \Store.sortOrder) private var stores: [Store]

    private static let pageCount = 4

    init(context: ModelContext) {
        _family = State(initialValue: FamilyViewModel(context: context))
        let diet = DietSettingsViewModel(context: context)
        _diet = State(initialValue: diet)
        _zipDraft = State(initialValue: diet.profile.zipCode)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            TabView(selection: $page) {
                familyPage.tag(0)
                dietPage.tag(1)
                kitchenPage.tag(2)
                storesPage.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            footer
        }
        .background(Theme.background)
    }

    // MARK: - Chrome

    private var header: some View {
        VStack(spacing: Theme.Spacing.s) {
            Text("Rasoi")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Text(AppCopy.appTagline)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            HStack(spacing: Theme.Spacing.s) {
                ForEach(0..<Self.pageCount, id: \.self) { index in
                    Circle()
                        .fill(index == page ? Theme.saffron : Theme.separator)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, Theme.Spacing.s)
            .accessibilityHidden(true)
        }
        .padding(.top, Theme.Spacing.xl)
        .padding(.bottom, Theme.Spacing.l)
    }

    private var footer: some View {
        HStack {
            if page > 0 {
                Button("Back") { page -= 1 }
                    .buttonStyle(.bordered)
            }
            Spacer()
            if page < Self.pageCount - 1 {
                Button(page == 0 ? "Next" : "Next") { page += 1 }
                    .buttonStyle(.borderedProminent)
                    .disabled(page == 0 && family.activeMembers.isEmpty)
                    .accessibilityIdentifier("onboarding.next")
            } else {
                Button("Generate my first week") { finish() }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("onboarding.finish")
            }
        }
        .tint(Theme.saffron)
        .padding(Theme.Spacing.l)
    }

    // MARK: - Pages

    private var familyPage: some View {
        page(title: "Who eats here?", subtitle: "Ages help Rasoi pick meals that suit everyone at the table.") {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("onboarding.name")
                Picker("Role", selection: $role) {
                    ForEach(MemberRole.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("onboarding.role")
                .onChange(of: role) { _, newValue in
                    let years = newValue == .child ? -5 : -35
                    dateOfBirth = Calendar.rasoi.date(byAdding: .year, value: years, to: .now) ?? .now
                }
                DatePicker("Date of birth", selection: $dateOfBirth, in: ...Date.now, displayedComponents: .date)
                    .accessibilityIdentifier("onboarding.dob")
                Button("Add to family") { addMember() }
                    .buttonStyle(.bordered)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("onboarding.addMember")

                if !family.activeMembers.isEmpty {
                    Divider()
                    ForEach(family.activeMembers) { member in
                        HStack {
                            Image(systemName: member.avatarSymbol)
                                .foregroundStyle(Theme.saffron)
                            Text(member.name)
                            Spacer()
                            Text("\(member.ageYears())")
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
    }

    private var dietPage: some View {
        page(title: "What do you eat?", subtitle: AppCopy.vegetarianOnlyNote) {
            VStack(spacing: Theme.Spacing.s) {
                Toggle("Eggs are fine", isOn: Binding(get: { diet.profile.eggsOK }, set: { diet.setEggsOK($0) }))
                Toggle("Dairy is fine", isOn: Binding(get: { diet.profile.dairyOK }, set: { diet.setDairyOK($0) }))
                Toggle("Nut free", isOn: Binding(get: { diet.profile.nutFree }, set: { diet.setNutFree($0) }))
                Toggle("Gluten free", isOn: Binding(get: { diet.profile.glutenFree }, set: { diet.setGlutenFree($0) }))
            }
            .tint(Theme.saffron)
        }
    }

    private var kitchenPage: some View {
        page(title: "What do you cook with?", subtitle: "Recipes that need equipment you don't have stay out of the plan.") {
            VStack(spacing: Theme.Spacing.s) {
                ForEach(Appliance.allCases, id: \.self) { appliance in
                    Toggle(appliance.label, isOn: Binding(
                        get: { diet.has(appliance) },
                        set: { _ in diet.toggleAppliance(appliance) }
                    ))
                }
            }
            .tint(Theme.saffron)
        }
    }

    private var storesPage: some View {
        page(title: "Where do you shop?", subtitle: "Pick the stores you usually visit. You can add addresses later.") {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                TextField("Zip code", text: $zipDraft)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .accessibilityIdentifier("onboarding.zip")
                Text(AppCopy.zipCodePrivacyNote)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                Divider()
                ForEach(stores) { store in
                    Toggle(isOn: Binding(
                        get: { store.isPreferred },
                        set: { store.isPreferred = $0; diet.save() }
                    )) {
                        VStack(alignment: .leading) {
                            Text(store.name)
                            Text(store.kind.label)
                                .font(.footnote)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
            .tint(Theme.saffron)
        }
    }

    private func page<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(title)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                content()
            }
            .padding(Theme.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Actions

    private func addMember() {
        family.addMember(name: name, dateOfBirth: dateOfBirth, role: role)
        name = ""
        Haptics.success()
    }

    private func finish() {
        diet.setZipCode(zipDraft)
        diet.profile.hasCompletedOnboarding = true
        diet.save()
        Haptics.success()
    }
}
