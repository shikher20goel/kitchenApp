import SwiftData
import SwiftUI

/// The three local reminders (SPEC §7). Off is always one tap away, and the quiet window is
/// stated plainly rather than hidden in a footnote nobody reads.
struct NotificationsSettingsView: View {
    @Environment(\.modelContext) private var context
    @State private var settings: AppSettings
    @State private var authorizationRequested = false

    init(context: ModelContext) {
        _settings = State(initialValue: AppSettings.current(in: context))
    }

    var body: some View {
        Form {
            Section {
                Toggle("Reminders", isOn: Binding(
                    get: { settings.notificationsMasterSwitch },
                    set: { settings.notificationsMasterSwitch = $0; save() }
                ))
            } footer: {
                Text(AppCopy.notificationsFooter)
            }

            Section("Shopping day") {
                Toggle("Remind me the evening before", isOn: Binding(
                    get: { settings.shoppingReminderEnabled },
                    set: { settings.shoppingReminderEnabled = $0; save() }
                ))
                timePicker(hour: settings.shoppingReminderHour, minute: settings.shoppingReminderMinute) {
                    settings.setShoppingReminderTime(hour: $0, minute: $1)
                    save()
                }
            }
            .disabled(!settings.notificationsMasterSwitch)

            Section("Cook tonight") {
                Toggle("Remind me what is for dinner", isOn: Binding(
                    get: { settings.cookReminderEnabled },
                    set: { settings.cookReminderEnabled = $0; save() }
                ))
                timePicker(hour: settings.cookReminderHour, minute: settings.cookReminderMinute) {
                    settings.setCookReminderTime(hour: $0, minute: $1)
                    save()
                }
            }
            .disabled(!settings.notificationsMasterSwitch)

            Section("Use it up") {
                Toggle("Tell me what is about to go", isOn: Binding(
                    get: { settings.expiringSoonReminderEnabled },
                    set: { settings.expiringSoonReminderEnabled = $0; save() }
                ))
                timePicker(hour: settings.expiringSoonReminderHour, minute: settings.expiringSoonReminderMinute) {
                    settings.setExpiringSoonReminderTime(hour: $0, minute: $1)
                    save()
                }
            }
            .disabled(!settings.notificationsMasterSwitch)
        }
        .navigationTitle("Notifications")
        .task {
            guard !authorizationRequested, settings.notificationsMasterSwitch else { return }
            authorizationRequested = true
            _ = await NotificationScheduler(context: context).requestAuthorizationIfNeeded()
            await NotificationScheduler(context: context).refresh()
        }
    }

    private func timePicker(hour: Int, minute: Int, onChange: @escaping (Int, Int) -> Void) -> some View {
        DatePicker(
            "Time",
            selection: Binding(
                get: {
                    Calendar.rasoi.date(from: DateComponents(hour: hour, minute: minute)) ?? .now
                },
                set: { newValue in
                    let components = Calendar.rasoi.dateComponents([.hour, .minute], from: newValue)
                    onChange(components.hour ?? hour, components.minute ?? minute)
                }
            ),
            displayedComponents: .hourAndMinute
        )
    }

    private func save() {
        try? context.save()
        Task { await NotificationScheduler(context: context).refresh() }
    }
}
