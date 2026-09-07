import SwiftData
import SwiftUI

/// The five tabs of Rasoi (SPEC §4). Each tab owns its own `NavigationStack`.
struct ContentView: View {
    enum Tab: String, Hashable {
        case today, plan, pantry, shop, more
    }

    @Environment(\.modelContext) private var context
    @State private var selection: Tab = .today
    /// Built on first appearance and kept: see `TabModels`.
    @State private var models: TabModels?

    var body: some View {
        Group {
            if let models {
                tabs(models)
            } else {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background)
            }
        }
        .onAppear {
            if models == nil { models = TabModels(context: context) }
            if let requested = UITestSupport.initialTab, let tab = Tab(rawValue: requested) {
                selection = tab
            }
        }
    }

    private func tabs(_ models: TabModels) -> some View {
        TabView(selection: $selection) {
            NavigationStack { TodayView(model: models.today) }
                .tabItem { Label("Today", systemImage: "sun.max") }
                .tag(Tab.today)

            NavigationStack { PlanView(model: models.plan) }
                .tabItem { Label("Plan", systemImage: "calendar") }
                .tag(Tab.plan)

            NavigationStack { PantryView(model: models.pantry) }
                .tabItem { Label("Pantry", systemImage: "refrigerator") }
                .tag(Tab.pantry)

            NavigationStack { ShopView(model: models.shop) }
                .tabItem { Label("Shop", systemImage: "cart") }
                .tag(Tab.shop)

            NavigationStack { MoreView() }
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
                .tag(Tab.more)
        }
        .tint(Theme.saffron)
    }
}

#Preview {
    ContentView()
}
