import SwiftData
import SwiftUI

/// The Pantry tab (SPEC §4.3): what is in the fridge, the pantry and the freezer.
struct PantryView: View {
    /// Built once by `ContentView` and handed in. Building it here instead would rebuild it
    /// every time the tab bar's body ran, which is far more often than a tab is opened.
    let model: PantryViewModel
    @State private var isAdding = false
    @State private var usingItem: PantryItem?
    @State private var isMarkingUsed = false

    var body: some View {
        content(model)
        // Sheets belong on the stable outer body, not inside the lazily built content.
        .sheet(isPresented: $isAdding) {
                AddPantryItemSheet(model: model)
        }
        .sheet(isPresented: $isMarkingUsed) {
            if let usingItem {
                MarkUsedSheet(model: model, item: usingItem)
            }
        }
    }

    @ViewBuilder
    private func content(_ model: PantryViewModel) -> some View {
        @Bindable var model = model
        List {
            if !model.expiringSoon().isEmpty {
                Section {
                    ForEach(model.expiringSoon()) { item in
                        row(model: model, item: item, showLocation: true)
                    }
                } header: {
                    Label("Use these first", systemImage: "clock")
                }
            }

            Section {
                if model.items.isEmpty {
                    ContentUnavailableView(
                        model.searchText.isEmpty ? "Nothing in the \(model.location.label.lowercased()) yet" : "No match",
                        systemImage: model.location.symbolName,
                        description: Text(model.searchText.isEmpty
                                          ? "Add what you have and Rasoi will plan around it."
                                          : "Nothing here matches “\(model.searchText)”.")
                    )
                } else {
                    ForEach(model.items) { item in
                        row(model: model, item: item, showLocation: false)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    model.ranOut(item)
                                    Haptics.tap()
                                } label: {
                                    Label("Ran out", systemImage: "tray")
                                }
                                Button {
                                    usingItem = item
                                    isMarkingUsed = true
                                } label: {
                                    Label("Mark used", systemImage: "minus.circle")
                                }
                                .tint(Theme.sage)
                                .disabled(isMarkingUsed)
                            }
                    }
                }
            } header: {
                Picker("Location", selection: $model.location) {
                    ForEach(PantryLocation.allCases, id: \.self) { location in
                        Text(location.label).tag(location)
                    }
                }
                .pickerStyle(.segmented)
                .textCase(nil)
                .padding(.bottom, Theme.Spacing.s)
                .accessibilityIdentifier("pantry.location")
            }
        }
        .searchable(text: $model.searchText, prompt: "Search the pantry")
        .navigationTitle("Pantry")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { isAdding = true } label: { Image(systemName: "plus") }
                    .accessibilityIdentifier("pantry.add")
                    .accessibilityLabel("Add to pantry")
            }
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Picker("Sort", selection: $model.sortOrder) {
                        ForEach(PantryViewModel.SortOrder.allCases, id: \.self) { order in
                            Text(order.label).tag(order)
                        }
                    }
                    Section {
                        Button {} label: { Label("Scan fridge — coming later", systemImage: "camera") }
                            .disabled(true)
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel("Sort and more")
            }
        }
        .task { model.load() }
    }

    private func row(model: PantryViewModel, item: PantryItem, showLocation: Bool) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: item.ingredient?.category.symbolName ?? "shippingbox")
                .foregroundStyle(Theme.sage)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.ingredient?.name ?? "Unknown")
                    .font(.body)
                    .foregroundStyle(Theme.textPrimary)
                HStack(spacing: Theme.Spacing.s) {
                    Text(quantityLabel(item))
                    if showLocation {
                        Text("· \(item.location.label)")
                    }
                    if let chip = expiryChip(item) {
                        Text(chip.text)
                            .foregroundStyle(chip.color)
                    }
                }
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Stepper(
                value: Binding(
                    get: { item.quantity },
                    set: { model.setQuantity($0, for: item) }
                ),
                in: 0...100_000,
                step: stepSize(item)
            ) {
                EmptyView()
            }
            .labelsHidden()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.ingredient?.name ?? "Item"), \(quantityLabel(item))")
    }

    private func quantityLabel(_ item: PantryItem) -> String {
        let quantity = item.quantity
        let rounded = quantity.rounded()
        let text = abs(quantity - rounded) < 0.01
            ? String(Int(rounded))
            : String(format: "%.1f", quantity)
        let unit = item.unit.shortLabel
        return unit.isEmpty ? "×\(text)" : "\(text) \(unit)"
    }

    private func stepSize(_ item: PantryItem) -> Double {
        switch item.unit.dimension {
        case .mass: return 50
        case .volume: return 100
        case .discrete: return 1
        }
    }

    /// Plain, factual expiry text. Nothing here scolds anyone for food that went off.
    private func expiryChip(_ item: PantryItem) -> (text: String, color: Color)? {
        guard let expiresAt = item.expiresAt else { return nil }
        let days = ShelfLife.daysUntilExpiry(expiresAt, on: .now)
        switch days {
        case ..<0: return ("past its date", Theme.terracotta)
        case 0: return ("use today", Theme.terracotta)
        case 1: return ("1 day left", Theme.saffron)
        case 2...3: return ("\(days) days left", Theme.saffron)
        default: return ("\(days) days left", Theme.textSecondary)
        }
    }
}

