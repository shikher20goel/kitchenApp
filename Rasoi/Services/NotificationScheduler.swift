import Foundation
import SwiftData
import UserNotifications

/// One local reminder Rasoi wants to deliver.
struct PendingNotification: Equatable, Sendable {
    /// Stable per kind, so rescheduling replaces rather than piling up.
    var id: String
    var kind: ReminderKind
    var title: String
    var body: String
    /// When it fires, as calendar components (weekday for the weekly shop, hour/minute otherwise).
    var trigger: DateComponents
    var repeats: Bool
}

/// The notification centre, behind a protocol so tests never touch the real one.
protocol NotificationScheduling: Sendable {
    func pendingIdentifiers() async -> [String]
    func removePending(identifiers: [String]) async
    func add(_ notification: PendingNotification) async throws
    func requestAuthorization() async -> Bool
}

/// The real centre.
struct SystemNotificationCenter: NotificationScheduling {
    func pendingIdentifiers() async -> [String] {
        await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier)
    }

    func removePending(identifiers: [String]) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func add(_ notification: PendingNotification) async throws {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: notification.trigger,
                                                    repeats: notification.repeats)
        try await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: notification.id, content: content, trigger: trigger)
        )
    }

    func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
    }
}

/// Schedules the three local reminders (SPEC §7).
///
/// Rules that hold whatever the household's settings say: at most one of each kind, nothing inside
/// the quiet window, and the expiring-soon nudge only when something really is about to go. Every
/// decision is made by the pure `notifications(for:)` below, so it can be tested without the
/// system centre.
@MainActor
struct NotificationScheduler {
    /// Nothing is delivered between these hours.
    static let quietStartHour = 21
    static let quietEndHour = 7
    /// A hard cap, so a bug can never bury the household in reminders.
    static let maximumPending = 10

    /// What the scheduler needs to know, as plain values.
    struct Snapshot: Sendable {
        var shoppingEnabled: Bool
        var shoppingTime: DateComponents
        /// Gregorian weekday the shop happens on (1 = Sunday); the reminder is the evening before.
        var shoppingWeekday: Int
        var groceryItemCount: Int
        var groceryStoreCount: Int

        var cookEnabled: Bool
        var cookTime: DateComponents
        var tonightRecipe: String?
        var tonightMinutes: Int
        var tonightServings: Int

        var expiringEnabled: Bool
        var expiringTime: DateComponents
        /// Items expiring today or tomorrow, soonest first.
        var expiringItems: [String]
    }

    private let center: NotificationScheduling
    private let context: ModelContext
    private let now: () -> Date

    init(center: NotificationScheduling = SystemNotificationCenter(),
         context: ModelContext,
         now: @escaping () -> Date = { .now }) {
        self.center = center
        self.context = context
        self.now = now
    }

    /// True when this time of day is inside the quiet window.
    nonisolated static func isQuiet(_ time: DateComponents) -> Bool {
        guard let hour = time.hour else { return false }
        return hour >= quietStartHour || hour < quietEndHour
    }

    /// The reminders that should exist for this state. Pure and deterministic.
    nonisolated static func notifications(for snapshot: Snapshot) -> [PendingNotification] {
        var result: [PendingNotification] = []

        if snapshot.shoppingEnabled, snapshot.groceryItemCount > 0, !isQuiet(snapshot.shoppingTime) {
            // The evening before the shop.
            let eve = ((snapshot.shoppingWeekday - 2 + 7) % 7) + 1
            var trigger = snapshot.shoppingTime
            trigger.weekday = eve
            result.append(
                PendingNotification(
                    id: ReminderKind.shoppingDay.rawValue,
                    kind: .shoppingDay,
                    title: AppCopy.shoppingReminderTitle,
                    body: AppCopy.shoppingReminderBody(items: snapshot.groceryItemCount,
                                                       stores: max(1, snapshot.groceryStoreCount)),
                    trigger: trigger,
                    repeats: true
                )
            )
        }

        if snapshot.cookEnabled, let recipe = snapshot.tonightRecipe, !isQuiet(snapshot.cookTime) {
            result.append(
                PendingNotification(
                    id: ReminderKind.cookTonight.rawValue,
                    kind: .cookTonight,
                    title: AppCopy.cookReminderTitle(recipe: recipe),
                    body: AppCopy.cookReminderBody(minutes: snapshot.tonightMinutes,
                                                   serves: snapshot.tonightServings),
                    trigger: snapshot.cookTime,
                    repeats: false
                )
            )
        }

        if snapshot.expiringEnabled, let first = snapshot.expiringItems.first, !isQuiet(snapshot.expiringTime) {
            result.append(
                PendingNotification(
                    id: ReminderKind.expiringSoon.rawValue,
                    kind: .expiringSoon,
                    title: AppCopy.expiringReminderTitle,
                    body: AppCopy.expiringReminderBody(item: first,
                                                       more: max(0, snapshot.expiringItems.count - 1)),
                    trigger: snapshot.expiringTime,
                    repeats: false
                )
            )
        }

        return Array(result.prefix(maximumPending))
    }

    /// Rebuilds every reminder from the current state. Safe to call as often as you like: the
    /// identifiers are fixed per kind, so nothing is ever scheduled twice.
    func refresh() async {
        let wanted = Self.notifications(for: snapshot())
        await center.removePending(identifiers: ReminderKind.allCases.map(\.rawValue))
        for notification in wanted {
            try? await center.add(notification)
        }
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        await center.requestAuthorization()
    }

    /// Reads the current household state for the scheduler.
    func snapshot() -> Snapshot {
        let settings = AppSettings.current(in: context)
        let profile = DietProfile.current(in: context)
        let today = now()

        let list = GroceryList.list(forWeekContaining: today, in: context)
        let outstanding = list.items.filter { !$0.isChecked }
        let stores = Set(outstanding.compactMap { $0.store?.name })

        let plan = MealPlan.plan(forWeekContaining: today, in: context)
        let dinner = plan.slots(on: today).first { $0.mealType == .dinner && $0.status == .planned }

        let expiring = ((try? context.fetch(FetchDescriptor<PantryItem>())) ?? [])
            .filter { $0.quantity > 0 && $0.isExpiringSoon(on: today, within: 1) }
            .sorted { ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture) }
            .compactMap { $0.ingredient?.name }

        return Snapshot(
            shoppingEnabled: settings.isEnabled(.shoppingDay),
            shoppingTime: settings.shoppingReminderTime,
            shoppingWeekday: profile.shoppingWeekday,
            groceryItemCount: outstanding.count,
            groceryStoreCount: stores.count,
            cookEnabled: settings.isEnabled(.cookTonight),
            cookTime: settings.cookReminderTime,
            tonightRecipe: dinner?.recipe?.title,
            tonightMinutes: dinner?.recipe?.totalMinutes ?? 0,
            tonightServings: dinner?.servings ?? 0,
            expiringEnabled: settings.isEnabled(.expiringSoon),
            expiringTime: settings.expiringSoonReminderTime,
            expiringItems: expiring
        )
    }
}
