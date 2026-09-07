import SwiftData
import SwiftUI

/// "Find nearby" (SPEC §4.5). The only screen in Rasoi that talks to the network, and only when
/// the household taps Search. Nothing that comes back is saved until they tap Add.
struct FindStoresSheet: View {
    @Environment(\.dismiss) private var dismiss

    let model: StoresViewModel
    let finder: StoreFinding

    @State private var zipCode: String
    @State private var results: [StoreSearchResult] = []
    @State private var addedIDs: Set<String> = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var hasSearched = false

    init(model: StoresViewModel, zipCode: String, finder: StoreFinding = MapKitStoreFinder()) {
        self.model = model
        self.finder = finder
        _zipCode = State(initialValue: zipCode)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("Zip code", text: $zipCode)
                            .keyboardType(.numberPad)
                            .accessibilityIdentifier("finder.zip")
                        Button("Search") { Task { await search() } }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.saffron)
                            .disabled(!DietSettingsViewModel.isValidZipCode(zipCode) || isSearching)
                            .accessibilityIdentifier("finder.search")
                    }
                } footer: {
                    Text(AppCopy.findNearbyPrivacyNote)
                }

                if isSearching {
                    HStack {
                        ProgressView()
                        Text("Looking for shops near \(zipCode)…")
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.circle")
                            .foregroundStyle(Theme.terracotta)
                    }
                }

                if hasSearched, results.isEmpty, !isSearching, errorMessage == nil {
                    ContentUnavailableView(
                        "Nothing found",
                        systemImage: "mappin.slash",
                        description: Text("Try another zip code, or add the shop by hand.")
                    )
                }

                if !results.isEmpty {
                    Section("Within \(Int(StoreSearch.defaultRadiusMeters / 1000)) km") {
                        ForEach(results) { result in
                            row(result)
                        }
                    }
                }
            }
            .navigationTitle("Find nearby")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private func row(_ result: StoreSearchResult) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: result.kind.symbolName)
                .foregroundStyle(Theme.saffron)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.name)
                    .foregroundStyle(Theme.textPrimary)
                Text([result.kind.label, distanceText(result), result.address]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if addedIDs.contains(result.id) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.sage)
            } else {
                Button("Add") { add(result) }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("finder.add")
            }
        }
        .padding(.vertical, 2)
    }

    private func distanceText(_ result: StoreSearchResult) -> String {
        guard let metres = result.distanceMeters else { return "" }
        return metres < 1000 ? "\(Int(metres)) m" : String(format: "%.1f km", metres / 1000)
    }

    private func search() async {
        isSearching = true
        errorMessage = nil
        defer {
            isSearching = false
            hasSearched = true
        }
        do {
            results = try await finder.search(zipCode: zipCode)
        } catch {
            results = []
            errorMessage = error.localizedDescription
        }
    }

    private func add(_ result: StoreSearchResult) {
        model.addStore(
            name: result.name,
            kind: result.kind,
            address: result.address,
            latitude: result.latitude,
            longitude: result.longitude
        )
        addedIDs.insert(result.id)
        Haptics.success()
    }
}
