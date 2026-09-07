import Foundation
import SwiftData
import SwiftUI

/// App-level preferences (SPEC §3). A singleton row, like `DietProfile`.
///
/// Reminder times are stored as hour + minute rather than a `Date` so they mean the same thing
/// after a time-zone change or a device restore.
@Model
final class AppSettings {
    /// One switch that silences everything, whatever the individual toggles say.
    var notificationsMasterSwitch: Bool = true

    var shoppingReminderEnabled: Bool = true
    var shoppingReminderHour: Int = 18
    var shoppingReminderMinute: Int = 0

    var cookReminderEnabled: Bool = false
    var cookReminderHour: Int = 16
    var cookReminderMinute: Int = 30

    var expiringSoonReminderEnabled: Bool = false
    var expiringSoonReminderHour: Int = 9
    var expiringSoonReminderMinute: Int = 0

    var appearanceRaw: String = Appearance.system.rawValue

    init() {}

    @MainActor
    static func current(in context: ModelContext) -> AppSettings {
        var descriptor = FetchDescriptor<AppSettings>()
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let settings = AppSettings()
        context.insert(settings)
        return settings
    }

    var appearance: Appearance {
        get { Appearance(rawValue: appearanceRaw) ?? .system }
        set { appearanceRaw = newValue.rawValue }
    }

    var shoppingReminderTime: DateComponents {
        DateComponents(hour: shoppingReminderHour, minute: shoppingReminderMinute)
    }

    var cookReminderTime: DateComponents {
        DateComponents(hour: cookReminderHour, minute: cookReminderMinute)
    }

    var expiringSoonReminderTime: DateComponents {
        DateComponents(hour: expiringSoonReminderHour, minute: expiringSoonReminderMinute)
    }

    func setShoppingReminderTime(hour: Int, minute: Int) {
        shoppingReminderHour = hour
        shoppingReminderMinute = minute
    }

    func setCookReminderTime(hour: Int, minute: Int) {
        cookReminderHour = hour
        cookReminderMinute = minute
    }

    func setExpiringSoonReminderTime(hour: Int, minute: Int) {
        expiringSoonReminderHour = hour
        expiringSoonReminderMinute = minute
    }

    /// Whether a reminder should be scheduled at all.
    func isEnabled(_ reminder: ReminderKind) -> Bool {
        guard notificationsMasterSwitch else { return false }
        switch reminder {
        case .shoppingDay: return shoppingReminderEnabled
        case .cookTonight: return cookReminderEnabled
        case .expiringSoon: return expiringSoonReminderEnabled
        }
    }

    func time(for reminder: ReminderKind) -> DateComponents {
        switch reminder {
        case .shoppingDay: return shoppingReminderTime
        case .cookTonight: return cookReminderTime
        case .expiringSoon: return expiringSoonReminderTime
        }
    }
}

/// The three local reminders Rasoi can send (SPEC §7). Nothing else ever notifies.
enum ReminderKind: String, CaseIterable, Sendable {
    case shoppingDay
    case cookTonight
    case expiringSoon
}

/// Light, dark or follow the system.
enum Appearance: String, Codable, CaseIterable, Sendable {
    case system
    case light
    case dark

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
