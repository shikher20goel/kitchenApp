import Foundation
import SwiftData

/// Bridges a cooked meal to the pantry. The arithmetic lives in the `PantryDepletion` engine;
/// this type is the seam views talk to, so a screen never reaches into an engine directly.
struct PantryDepletionService: FeedbackViewModel.Depleting {
    @MainActor
    func deplete(slot: MealSlot, in context: ModelContext) {
        PantryDepletion.apply(slot: slot, in: context)
    }
}
