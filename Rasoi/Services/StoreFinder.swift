import CoreLocation
import Foundation
import MapKit

/// One shop Apple Maps knows about. Nothing here is saved until the household taps Add.
struct StoreSearchResult: Hashable, Identifiable, Sendable {
    var id: String { "\(Ingredient.fold(name))|\(Ingredient.fold(address))" }
    var name: String
    var address: String
    var kind: StoreKind
    var latitude: Double
    var longitude: Double
    /// Metres from the searched zip code, when it could be worked out.
    var distanceMeters: Double?
}

/// Finds shops near a zip code.
///
/// This protocol is the ONLY network-capable seam in Rasoi (SPEC R1): the MapKit implementation
/// below sends a search string and a coordinate derived from the household's zip code to Apple,
/// and only when someone taps "Find nearby". Tests use a fake and never touch the network.
protocol StoreFinding: Sendable {
    func search(zipCode: String, radiusMeters: Double) async throws -> [StoreSearchResult]
}

extension StoreFinding {
    func search(zipCode: String) async throws -> [StoreSearchResult] {
        try await search(zipCode: zipCode, radiusMeters: StoreSearch.defaultRadiusMeters)
    }
}

/// The pure parts of a store search: what is asked for, what a result is called, and which of
/// them are worth showing. Kept out of the MapKit type so they can be tested without a network.
enum StoreSearch {
    /// 8 km — a sensible weekly-shop radius (SPEC §4.5).
    static let defaultRadiusMeters: Double = 8_000

    /// The searches run for one zip code.
    static let queries = ["grocery", "supermarket", "Indian grocery", "Spanish grocery", "Asian grocery"]

    /// Name fragments that tell us what kind of shop something is. Nothing here is about food the
    /// household eats — it only decides which aisle list a shop is assumed to carry.
    static let kindKeywords: [(StoreKind, [String])] = [
        (.warehouse, ["costco", "bj's", "bjs", "sam's club", "sams club", "warehouse"]),
        (.indian, ["indian", "patel", "desi", "spice bazaar", "india", "punjab", "masala"]),
        (.hispanic, ["spanish", "latino", "latina", "bodega", "supermercado", "mexican", "carniceria"]),
        (.eastAsian, ["asian", "chinese", "h mart", "hmart", "korean", "japanese", "oriental"]),
        (.farmers, ["farmers market", "farmer's market", "farm stand"]),
        (.supermarket, ["supermarket", "grocery", "market", "foods"]),
    ]

    /// What kind of shop a result is, guessed from its name and the search that found it.
    static func inferKind(name: String, query: String) -> StoreKind {
        let haystack = Ingredient.fold("\(name) \(query)")
        for (kind, keywords) in kindKeywords where keywords.contains(where: { haystack.contains($0) }) {
            return kind
        }
        return .other
    }

    /// Drops anything too far away, removes duplicates, and puts the nearest first.
    ///
    /// The same shop comes back from several of the searches, so results are keyed by name and
    /// address; the entry with a real distance and the more specific kind wins.
    static func normalise(_ results: [StoreSearchResult], within radiusMeters: Double) -> [StoreSearchResult] {
        var best: [String: StoreSearchResult] = [:]
        for result in results {
            if let distance = result.distanceMeters, distance > radiusMeters { continue }
            guard let existing = best[result.id] else {
                best[result.id] = result
                continue
            }
            var winner = existing
            if existing.kind == .other, result.kind != .other { winner.kind = result.kind }
            if existing.distanceMeters == nil { winner.distanceMeters = result.distanceMeters }
            best[result.id] = winner
        }
        return best.values.sorted { left, right in
            switch (left.distanceMeters, right.distanceMeters) {
            case let (leftDistance?, rightDistance?) where leftDistance != rightDistance:
                return leftDistance < rightDistance
            case (nil, .some):
                return false
            case (.some, nil):
                return true
            default:
                return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
            }
        }
    }
}

/// The real finder: zip code → coordinate → Apple Maps local search.
///
/// What leaves the device, and only when the household taps Find nearby: the zip code (to
/// `CLGeocoder`) and the five search strings above with that coordinate (to `MKLocalSearch`).
/// No household data, no plan, no pantry, nothing about the children. Documented for review in
/// docs/PRIVACY-MAPKIT.md.
struct MapKitStoreFinder: StoreFinding {
    enum FinderError: LocalizedError {
        case zipNotFound(String)

        var errorDescription: String? {
            switch self {
            case .zipNotFound(let zip):
                return "Apple Maps could not place the zip code \(zip)."
            }
        }
    }

    func search(zipCode: String, radiusMeters: Double) async throws -> [StoreSearchResult] {
        let centre = try await coordinate(for: zipCode)
        let region = MKCoordinateRegion(center: centre, latitudinalMeters: radiusMeters * 2,
                                        longitudinalMeters: radiusMeters * 2)
        let origin = CLLocation(latitude: centre.latitude, longitude: centre.longitude)

        var found: [StoreSearchResult] = []
        for query in StoreSearch.queries {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = region
            request.resultTypes = .pointOfInterest

            guard let response = try? await MKLocalSearch(request: request).start() else { continue }
            for item in response.mapItems {
                guard let name = item.name else { continue }
                let placemark = item.placemark
                let location = placemark.location
                found.append(
                    StoreSearchResult(
                        name: name,
                        address: Self.address(for: placemark),
                        kind: StoreSearch.inferKind(name: name, query: query),
                        latitude: placemark.coordinate.latitude,
                        longitude: placemark.coordinate.longitude,
                        distanceMeters: location.map { origin.distance(from: $0) }
                    )
                )
            }
        }
        return StoreSearch.normalise(found, within: radiusMeters)
    }

    private func coordinate(for zipCode: String) async throws -> CLLocationCoordinate2D {
        let placemarks = try await CLGeocoder().geocodeAddressString(zipCode)
        guard let coordinate = placemarks.first?.location?.coordinate else {
            throw FinderError.zipNotFound(zipCode)
        }
        return coordinate
    }

    private static func address(for placemark: MKPlacemark) -> String {
        [placemark.thoroughfare.map { [placemark.subThoroughfare, $0].compactMap { $0 }.joined(separator: " ") },
         placemark.locality,
         placemark.administrativeArea]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}
