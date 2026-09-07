import SwiftData
import SwiftUI

/// Where the household shops, in the order they shop (SPEC §4.5).
struct StoresView: View {
    @State private var model: StoresViewModel
    @State private var editing: Store?
    @State private var isAdding = false

    init(context: ModelContext) {
        _model = State(initialValue: StoresViewModel(context: context))
    }

    var body: some View {
        List {
            Section {
                ForEach(model.stores) { store in
                    Button { editing = store } label: { row(store) }
                        .buttonStyle(.plain)
                }
                .onMove { model.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { offsets in
                    for index in offsets { model.remove(model.stores[index]) }
                }
            } header: {
                Text("Your stores")
            } footer: {
                Text("The weekly list is split across the stores you shop at, in this order. Drag to reorder.")
            }
        }
        .navigationTitle("Stores")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { isAdding = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add a store")
            }
            ToolbarItem(placement: .topBarLeading) { EditButton() }
        }
        .sheet(isPresented: $isAdding) { StoreEditView(model: model, store: nil) }
        .sheet(item: $editing) { store in StoreEditView(model: model, store: store) }
        .onAppear { model.load() }
    }

    private func row(_ store: Store) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: store.kind.symbolName)
                .foregroundStyle(store.isPreferred ? Theme.saffron : Theme.textSecondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.name)
                    .foregroundStyle(Theme.textPrimary)
                Text(store.address.isEmpty ? store.kind.label : store.address)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if !store.isPreferred {
                Text("not shopping here")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Edit one store: what it is called, what kind of shop it is, and which aisles you use it for.
struct StoreEditView: View {
    @Environment(\.dismiss) private var dismiss
    let model: StoresViewModel
    let store: Store?

    @State private var name: String
    @State private var kind: StoreKind
    @State private var address: String
    @State private var isPreferred: Bool
    @State private var affinities: Set<IngredientCategory>

    init(model: StoresViewModel, store: Store?) {
        self.model = model
        self.store = store
        _name = State(initialValue: store?.name ?? "")
        _kind = State(initialValue: store?.kind ?? .supermarket)
        _address = State(initialValue: store?.address ?? "")
        _isPreferred = State(initialValue: store?.isPreferred ?? true)
        _affinities = State(initialValue: store?.affinities
                            ?? Set(StoresViewModel.defaultAffinity(for: .supermarket)))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    Picker("Kind", selection: $kind) {
                        ForEach(StoreKind.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    TextField("Address", text: $address)
                    Toggle("Shop here", isOn: $isPreferred)
                } footer: {
                    Text("Only the stores you shop at get lines on the weekly list.")
                }

                Section {
                    ForEach(IngredientCategory.allCases, id: \.self) { category in
                        Toggle(category.label, isOn: Binding(
                            get: { affinities.contains(category) },
                            set: { isOn in
                                if isOn { affinities.insert(category) } else { affinities.remove(category) }
                            }
                        ))
                    }
                } header: {
                    Text("What you buy here")
                } footer: {
                    Text("A speciality shop wins over a supermarket for the aisles it claims.")
                }
            }
            .navigationTitle(store == nil ? "Add a store" : name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onChange(of: kind) { _, newKind in
                if store == nil {
                    affinities = Set(StoresViewModel.defaultAffinity(for: newKind))
                }
            }
        }
    }

    private func save() {
        if let store {
            model.update(store, name: name, kind: kind, address: address,
                         isPreferred: isPreferred, affinities: affinities)
        } else {
            let created = model.addStore(name: name, kind: kind, address: address, isPreferred: isPreferred)
            model.update(created, affinities: affinities)
        }
        Haptics.success()
        dismiss()
    }
}
