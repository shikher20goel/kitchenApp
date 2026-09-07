import Foundation
import SwiftData

/// Launch arguments the UI tests (and the screenshot run) use to start from a known household.
///
/// None of this changes how the app behaves for a real household: without the flags the app opens
/// its on-disk store and shows onboarding exactly as it ships.
enum UITestSupport {
    /// Use a throw-away in-memory store instead of the real one.
    static var isUITesting: Bool { flag("-uiTesting") }

    /// Skip onboarding and start with the demo household (two adults, two children).
    static var startsWithDemoHousehold: Bool { flag("-uiTestingDemoHousehold") }

    /// Open straight onto one tab, so a test never has to drive the tab bar to reach a screen.
    /// Pass `-uiTestingTab plan` (today, plan, pantry, shop, more).
    static var initialTab: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-uiTestingTab"),
              arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1].lowercased()
    }

    private static func flag(_ name: String) -> Bool {
        ProcessInfo.processInfo.arguments.contains(name)
    }

    /// Fills an empty store with the demo household. Never runs unless the flag is present.
    @MainActor
    static func installDemoHouseholdIfRequested(in context: ModelContext) {
        guard startsWithDemoHousehold else { return }
        let profile = DietProfile.current(in: context)
        guard !profile.hasCompletedOnboarding else { return }

        let family = FamilyViewModel(context: context)
        guard family.members.isEmpty else { return }
        family.addMember(name: "Shikher", dateOfBirth: date(1988, 4, 20), role: .adult)
        family.addMember(name: "Priya", dateOfBirth: date(1990, 11, 3), role: .adult)
        family.addMember(name: "Aarav", dateOfBirth: date(2017, 6, 15), role: .child)
        family.addMember(name: "Ira", dateOfBirth: date(2022, 3, 1), role: .child)

        profile.hasCompletedOnboarding = true
        try? context.save()
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.rasoi.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? .now
    }
}
