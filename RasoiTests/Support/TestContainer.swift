import Foundation
import SwiftData
@testable import Rasoi

/// A container plus its main context, kept together.
///
/// A `ModelContext` does not keep its `ModelContainer` alive: hand a test only the context and
/// the container deallocates at the end of the calling line, and the next insert or fetch traps
/// inside SwiftData. Always hold the stack for as long as the context is used.
struct TestStack {
    let container: ModelContainer

    @MainActor
    var context: ModelContext { container.mainContext }
}

/// Fresh in-memory SwiftData stacks for tests. Nothing a test writes ever touches the real store.
enum TestContainer {
    /// A new, empty container using the app's real schema.
    static func make() throws -> ModelContainer {
        try Persistence.inMemory()
    }

    /// A new container and its main context — the common case.
    @MainActor
    static func makeStack() throws -> TestStack {
        TestStack(container: try make())
    }
}
