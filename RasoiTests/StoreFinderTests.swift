import XCTest
@testable import Rasoi

/// The store finder is the only network-capable code in Rasoi, so its logic is tested through a
/// fake — these tests never touch Apple Maps.
final class StoreFinderTests: XCTestCase {

    /// Stands in for MapKit: returns whatever the test hands it, through the real normalisation.
    private struct FakeStoreFinder: StoreFinding {
        var results: [StoreSearchResult]
        var error: Error?

        func search(zipCode: String, radiusMeters: Double) async throws -> [StoreSearchResult] {
            if let error { throw error }
            return StoreSearch.normalise(results, within: radiusMeters)
        }
    }

    private struct FinderFailure: Error {}

    private func result(_ name: String, address: String = "1 Main St, Jersey City, NJ",
                        kind: StoreKind = .other, distance: Double? = 1_000) -> StoreSearchResult {
        StoreSearchResult(name: name, address: address, kind: kind,
                          latitude: 40.72, longitude: -74.04, distanceMeters: distance)
    }

    // MARK: - Kind inference

    func testKindIsInferredFromTheName() {
        XCTAssertEqual(StoreSearch.inferKind(name: "Costco Wholesale", query: "grocery"), .warehouse)
        XCTAssertEqual(StoreSearch.inferKind(name: "Patel Brothers", query: "grocery"), .indian)
        XCTAssertEqual(StoreSearch.inferKind(name: "Supermercado La Familia", query: "grocery"), .hispanic)
        XCTAssertEqual(StoreSearch.inferKind(name: "H Mart", query: "grocery"), .eastAsian)
        XCTAssertEqual(StoreSearch.inferKind(name: "Stop & Shop Supermarket", query: "supermarket"), .supermarket)
        XCTAssertEqual(StoreSearch.inferKind(name: "Downtown Farmers Market", query: "grocery"), .farmers)
    }

    func testTheSearchThatFoundItAlsoCounts() {
        XCTAssertEqual(StoreSearch.inferKind(name: "Krishna Store", query: "Indian grocery"), .indian)
        XCTAssertEqual(StoreSearch.inferKind(name: "Krishna Store", query: "Asian grocery"), .eastAsian)
    }

    func testSomethingUnrecognisedIsJustAStore() {
        XCTAssertEqual(StoreSearch.inferKind(name: "Corner Deli", query: "shops"), .other)
    }

    func testKindInferenceIgnoresCaseAndAccents() {
        XCTAssertEqual(StoreSearch.inferKind(name: "SUPERMERCADO", query: ""), .hispanic)
        XCTAssertEqual(StoreSearch.inferKind(name: "Carnicería Ríos", query: ""), .hispanic)
    }

    // MARK: - Normalisation

    func testTheSameShopFoundTwiceAppearsOnce() {
        let normalised = StoreSearch.normalise([
            result("Patel Brothers", kind: .other, distance: 900),
            result("patel brothers", kind: .indian, distance: 900),
        ], within: StoreSearch.defaultRadiusMeters)

        XCTAssertEqual(normalised.count, 1)
        XCTAssertEqual(normalised.first?.kind, .indian, "The more specific kind wins.")
    }

    func testShopsBeyondTheRadiusAreDropped() {
        let normalised = StoreSearch.normalise([
            result("Near", address: "1 A St", distance: 2_000),
            result("Far", address: "2 B St", distance: 20_000),
        ], within: StoreSearch.defaultRadiusMeters)
        XCTAssertEqual(normalised.map(\.name), ["Near"])
    }

    func testNearestComesFirstAndUnknownDistancesGoLast() {
        let normalised = StoreSearch.normalise([
            result("Third", address: "3 C St", distance: nil),
            result("Second", address: "2 B St", distance: 3_000),
            result("First", address: "1 A St", distance: 500),
        ], within: StoreSearch.defaultRadiusMeters)
        XCTAssertEqual(normalised.map(\.name), ["First", "Second", "Third"])
    }

    func testNormalisationIsDeterministic() {
        let raw = [
            result("Bravo", address: "2 B St", distance: 1_000),
            result("Alpha", address: "1 A St", distance: 1_000),
        ]
        XCTAssertEqual(StoreSearch.normalise(raw, within: 8_000).map(\.name),
                       StoreSearch.normalise(raw.reversed(), within: 8_000).map(\.name))
    }

    // MARK: - Through the protocol

    func testTheFinderReturnsNormalisedResults() async throws {
        let finder = FakeStoreFinder(results: [
            result("Patel Brothers", kind: .indian, distance: 1_200),
            result("Patel Brothers", kind: .other, distance: 1_200),
            result("Far Away Foods", address: "9 Z St", distance: 40_000),
        ], error: nil)

        let found = try await finder.search(zipCode: "07302")
        XCTAssertEqual(found.map(\.name), ["Patel Brothers"])
        XCTAssertEqual(found.first?.kind, .indian)
    }

    func testAFailedSearchSurfacesAsAnError() async {
        let finder = FakeStoreFinder(results: [], error: FinderFailure())
        do {
            _ = try await finder.search(zipCode: "07302")
            XCTFail("The search should have thrown.")
        } catch {
            XCTAssertTrue(error is FinderFailure)
        }
    }

    func testDefaultsMatchTheSpec() {
        XCTAssertEqual(StoreSearch.defaultRadiusMeters, 8_000)
        XCTAssertEqual(StoreSearch.queries,
                       ["grocery", "supermarket", "Indian grocery", "Spanish grocery", "Asian grocery"])
    }
}
