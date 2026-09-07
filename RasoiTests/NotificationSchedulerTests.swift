import SwiftData
import XCTest
@testable import Rasoi

final class NotificationSchedulerTests: XCTestCase {

    /// Stands in for `UNUserNotificationCenter`; the suite never schedules a real notification.
    private final class FakeCenter: NotificationScheduling, @unchecked Sendable {
        private(set) var scheduled: [PendingNotification] = []
        private(set) var removedIdentifiers: [[String]] = []
        var authorized = true

        func pendingIdentifiers() async -> [String] { scheduled.map(\.id) }

        func removePending(identifiers: [String]) async {
            removedIdentifiers.append(identifiers)
            scheduled.removeAll { identifiers.contains($0.id) }
        }

        func add(_ notification: PendingNotification) async throws {
            scheduled.append(notification)
        }

        func requestAuthorization() async -> Bool { authorized }
    }

    private func snapshot(
        shoppingEnabled: Bool = true,
        shoppingHour: Int = 18,
        shoppingWeekday: Int = 1,
        items: Int = 12,
        stores: Int = 2,
        cookEnabled: Bool = true,
        cookHour: Int = 16,
        tonight: String? = "Instant Pot Khichdi",
        expiringEnabled: Bool = true,
        expiringHour: Int = 9,
        expiring: [String] = ["Spinach"]
    ) -> NotificationScheduler.Snapshot {
        NotificationScheduler.Snapshot(
            shoppingEnabled: shoppingEnabled,
            shoppingTime: DateComponents(hour: shoppingHour, minute: 0),
            shoppingWeekday: shoppingWeekday,
            groceryItemCount: items,
            groceryStoreCount: stores,
            cookEnabled: cookEnabled,
            cookTime: DateComponents(hour: cookHour, minute: 30),
            tonightRecipe: tonight,
            tonightMinutes: 30,
            tonightServings: 4,
            expiringEnabled: expiringEnabled,
            expiringTime: DateComponents(hour: expiringHour, minute: 0),
            expiringItems: expiring
        )
    }

    // MARK: - What gets scheduled

    func testOneOfEachKindAtMost() {
        let notifications = NotificationScheduler.notifications(for: snapshot())
        XCTAssertEqual(notifications.count, 3)
        XCTAssertEqual(Set(notifications.map(\.kind)).count, 3)
        XCTAssertEqual(Set(notifications.map(\.id)).count, 3)
        XCTAssertLessThanOrEqual(notifications.count, NotificationScheduler.maximumPending)
    }

    func testTheShoppingReminderIsTheEveningBeforeTheShop() {
        // Shopping on Sunday (1) → reminder on Saturday (7).
        let sunday = NotificationScheduler.notifications(for: snapshot(shoppingWeekday: 1))
        XCTAssertEqual(sunday.first { $0.kind == .shoppingDay }?.trigger.weekday, 7)

        // Shopping on Monday (2) → reminder on Sunday (1).
        let monday = NotificationScheduler.notifications(for: snapshot(shoppingWeekday: 2))
        XCTAssertEqual(monday.first { $0.kind == .shoppingDay }?.trigger.weekday, 1)
    }

    func testTheShoppingReminderCountsWhatIsLeftToBuy() {
        let notification = NotificationScheduler.notifications(for: snapshot(items: 12, stores: 2))
            .first { $0.kind == .shoppingDay }
        XCTAssertEqual(notification?.body, "Tomorrow's list has 12 items across 2 stores.")
        XCTAssertTrue(notification?.repeats == true, "The weekly shop repeats.")
    }

    func testNothingToBuyMeansNoShoppingReminder() {
        let notifications = NotificationScheduler.notifications(for: snapshot(items: 0))
        XCTAssertFalse(notifications.contains { $0.kind == .shoppingDay })
    }

    func testTheCookReminderNamesTonightsMeal() {
        let notification = NotificationScheduler.notifications(for: snapshot())
            .first { $0.kind == .cookTonight }
        XCTAssertEqual(notification?.title, "Tonight: Instant Pot Khichdi")
        XCTAssertEqual(notification?.body, "30 minutes, serves 4.")
        XCTAssertFalse(notification?.repeats == true, "Tonight's meal is tonight's only.")
    }

    func testNoDinnerPlannedMeansNoCookReminder() {
        XCTAssertFalse(NotificationScheduler.notifications(for: snapshot(tonight: nil))
            .contains { $0.kind == .cookTonight })
    }

    func testExpiringSoonOnlyWhenSomethingIsExpiring() {
        XCTAssertTrue(NotificationScheduler.notifications(for: snapshot(expiring: ["Spinach"]))
            .contains { $0.kind == .expiringSoon })
        XCTAssertFalse(NotificationScheduler.notifications(for: snapshot(expiring: []))
            .contains { $0.kind == .expiringSoon })
    }

