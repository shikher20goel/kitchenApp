import XCTest
@testable import Rasoi

final class ScalingTests: XCTestCase {
    private func line(_ name: String, _ quantity: Double, _ unit: MeasurementUnit) -> RecipeIngredient {
        RecipeIngredient(ingredientName: name, quantity: quantity, unit: unit)
    }

    func testScalingFourServingsToSix() {
        let scaled = Scaling.scale(
            [line("Toor dal", 200, .gram), line("Onion", 2, .count), line("Milk", 600, .millilitre)],
            from: 4, to: 6
        )
        XCTAssertEqual(scaled[0].quantity, 300, accuracy: 0.0001)
        XCTAssertEqual(scaled[1].quantity, 3, accuracy: 0.0001)
        XCTAssertEqual(scaled[2].quantity, 900, accuracy: 0.0001)
    }

    func testCountsRoundToAQuarter() {
        XCTAssertEqual(Scaling.round(1.6667, unit: .count), 1.75, accuracy: 0.0001)
        XCTAssertEqual(Scaling.round(2.1, unit: .count), 2, accuracy: 0.0001)
        XCTAssertEqual(Scaling.round(0.3, unit: .bunch), 0.25, accuracy: 0.0001)
    }

    func testWeightsRoundToFiveGramsOnceTheyAreBigEnough() {
        XCTAssertEqual(Scaling.round(233, unit: .gram), 235, accuracy: 0.0001)
        XCTAssertEqual(Scaling.round(22, unit: .gram), 20, accuracy: 0.0001)
        XCTAssertEqual(Scaling.round(7.4, unit: .gram), 7, accuracy: 0.0001, "Small amounts keep whole grams.")
        XCTAssertEqual(Scaling.round(1.6, unit: .gram), 1.5, accuracy: 0.0001, "A pinch keeps half grams.")
    }

    func testAPinchIsNeverRoundedAway() {
        XCTAssertEqual(Scaling.round(0.2, unit: .gram), 0.5, accuracy: 0.0001)
        XCTAssertEqual(Scaling.round(0.05, unit: .count), 0.25, accuracy: 0.0001)
        XCTAssertEqual(Scaling.round(0, unit: .gram), 0, accuracy: 0.0001, "Nothing stays nothing.")
    }

    func testScalingDownHalvesCleanly() {
        let scaled = Scaling.scale([line("Rice", 400, .gram), line("Egg", 4, .count)], from: 4, to: 2)
        XCTAssertEqual(scaled[0].quantity, 200, accuracy: 0.0001)
        XCTAssertEqual(scaled[1].quantity, 2, accuracy: 0.0001)
    }

    func testSameServingsIsTheIdentity() {
        let original = [line("Rice", 333, .gram)]
        XCTAssertEqual(Scaling.scale(original, from: 4, to: 4).map(\.quantity), [333])
    }

    func testNonsenseServingsAreIgnored() {
        let original = [line("Rice", 200, .gram)]
        XCTAssertEqual(Scaling.scale(original, from: 0, to: 4).map(\.quantity), [200])
        XCTAssertEqual(Scaling.scale(original, from: 4, to: 0).map(\.quantity), [200])
    }

    func testScalingIsDeterministic() {
        let original = [line("Toor dal", 200, .gram), line("Onion", 2, .count)]
        let first = Scaling.scale(original, from: 4, to: 7)
        let second = Scaling.scale(original, from: 4, to: 7)
        XCTAssertEqual(first.map(\.quantity), second.map(\.quantity))
    }

    func testServingOptionsSurroundTheRecipe() {
        XCTAssertEqual(Scaling.servingOptions(around: 4), [2, 3, 4, 5, 6, 7, 8])
        XCTAssertEqual(Scaling.servingOptions(around: 1), [1, 2, 3, 4, 5])
    }
}
