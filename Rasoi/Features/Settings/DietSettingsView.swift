import SwiftData
import SwiftUI

/// Diet & Kitchen (SPEC §4.5): what the household eats, what it cooks with, and how long a
/// weeknight dinner is allowed to take.
struct DietSettingsView: View {
    @State private var model: DietSettingsViewModel
    @State private var zipDraft: String
    @State private var exclusionDraft: String = ""

    init(context: ModelContext) {
        let model = DietSettingsViewModel(context: context)
        _model = State(initialValue: model)
        _zipDraft = State(initialValue: model.profile.zipCode)
    }

    var body: some View {
        Form {
            Section {
                Toggle("Vegetarian", isOn: .constant(true))
                    .disabled(true)
                Toggle("Eggs are fine", isOn: Binding(
                    get: { model.profile.eggsOK },
                    set: { model.setEggsOK($0) }
                ))
                Toggle("Dairy is fine", isOn: Binding(
                    get: { model.profile.dairyOK },
                    set: { model.setDairyOK($0) }
                ))
                Toggle("Nut free", isOn: Binding(
                    get: { model.profile.nutFree },
                    set: { model.setNutFree($0) }
                ))
                Toggle("Gluten free", isOn: Binding(
                    get: { model.profile.glutenFree },
                    set: { model.setGlutenFree($0) }
                ))
            } header: {
                Text("What you eat")
            } footer: {
                Text(AppCopy.vegetarianOnlyNote)
            }

            Section {
                ChipField(
                    title: "Excluded ingredients",
                    placeholder: "Type an ingredient",
                    suggestions: { model.exclusionSuggestions(for: $0) },
                    values: Binding(
                        get: { model.profile.excludedIngredients },
                        set: { newValue in
                            let old = model.profile.excludedIngredients
                            for removed in old where !newValue.contains(removed) {
                                model.removeExclusion(removed)
                            }
                            for added in newValue where !old.contains(added) {
                                model.addExclusion(added)
                            }
                        }
                    )
                )
            } header: {
                Text("Never suggest")
            } footer: {
                Text("These disappear from the planner, suggestions and search. Aliases count too — add “palak” and spinach dishes go as well.")
            }

            Section("Your kitchen") {
                ForEach(Appliance.allCases, id: \.self) { appliance in
                    Toggle(appliance.label, isOn: Binding(
                        get: { model.has(appliance) },
                        set: { _ in model.toggleAppliance(appliance) }
                    ))
                }
            }

            Section {
                ForEach(model.availableCuisines, id: \.self) { cuisine in
                    Toggle(cuisine, isOn: Binding(
                        get: { model.prefers(cuisine) },
                        set: { _ in model.toggleCuisine(cuisine) }
                    ))
                }
            } header: {
                Text("Cuisines you like")
            } footer: {
                Text("Everything else stays available in Recipes — this only nudges the weekly plan.")
            }

            Section {
                Stepper(
                    "Weeknight dinners: \(model.profile.weekdayMaxCookMinutes) min",
                    value: Binding(
                        get: { model.profile.weekdayMaxCookMinutes },
                        set: { model.setWeekdayMaxCookMinutes($0) }
                    ),
                    in: DietSettingsViewModel.minimumWeekdayCookMinutes...DietSettingsViewModel.maximumWeekdayCookMinutes,
                    step: 5
                )
                Picker("Shopping day", selection: Binding(
                    get: { model.profile.shoppingWeekday },
                    set: { model.setShoppingWeekday($0) }
                )) {
                    ForEach(1...7, id: \.self) { weekday in
                        Text(weekday.weekdayName).tag(weekday)
                    }
                }
            } header: {
                Text("Your week")
            } footer: {
                Text("Weekends can take longer — the cap only applies Monday to Friday.")
            }

            Section {
                TextField("Zip code", text: $zipDraft)
                    .keyboardType(.numberPad)
                    .onSubmit { model.setZipCode(zipDraft) }
                if let error = model.zipCodeError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(Theme.terracotta)
                }
            } header: {
                Text("Where you shop")
            } footer: {
                Text(AppCopy.zipCodePrivacyNote)
            }
        }
        .navigationTitle("Diet & Kitchen")
        .onChange(of: zipDraft) { _, newValue in
            if DietSettingsViewModel.isValidZipCode(newValue) {
                model.setZipCode(newValue)
            }
        }
    }
}
