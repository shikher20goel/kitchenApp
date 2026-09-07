import SwiftData
import SwiftUI

@main
struct RasoiApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(Persistence.shared)
    }
}
