import Foundation
import SwiftData

/// The single place Rasoi's SwiftData stack is configured.
///
/// Every model type is registered in `models`; new entities are appended there as their tasks
/// land so the on-disk store, previews and tests always share one schema. All persistence is
/// local — there is no CloudKit configuration and no remote store (SPEC R1, R7).
enum Persistence {
    /// Every `@Model` type Rasoi persists, in the order they were introduced.
    static var models: [any PersistentModel.Type] {
        [
            HouseholdMember.self,
            DietProfile.self,
            Store.self,
            Ingredient.self,
        ]
    }

    /// Built once: `ModelConfiguration` and `ModelContainer` must be handed the *same* schema
    /// instance, or SwiftData cannot resolve entities and traps on the first insert.
    static let schema = Schema(models)

    /// Builds a container. `inMemory` gives a throw-away store for tests and previews.
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        // The configuration deliberately does NOT carry its own `schema:` — handing a separate
        // Schema instance to both the configuration and the container leaves SwiftData unable to
        // resolve entities, and it traps on the first insert or fetch.
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    /// A throw-away in-memory container. Tests and SwiftUI previews use this.
    static func inMemory() throws -> ModelContainer {
        try makeContainer(inMemory: true)
    }

    /// The app's on-disk container. Built once on first use.
    static let shared: ModelContainer = {
        do {
            return try makeContainer()
        } catch {
            // A container that cannot open means the app has no data at all; there is no
            // meaningful degraded mode, so surface it loudly rather than silently losing data.
            fatalError("Rasoi could not open its local database: \(error)")
        }
    }()
}
