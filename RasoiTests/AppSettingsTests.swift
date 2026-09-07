import SwiftData
import XCTest
@testable import Rasoi

final class AppSettingsTests: XCTestCase {
    @MainActor
    func testDefaultsMatchSpec() throws {
        let stack = try TestContainer.makeStack()
        let settings = AppSettings.current(in: stack.context)

        XCTAssertTrue(settings.notificationsMasterSwitch)
        XCTAssertTrue(settings.shoppingReminderEnabled, "The one reminder that is on by default.")
        XCTAssertEqual(settings.shoppingReminderHour, 18)
        XCTAssertEqual(settings.shoppingReminderMinute, 0)
        XCTAssertFalse(settings.cookReminderEnabled)
        XCTAssertEqual(settings.cookReminderHour, 16)
        XCTAssertEqual(settings.cookReminderMinute, 30)
        XCTAssertFalse(settings.expiringSoonReminderEnabled)
        XCTAssertEqual(settings.appearance, .system)
    }

    @MainActor
    func testCurrentIsIdempotent() throws {
        let stack = try TestContainer.makeStack()
        let first = AppSettings.current(in: stack.context)
        first.cookReminderEnabled = true
        try stack.context.save()

        let second = AppSettings.current(in: stack.context)
        XCTAssertTrue(second.cookReminderEnabled)
        XCTAssertEqual(try stack.context.fetch(FetchDescriptor<AppSettings>()).count, 1)
    }

    @MainActor
    func testAppearanceRoundTrips() throws {
        let stack = try TestContainer.makeStack()
        let settings = AppSettings.current(in: stack.context)
        settings.appearance = .dark
        try stack.context.save()

        let reloaded = try XCTUnwrap(try stack.context.fetch(FetchDescriptor<AppSettings>()).first)
        XCTAssertEqual(reloaded.appearance, .dark)
    }

    @MainActor
    func testReminderTimesAreDateComponents() throws {
        let stack = try TestContainer.makeStack()
        let settings = AppSettings.current(in: stack.context)
        XCTAssertEqual(settings.shoppingReminderTime.hour, 18)
        XCTAssertEqual(settings.cookReminderTime.minute, 30)

        settings.setShoppingReminderTime(hour: 9, minute: 15)
        XCTAssertEqual(settings.shoppingReminderHour, 9)
        XCTAssertEqual(settings.shoppingReminderMinute, 15)
    }

    @MainActor
    func testMasterSwitchOffSilencesEveryReminder() throws {
        let stack = try TestContainer.makeStack()
        let settings = AppSettings.current(in: stack.context)
        settings.cookReminderEnabled = true
        settings.notificationsMasterSwitch = false

        XCTAssertFalse(settings.isEnabled(.shoppingDay))
        XCTAssertFalse(settings.isEnabled(.cookTonight))
        XCTAssertFalse(settings.isEnabled(.expiringSoon))
    }

    @MainActor
    func testIndividualRemindersRespectTheirOwnSwitch() throws {
        let stack = try TestContainer.makeStack()
        let settings = AppSettings.current(in: stack.context)
        XCTAssertTrue(settings.isEnabled(.shoppingDay))
        XCTAssertFalse(settings.isEnabled(.cookTonight))
        settings.cookReminderEnabled = true
        XCTAssertTrue(settings.isEnabled(.cookTonight))
    }
}
