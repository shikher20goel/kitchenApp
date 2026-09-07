import SwiftData
import XCTest
@testable import Rasoi

final class PersistenceTests: XCTestCase {
    @MainActor
    func testInMemoryContainerIsCreated() throws {
        let container = try TestContainer.make()
        XCTAssertTrue(container.configurations.allSatisfy(\.isStoredInMemoryOnly),
                      "Test containers must never touch the on-disk store.")
    }

    @MainActor
    func testContextCanSave() throws {
        let stack = try TestContainer.makeStack()
        XCTAssertNoThrow(try stack.context.save())
    }

    func testSchemaMatchesRegisteredModels() {
        XCTAssertEqual(Persistence.schema.entities.count, Persistence.models.count,
                       "Every model registered in Persistence.models should appear in the schema.")
    }
}
