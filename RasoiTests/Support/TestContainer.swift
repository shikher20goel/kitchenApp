import Foundation
import SwiftData
import XCTest
@testable import Rasoi

/// Fresh in-memory SwiftData stacks for tests. Nothing a test writes ever touches the real store.
enum TestContainer {
    /// A new, empty container using the app's real schema.
    static func make() throws -> ModelContainer {
        try Persistence.inMemory()
    }

    /// A new container plus its main context — the common case.
    @MainActor
    static func makeContext() throws -> ModelContext {
        try make().mainContext
    }
}
