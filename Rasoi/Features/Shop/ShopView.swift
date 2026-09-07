import SwiftData
import SwiftUI

/// The Shop tab (SPEC §4.4): the week's list, grouped by store then by aisle. Ticking an item is
/// what puts it in the pantry.
struct ShopView: View {
    @State private var model: ShopViewModel
    @State private var isAdding = false
    @State private var whyItem: GroceryItem?
    @State private var isSharing = false

    init(context: ModelContext) {
        _model = State(initialValue: ShopViewModel(context: context))
    }

    var body: some View {
        List {
            Section {
                Button {
                    model.buildFromPlan()
                    Haptics.success()
                } label: {
                    Label(model.isEmpty ? "Build list from the plan" : "Update list from the plan",
                          systemImage: "list.bullet.rectangle")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: Theme.largeTapTarget)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.saffron)
                .accessibilityIdentifier("shop.build")
                .listRowBackground(Color.clear)

                if !model.isEmpty {
                    Text("\(model.remainingCount) still to get")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .listRowBackground(Color.clear)
                }
            }

            if model.isEmpty {
                ContentUnavailableView(
                    "Nothing to buy yet",
                    systemImage: "cart",
                    description: Text("Plan a week first, then build the list here.")
                )
            }

            ForEach(model.sections) { section in
                Section {
                    ForEach(section.categories) { category in
                        ForEach(category.items, id: \.persistentModelID) { item in
                            row(item)
                        }
                    }
                } header: {
                    Text(section.storeName)
                }
            }
        }
        .navigationTitle("Shop")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { isAdding = true } label: { Image(systemName: "plus") }
                    .accessibilityIdentifier("shop.add")
                    .accessibilityLabel("Add an item")
            }
            ToolbarItem(placement: .topBarLeading) {
                Button { isSharing = true } label: { Image(systemName: "square.and.arrow.up") }
                    .disabled(model.isEmpty)
                    .accessibilityLabel("Share the list")
            }
        }
        .sheet(isPresented: $isAdding) { AddGroceryItemSheet(model: model) }
        .sheet(item: $whyItem) { item in WhySheet(item: item) }
        .sheet(isPresented: $isSharing) {
            ShareLink(item: model.shareText()) {
                Label("Share the list", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity, minHeight: Theme.largeTapTarget)
            }
            .padding(Theme.Spacing.xl)
            .presentationDetents([.height(160)])
        }
        .onAppear { model.load() }
    }

    private func row(_ item: GroceryItem) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            Button {
                model.setChecked(!item.isChecked, for: item)
                Haptics.tap()
            } label: {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isChecked ? Theme.sage : Theme.separator)
                    .frame(width: Theme.minimumTapTarget, height: Theme.minimumTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isChecked ? "Uncheck \(item.ingredient?.name ?? "item")"
                                               : "Check \(item.ingredient?.name ?? "item")")
            .accessibilityIdentifier("shop.check")

            VStack(alignment: .leading, spacing: 2) {
                Text(item.ingredient?.name ?? "Item")
                    .strikethrough(item.isChecked, color: Theme.textSecondary)
                    .foregroundStyle(item.isChecked ? Theme.textSecondary : Theme.textPrimary)
                HStack(spacing: Theme.Spacing.s) {
                    Text(Units.display(Quantity(item.quantity, item.unit)))
                    if item.isStapleTopUp { Text("· weekly staple") }
                    if item.addedManually { Text("· added by you") }
                }
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            if !item.neededFor.isEmpty {
                Button { whyItem = item } label: {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Why is \(item.ingredient?.name ?? "this") on the list?")
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { model.remove(item) } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }
}

/// Which meals need this.
struct WhySheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: GroceryItem

    var body: some View {
        NavigationStack {
            List {
                Section("Needed for") {
                    ForEach(item.neededFor, id: \.self) { title in
                        Text(title)
                    }
                }
            }
            .navigationTitle(item.ingredient?.name ?? "Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium])
    }
}

/// Add something the plan did not ask for.
struct AddGroceryItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    let model: ShopViewModel

    @State private var query = ""
    @State private var selected: Ingredient?
    @State private var quantity: Double = 1

    var body: some View {
        NavigationStack {
            Form {
                Section("What do you need?") {
                    TextField("Search ingredients", text: $query)
                        .textInputAutocapitalization(.never)
                        .accessibilityIdentifier("shop.search")
                    ForEach(model.searchCatalog(query).prefix(8), id: \.persistentModelID) { ingredient in
                        Button {
                            selected = ingredient
                            quantity = ingredient.defaultUnit == .count ? 1 : 200
                            Haptics.selection()
                        } label: {
                            HStack {
                                Text(ingredient.name).foregroundStyle(Theme.textPrimary)
                                Spacer()
                                if selected?.persistentModelID == ingredient.persistentModelID {
                                    Image(systemName: "checkmark").foregroundStyle(Theme.saffron)
                                }
                            }
                        }
                        .accessibilityIdentifier("shop.result.\(ingredient.name)")
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
                        }
                    }
                }
            }
            .navigationTitle("Add to the list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let selected {
                            model.addManualItem(selected, quantity: quantity)
                            Haptics.success()
                        }
                        dismiss()
                    }
                    .disabled(selected == nil || quantity <= 0)
                    .accessibilityIdentifier("shop.confirmAdd")
                }
            }
        }
    }
}
