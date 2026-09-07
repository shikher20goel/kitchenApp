import Foundation
import SwiftData
import SwiftUI

/// Decides what the app opens into: onboarding on a fresh install, the five tabs after that.
/// Also does the one-time bootstrap — default stores and the bundled catalog.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [DietProfile]
    @Query private var settingsRows: [AppSettings]
    @State private var isReady = false

    var body: some View {
        Group {
            if !isReady {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background)
            } else if profiles.first?.hasCompletedOnboarding == true {
                ContentView()
            } else {
                OnboardingFlow(context: context)
            }
        }
        .task { bootstrap() }
        .preferredColorScheme(settingsRows.first?.appearance.colorScheme)
    }

    /// Idempotent: creates the singletons, the default stores and imports the catalog once.
    private func bootstrap() {
        guard !isReady else { return }
        _ = DietProfile.current(in: context)
        _ = AppSettings.current(in: context)
        StoreSeeder.seedDefaultsIfEmpty(in: context)
        do {
            try SeedImporter.importIfNeeded(in: context)
        } catch {
            // A missing or malformed catalog must not stop the app: the household can still add
            // their own recipes, and the next launch retries the import.
            assertionFailure("Seed import failed: \(error)")
        }
        UITestSupport.installDemoHouseholdIfRequested(in: context)
        try? context.save()
        isReady = true
    }
}
