import Foundation
import SwiftData

/// The five tabs' view models, built once for the life of the app.
///
/// Each of these reads a good part of the store when it loads, so they must not be constructed
/// inside `ContentView.body` — SwiftUI runs a body far more often than a household opens a tab.
@MainActor
@Observable
final class TabModels {
    let today: TodayViewModel
    let plan: PlanViewModel
    let pantry: PantryViewModel
    let shop: ShopViewModel

    init(context: ModelContext) {
        today = TodayViewModel(context: context)
        plan = PlanViewModel(context: context)
        pantry = PantryViewModel(context: context)
        shop = ShopViewModel(context: context)
    }
}
