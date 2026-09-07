import SwiftData
import SwiftUI

@main
struct RasoiApp: App {
    private let container: ModelContainer

    init() {
        // UI tests launch with `-uiTesting` so they start from an empty, in-memory household and
        // never touch (or leave behind) the real store.
        if UITestSupport.isUITesting, let container = try? Persistence.inMemory() {
            self.container = container
        } else {
            self.container = Persistence.shared
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
