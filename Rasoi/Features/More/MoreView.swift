import SwiftData
import SwiftUI

/// The More tab (SPEC §4.5): everything that is not a daily action.
struct MoreView: View {
    @Environment(\.modelContext) private var context
    @State private var showDeleteDialog = false
    @State private var showDeleteConfirmation = false
    @State private var deleteError: String?

    var body: some View {
        List {
            Section("Household") {
                NavigationLink("Family") { FamilyListView(context: context) }
                NavigationLink("Diet & Kitchen") { DietSettingsView(context: context) }
                NavigationLink("Stores") { StoresView(context: context) }
            }

            Section("Cooking") {
                NavigationLink("Recipes") { RecipeListView(context: context) }
                NavigationLink("Insights") { InsightsView(context: context) }
            }

            Section("App") {
                NavigationLink("Notifications") { NotificationsSettingsView(context: context) }
                NavigationLink("Appearance") { AppearanceView(context: context) }
                NavigationLink("About") { AboutView() }
            }

            Section {
                NavigationLink("Export your data") { ExportView() }
                Button(AppCopy.deleteAllDataTitle, role: .destructive) {
                    showDeleteDialog = true
                }
            } header: {
                Text("Your data")
            } footer: {
                Text(AppCopy.privacyNote)
            }
        }
        .navigationTitle("More")
        .confirmationDialog(AppCopy.deleteAllDataTitle, isPresented: $showDeleteDialog, titleVisibility: .visible) {
            Button("Continue", role: .destructive) { showDeleteConfirmation = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(AppCopy.deleteAllDataExplanation)
        }
        .alert("Delete everything?", isPresented: $showDeleteConfirmation) {
            Button(AppCopy.deleteAllDataConfirm, role: .destructive) { deleteEverything() }
            Button("Keep my data", role: .cancel) {}
        } message: {
            Text("This is the last step. Your family, pantry, plans and meal history go for good.")
        }
        .alert("Could not delete", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK", role: .cancel) { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }

    private func deleteEverything() {
        do {
            try DataManager.deleteEverything(in: context)
            Haptics.success()
        } catch {
            deleteError = error.localizedDescription
        }
    }
}

/// About: what Rasoi is, and the two notes that must appear verbatim (SPEC R1, R2).
struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text(Theme.appName)
                        .font(.title2.weight(.semibold))
                    Text(AppCopy.appTagline)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.vertical, Theme.Spacing.s)
            }

            Section("Privacy") {
                Text(AppCopy.privacyNote)
            }

            Section("A note on nutrition") {
                Text(AppCopy.notNutritionAdviceNote)
            }

            Section {
                LabeledContent("Version", value: Bundle.main.appVersion)
            }
        }
        .navigationTitle("About")
    }
}

/// A named placeholder for a screen a later milestone fills in. It says plainly that the screen
/// is not built yet rather than pretending to be empty.
struct ComingSoonView: View {
    let title: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: "hammer",
            description: Text("This screen arrives later in the build.")
        )
        .navigationTitle(title)
    }
}

extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
