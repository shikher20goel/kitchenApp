import Foundation
import SwiftData

/// Edits the household's one `DietProfile` (SPEC §4.5).
///
/// Everything here is a household choice: Rasoi never classifies an ingredient as good or bad and
/// never sets a target. Exclusions are resolved through the catalog so "palak" and "Spinach" mean
/// the same thing everywhere.
@MainActor
@Observable
final class DietSettingsViewModel {
    private let context: ModelContext
    let profile: DietProfile

    /// Set when the last zip code entry was rejected; cleared on the next valid one.
    private(set) var zipCodeError: String?

    static let minimumWeekdayCookMinutes = 15
    static let maximumWeekdayCookMinutes = 90

    init(context: ModelContext) {
        self.context = context
        self.profile = DietProfile.current(in: context)
        try? context.save()
    }

    // MARK: - Zip code

    /// Five digits, nothing else. A zip is only ever used locally to centre a store search.
    static func isValidZipCode(_ text: String) -> Bool {
        text.count == 5 && text.allSatisfy(\.isNumber)
    }

    @discardableResult
    func setZipCode(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard Self.isValidZipCode(trimmed) else {
            zipCodeError = "A zip code is five digits."
            return false
        }
        zipCodeError = nil
        profile.zipCode = trimmed
        save()
        return true
    }

    // MARK: - Exclusions

    /// Catalog names matching what is being typed, minus what is already excluded.
    func exclusionSuggestions(for query: String) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return [] }
        let catalog = (try? context.fetch(FetchDescriptor<Ingredient>())) ?? []
        let excluded = Set(profile.excludedIngredients.map(Ingredient.fold))
        return Ingredient.search(trimmed, in: catalog, limit: 8)
            .map(\.name)
            .filter { !excluded.contains(Ingredient.fold($0)) }
    }

    /// Adds an exclusion, storing the catalog's own spelling when the text matches a known
    /// ingredient or one of its aliases.
    func addExclusion(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let name = canonicalName(for: trimmed)
        guard !profile.excludes(ingredientNamed: name) else { return }
        profile.excludedIngredients.append(name)
        save()
    }

    func removeExclusion(_ name: String) {
        let folded = Ingredient.fold(name)
        profile.excludedIngredients.removeAll { Ingredient.fold($0) == folded }
        save()
    }

    /// Resolves an alias to the catalog name; unknown text is kept as typed.
    private func canonicalName(for text: String) -> String {
        if let exact = Ingredient.named(text, in: context) { return exact.name }
        let catalog = (try? context.fetch(FetchDescriptor<Ingredient>())) ?? []
        let folded = Ingredient.fold(text)
        if let byAlias = catalog.first(where: { $0.aliases.contains { Ingredient.fold($0) == folded } }) {
            return byAlias.name
        }
        return text
    }

    // MARK: - Kitchen

    func toggleAppliance(_ appliance: Appliance) {
        var set = profile.applianceSet
        if set.contains(appliance) {
            set.remove(appliance)
        } else {
            set.insert(appliance)
        }
        profile.applianceSet = set
        save()
    }

    func has(_ appliance: Appliance) -> Bool {
        profile.applianceSet.contains(appliance)
    }

    /// Every cuisine the catalog knows about, plus any the household already prefers.
    var availableCuisines: [String] {
        let fromCatalog = (try? context.fetch(FetchDescriptor<Recipe>()))?.map(\.cuisine) ?? []
        let all = Set(fromCatalog + profile.preferredCuisines + DietProfile.defaultCuisines)
            .filter { !$0.isEmpty }
        return all.sorted()
    }

    func toggleCuisine(_ cuisine: String) {
        if profile.preferredCuisines.contains(cuisine) {
            profile.preferredCuisines.removeAll { $0 == cuisine }
        } else {
            profile.preferredCuisines.append(cuisine)
        }
        save()
    }

    func prefers(_ cuisine: String) -> Bool {
        profile.preferredCuisines.contains(cuisine)
    }

    /// Weeknight dinners are capped by this; the slider stays inside a sane range.
    func setWeekdayMaxCookMinutes(_ minutes: Int) {
        profile.weekdayMaxCookMinutes = min(
            Self.maximumWeekdayCookMinutes,
            max(Self.minimumWeekdayCookMinutes, minutes)
        )
        save()
    }

    /// Gregorian weekday number, 1 = Sunday.
    func setShoppingWeekday(_ weekday: Int) {
        guard (1...7).contains(weekday) else { return }
        profile.shoppingWeekday = weekday
        save()
    }

    func setEggsOK(_ value: Bool) { profile.eggsOK = value; save() }
    func setDairyOK(_ value: Bool) { profile.dairyOK = value; save() }
    func setNutFree(_ value: Bool) { profile.nutFree = value; save() }
    func setGlutenFree(_ value: Bool) { profile.glutenFree = value; save() }

    func save() {
        try? context.save()
    }
}

extension Int {
    /// "Sunday", "Monday", … for a Gregorian weekday number.
    var weekdayName: String {
        let symbols = Calendar.rasoi.weekdaySymbols
        guard (1...symbols.count).contains(self) else { return "" }
        return symbols[self - 1]
    }
}
