import XCTest
@testable import Rasoi

final class UnitsTests: XCTestCase {
    func testMassConversions() {
        XCTAssertEqual(Units.convert(1, from: .kilogram, to: .gram) ?? 0, 1000, accuracy: 0.0001)
        XCTAssertEqual(Units.convert(250, from: .gram, to: .kilogram) ?? 0, 0.25, accuracy: 0.0001)
    }

    func testVolumeConversions() {
        XCTAssertEqual(Units.convert(1, from: .litre, to: .millilitre) ?? 0, 1000, accuracy: 0.0001)
        XCTAssertEqual(Units.convert(1, from: .cup, to: .millilitre) ?? 0, 240, accuracy: 0.0001)
        XCTAssertEqual(Units.convert(1, from: .tablespoon, to: .millilitre) ?? 0, 15, accuracy: 0.0001)
        XCTAssertEqual(Units.convert(1, from: .teaspoon, to: .millilitre) ?? 0, 5, accuracy: 0.0001)
        XCTAssertEqual(Units.convert(480, from: .millilitre, to: .cup) ?? 0, 2, accuracy: 0.0001)
    }

    func testCountsOnlyConvertToThemselves() {
        XCTAssertEqual(Units.convert(3, from: .count, to: .count) ?? 0, 3, accuracy: 0.0001)
        XCTAssertNil(Units.convert(1, from: .bunch, to: .count), "A bunch is not a number of things.")
    }

    func testDimensionsNeverMix() {
        XCTAssertNil(Units.convert(100, from: .gram, to: .millilitre))
        XCTAssertNil(Units.convert(2, from: .count, to: .gram))
    }

    func testAddingAndSubtracting() {
        XCTAssertEqual(Units.add(Quantity(200, .gram), Quantity(1, .kilogram))?.amount ?? 0, 1200, accuracy: 0.0001)
        XCTAssertEqual(Units.subtract(Quantity(1, .kilogram), Quantity(250, .gram))?.amount ?? 0, 0.75, accuracy: 0.0001)
        XCTAssertNil(Units.add(Quantity(200, .gram), Quantity(1, .litre)))
    }

    func testSubtractingMoreThanThereIsFloorsAtZero() {
        XCTAssertEqual(Units.subtract(Quantity(100, .gram), Quantity(1, .kilogram))?.amount ?? -1, 0, accuracy: 0.0001)
    }

    func testSummingGroupsByDimension() {
        let totals = Units.sum([
            Quantity(200, .gram), Quantity(1, .kilogram),
            Quantity(2, .cup), Quantity(100, .millilitre),
            Quantity(3, .count),
        ])
        XCTAssertEqual(totals.count, 3)
        XCTAssertEqual(totals[0].unit, .gram)
        XCTAssertEqual(totals[0].amount, 1200, accuracy: 0.0001)
        XCTAssertEqual(totals[1].unit, .millilitre)
        XCTAssertEqual(totals[1].amount, 580, accuracy: 0.0001)
        XCTAssertEqual(totals[2].unit, .count)
        XCTAssertEqual(totals[2].amount, 3, accuracy: 0.0001)
    }

    func testDisplayReadsLikeAShoppingList() {
        XCTAssertEqual(Units.display(Quantity(1200, .gram)), "1.2 kg")
        XCTAssertEqual(Units.display(Quantity(250, .gram)), "250 g")
        XCTAssertEqual(Units.display(Quantity(1, .litre)), "1 l")
        XCTAssertEqual(Units.display(Quantity(500, .millilitre)), "500 ml")
        XCTAssertEqual(Units.display(Quantity(3, .count)), "×3")
        XCTAssertEqual(Units.display(Quantity(1, .bunch)), "1 bunch")
        XCTAssertEqual(Units.display(Quantity(2, .cup)), "480 ml")
    }
}
