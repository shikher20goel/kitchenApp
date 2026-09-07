import Foundation
import SwiftData

/// Whole-store operations: the only place in Rasoi that deletes household data in bulk (SPEC R6).
///
/// Nothing else may call `deleteEverything` — every other screen removes at most the one row the
/// household asked it to.
@MainActor
enum DataManager {
    /// Wipes every entity, then puts back what shipped with the app: the default stores, the
    /// seeded catalog and the two singleton rows. The household is left where a fresh install
    /// would leave it, at onboarding.
    static func deleteEverything(in context: ModelContext, bundle: Bundle = .main) throws {
        for model in Persistence.models {
            try deleteAll(model, in: context)
        }
        try context.save()

        _ = DietProfile.current(in: context)
        _ = AppSettings.current(in: context)
        StoreSeeder.seedDefaultsIfEmpty(in: context)
        try SeedImporter.reimport(in: context, bundle: bundle)
        try context.save()
    }

    /// Generic hop so the loop above can work over `Persistence.models`, which holds existentials.
    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws {
        try context.delete(model: type)
    }
}
