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

    /// Refreshes the tab the household just switched to.
    ///
    /// A tab's view stays alive in the background, so `.task` runs only once; without this, the
    /// Shop tab would still be showing what it read before the week was planned.
    func reload(_ tab: ContentView.Tab) {
        switch tab {
        case .today: today.load()
        case .plan: plan.load()
        case .pantry: pantry.load()
        case .shop: shop.load()
        case .more: break
        }
    }
}