/// Search the catalog and add what you bought.
struct AddPantryItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    let model: PantryViewModel

    @State private var query = ""
    @State private var selected: Ingredient?
    @State private var quantity: Double = 1
    @State private var unit: MeasurementUnit = .gram
    @State private var location: PantryLocation = .fridge

    var body: some View {
        NavigationStack {
            Form {
                Section("What did you get?") {
                    TextField("Search ingredients", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("pantry.search")
                    ForEach(model.searchCatalog(query).prefix(8), id: \.persistentModelID) { ingredient in
                        Button {
                            select(ingredient)
                        } label: {
                            HStack {
                                Text(ingredient.name)
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                if selected?.persistentModelID == ingredient.persistentModelID {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Theme.saffron)
                                }
                            }
                        }
                        .accessibilityIdentifier("pantry.result.\(ingredient.name)")
                    }
                }

                if let selected {
                    Section(selected.name) {
                        HStack {
                            Text("Quantity")
                            Spacer()
                            TextField("Quantity", value: $quantity, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 90)
                                .accessibilityIdentifier("pantry.quantity")
                        }
                        Picker("Unit", selection: $unit) {
                            ForEach(MeasurementUnit.allCases, id: \.self) { unit in
                                Text(unit == .count ? "count" : unit.rawValue).tag(unit)
                            }
                        }
                        Picker("Where", selection: $location) {
                            ForEach(PantryLocation.allCases, id: \.self) { location in
                                Text(location.label).tag(location)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add to pantry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { add() }
                        .disabled(selected == nil || quantity <= 0)
                        .accessibilityIdentifier("pantry.confirmAdd")
                }
            }
        }
        .onAppear { location = model.location }
    }

    private func select(_ ingredient: Ingredient) {
        selected = ingredient
        unit = ingredient.defaultUnit
        quantity = ingredient.defaultUnit == .count ? 1 : 200
        Haptics.selection()
    }

    private func add() {
        guard let selected else { return }
        model.add(selected, quantity: quantity, unit: unit, location: location)
        model.location = location
        Haptics.success()
        dismiss()
    }
}

/// "I used some of this" — takes an amount off without leaving the list.
struct MarkUsedSheet: View {
    @Environment(\.dismiss) private var dismiss
    let model: PantryViewModel
    let item: PantryItem

    @State private var amount: Double = 0

    var body: some View {
        NavigationStack {
            Form {
                Section(item.ingredient?.name ?? "Item") {
                    HStack {
                        Text("Used")
                        Spacer()
                        TextField("Amount", value: $amount, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text(item.unit.shortLabel)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Text("\(item.quantity, format: .number) \(item.unit.shortLabel) in the \(item.location.label.lowercased())")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .navigationTitle("Mark used")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.markUsed(item, quantity: amount)
                        Haptics.tap()
                        dismiss()
                    }
                    .disabled(amount <= 0)
                }
            }
        }
        .onAppear { amount = max(1, (item.quantity / 4).rounded()) }
    }
}