    func testExpiringBodyMentionsTheRest() {
        let one = NotificationScheduler.notifications(for: snapshot(expiring: ["Spinach"]))
            .first { $0.kind == .expiringSoon }
        XCTAssertEqual(one?.body, "The spinach is best used now.")

        let several = NotificationScheduler.notifications(for: snapshot(expiring: ["Spinach", "Milk", "Yogurt"]))
            .first { $0.kind == .expiringSoon }
        XCTAssertEqual(several?.body, "The spinach is best used now, and 2 more things are close behind.")
    }

    // MARK: - Switches and the quiet window

    func testEachSwitchIsRespected() {
        XCTAssertFalse(NotificationScheduler.notifications(for: snapshot(shoppingEnabled: false))
            .contains { $0.kind == .shoppingDay })
        XCTAssertFalse(NotificationScheduler.notifications(for: snapshot(cookEnabled: false))
            .contains { $0.kind == .cookTonight })
        XCTAssertFalse(NotificationScheduler.notifications(for: snapshot(expiringEnabled: false))
            .contains { $0.kind == .expiringSoon })
    }

    func testNothingIsScheduledInsideTheQuietWindow() {
        XCTAssertTrue(NotificationScheduler.isQuiet(DateComponents(hour: 21)))
        XCTAssertTrue(NotificationScheduler.isQuiet(DateComponents(hour: 23)))
        XCTAssertTrue(NotificationScheduler.isQuiet(DateComponents(hour: 6)))
        XCTAssertFalse(NotificationScheduler.isQuiet(DateComponents(hour: 7)))
        XCTAssertFalse(NotificationScheduler.isQuiet(DateComponents(hour: 20)))

        let lateNight = NotificationScheduler.notifications(
            for: snapshot(shoppingHour: 22, cookHour: 23, expiringHour: 5)
        )
        XCTAssertTrue(lateNight.isEmpty, "Rasoi does not wake anyone up.")
    }

    // MARK: - Through the centre

    @MainActor
    func testRefreshSchedulesFromTheStoreAndIsIdempotent() async throws {
        let stack = try TestContainer.makeStack()
        let context = stack.context
        try SeedImporter.reimport(in: context)
        StoreSeeder.seedDefaultsIfEmpty(in: context)
        context.insert(HouseholdMember(name: "Shikher", dateOfBirth: D.adultDOB, role: .adult))
        let settings = AppSettings.current(in: context)
        settings.cookReminderEnabled = true
        settings.expiringSoonReminderEnabled = true

        let today = D.date(2026, 9, 8, hour: 10)
        let plan = MealPlan.plan(forWeekContaining: today, in: context)
        let dinner = MealSlot.slot(in: plan, on: today, mealType: .dinner, in: context)
        dinner.recipe = try XCTUnwrap(try context.fetch(FetchDescriptor<Recipe>()).first { $0.serves(.dinner) })

        let list = GroceryList.list(forWeekContaining: today, in: context)
        let spinach = try XCTUnwrap(Ingredient.named("Spinach", in: context))
        let item = GroceryItem(list: list, ingredient: spinach, quantity: 200, unit: .gram)
        context.insert(item)
        list.items.append(item)
        // Spinach keeps four days, so adding it on the 5th makes it due on the 9th — tomorrow.
        PantryItem.add(spinach, quantity: 100, unit: .gram, location: .fridge,
                       on: D.date(2026, 9, 5), in: context)
        try context.save()

        let center = FakeCenter()
        let scheduler = NotificationScheduler(center: center, context: context, now: { today })

        await scheduler.refresh()
        XCTAssertEqual(center.scheduled.count, 3)

        await scheduler.refresh()
        XCTAssertEqual(center.scheduled.count, 3, "Rescheduling replaces; it never piles up.")
        XCTAssertEqual(Set(center.scheduled.map(\.id)).count, 3)
    }

    @MainActor
    func testTheMasterSwitchSilencesEverything() async throws {
        let stack = try TestContainer.makeStack()
        let context = stack.context
        let settings = AppSettings.current(in: context)
        settings.notificationsMasterSwitch = false
        try context.save()

        let center = FakeCenter()
        let scheduler = NotificationScheduler(center: center, context: context,
                                              now: { D.date(2026, 9, 8, hour: 10) })
        await scheduler.refresh()
        XCTAssertTrue(center.scheduled.isEmpty)
        XCTAssertFalse(center.removedIdentifiers.isEmpty, "Old reminders are cleared out too.")
    }
}
