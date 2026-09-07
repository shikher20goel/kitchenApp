import XCTest
@testable import Rasoi

final class AgeBandTests: XCTestCase {
    private func band(bornOn dob: Date, at date: Date) -> AgeBand {
        AgeBand.band(dob: dob, on: date)
    }

    func testYearsCountsCompletedBirthdays() {
        let dob = D.date(2017, 6, 15)
        XCTAssertEqual(AgeBand.years(dob: dob, on: D.date(2017, 6, 15)), 0)
        XCTAssertEqual(AgeBand.years(dob: dob, on: D.date(2018, 6, 14)), 0)
        XCTAssertEqual(AgeBand.years(dob: dob, on: D.date(2018, 6, 15)), 1)
        XCTAssertEqual(AgeBand.years(dob: dob, on: D.date(2026, 6, 14)), 8)
        XCTAssertEqual(AgeBand.years(dob: dob, on: D.date(2026, 6, 15)), 9)
    }

    func testBandBoundariesAtEachBirthday() {
        let dob = D.date(2010, 1, 10)
        // preschool 2–5
        XCTAssertEqual(band(bornOn: dob, at: D.date(2012, 1, 10)), .preschool)
        XCTAssertEqual(band(bornOn: dob, at: D.date(2016, 1, 9)), .preschool)
        // child 6–8
        XCTAssertEqual(band(bornOn: dob, at: D.date(2016, 1, 10)), .child)
        XCTAssertEqual(band(bornOn: dob, at: D.date(2019, 1, 9)), .child)
        // preteen 9–13
        XCTAssertEqual(band(bornOn: dob, at: D.date(2019, 1, 10)), .preteen)
        XCTAssertEqual(band(bornOn: dob, at: D.date(2024, 1, 9)), .preteen)
        // teen 14–18
        XCTAssertEqual(band(bornOn: dob, at: D.date(2024, 1, 10)), .teen)
        XCTAssertEqual(band(bornOn: dob, at: D.date(2029, 1, 9)), .teen)
        // adult 19+
        XCTAssertEqual(band(bornOn: dob, at: D.date(2029, 1, 10)), .adult)
    }

    func testUnderTwoUsesTheYoungestBand() {
        let dob = D.date(2025, 5, 1)
        XCTAssertEqual(band(bornOn: dob, at: D.date(2025, 8, 1)), .preschool)
        XCTAssertEqual(band(bornOn: dob, at: D.date(2026, 5, 1)), .preschool)
    }

    func testLeapDayBirthdayCountsOnMarchFirstInCommonYears() {
        let dob = D.date(2020, 2, 29)
        XCTAssertEqual(AgeBand.years(dob: dob, on: D.date(2021, 2, 28)), 0)
        XCTAssertEqual(AgeBand.years(dob: dob, on: D.date(2021, 3, 1)), 1)
        XCTAssertEqual(AgeBand.years(dob: dob, on: D.date(2024, 2, 29)), 4)
    }

    func testAdultDOBIsAdult() {
        XCTAssertEqual(band(bornOn: D.adultDOB, at: D.date(2026, 9, 6)), .adult)
    }

    func testDemoHouseholdChildren() {
        let today = D.date(2026, 9, 6)
        XCTAssertEqual(band(bornOn: D.youngChildDOB, at: today), .preschool)
        XCTAssertEqual(band(bornOn: D.olderChildDOB, at: today), .preteen)
    }

    func testFutureDateOfBirthIsNeverNegative() {
        XCTAssertEqual(AgeBand.years(dob: D.date(2027, 1, 1), on: D.date(2026, 9, 6)), 0)
    }
}
