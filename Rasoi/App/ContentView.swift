import SwiftData
import SwiftUI

/// The five tabs of Rasoi (SPEC §4). Each tab owns a `NavigationStack`; the feature screens
/// replace these placeholders as their milestones land.
struct ContentView: View {
    @Environment(\.modelContext) private var context

    enum Tab: Hashable {
        case today, plan, pantry, shop, more
    }

    @State private var selection: Tab = .today

    var body: some View {
        TabView(selection: $selection) {
            placeholder(title: "Today", detail: "Tonight's dinner, the day's meals and a quick snack.")
                .tabItem { Label("Today", systemImage: "sun.max") }
                .tag(Tab.today)

            NavigationStack { PlanView(context: context) }
                .tabItem { Label("Plan", systemImage: "calendar") }
                .tag(Tab.plan)

            NavigationStack { PantryView(context: context) }
                .tabItem { Label("Pantry", systemImage: "refrigerator") }
                .tag(Tab.pantry)

            NavigationStack { ShopView(context: context) }
                .tabItem { Label("Shop", systemImage: "cart") }
                .tag(Tab.shop)

            NavigationStack { MoreView() }
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
                .tag(Tab.more)
        }
        .tint(Theme.saffron)
    }

    private func placeholder(title: String, detail: String) -> some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                .rasoiCard()
                .padding(Theme.Spacing.l)
            }
            .navigationTitle(title)
        }
    }
}

#Preview {
    ContentView()
}
