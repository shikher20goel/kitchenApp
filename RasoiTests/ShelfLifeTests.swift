import XCTest
@testable import Rasoi

final class ShelfLifeTests: XCTestCase {
    private let added = D.date(2026, 9, 1)

    func testFridgeAndPantryUseTheCatalogShelfLife() {
        let fridge = ShelfLife.expiry(shelfLifeDays: 7, addedAt: added, location: .fridge)
        let pantry = ShelfLife.expiry(shelfLifeDays: 7, addedAt: added, location: .pantry)
        XCTAssertEqual(fridge, D.date(2026, 9, 8))
        XCTAssertEqual(pantry, D.date(2026, 9, 8))
    }

    func testFreezerMultipliesShelfLifeBySix() {
        let freezer = ShelfLife.expiry(shelfLifeDays: 10, addedAt: added, location: .freezer)
        XCTAssertEqual(freezer, D.date(2026, 10, 31), "10 days × 6 = 60 days in the freezer.")
        XCTAssertEqual(ShelfLife.freezerMultiplier, 6)
    }

    func testDaysUntilExpiryCountsWholeDays() {
        let today = D.date(2026, 9, 6, hour: 9)
        XCTAssertEqual(ShelfLife.daysUntilExpiry(D.date(2026, 9, 6, hour: 23), on: today), 0)
        XCTAssertEqual(ShelfLife.daysUntilExpiry(D.date(2026, 9, 8, hour: 1), on: today), 2)
        XCTAssertEqual(ShelfLife.daysUntilExpiry(D.date(2026, 9, 4), on: today), -2)
    }

    func testExpiringSoonBoundaryIsTwoDays() {
        let today = D.date(2026, 9, 6, hour: 9)
        XCTAssertTrue(ShelfLife.isExpiringSoon(D.date(2026, 9, 6), on: today), "Expires today.")
        XCTAssertTrue(ShelfLife.isExpiringSoon(D.date(2026, 9, 8), on: today), "Two days out is still soon.")
        XCTAssertFalse(ShelfLife.isExpiringSoon(D.date(2026, 9, 9), on: today), "Three days out is not.")
        XCTAssertTrue(ShelfLife.isExpiringSoon(D.date(2026, 9, 1), on: today), "Already past counts as soon.")
        XCTAssertFalse(ShelfLife.isExpiringSoon(nil, on: today), "No expiry date means nothing to warn about.")
    }

    func testUseItUpWindowIsThreeDaysForThePlanner() {
        let today = D.date(2026, 9, 6, hour: 9)
        XCTAssertTrue(ShelfLife.isExpiringSoon(D.date(2026, 9, 9), on: today, within: ShelfLife.useItUpWindowDays))
        XCTAssertFalse(ShelfLife.isExpiringSoon(D.date(2026, 9, 10), on: today, within: ShelfLife.useItUpWindowDays))
    }

    func testZeroShelfLifeStillExpires() {
        XCTAssertEqual(ShelfLife.expiry(shelfLifeDays: 0, addedAt: added, location: .fridge), added)
    }
}
