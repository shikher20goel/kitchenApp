import SwiftData
import SwiftUI

/// Light, dark, or whatever the phone is doing (SPEC §3).
struct AppearanceView: View {
    @Environment(\.modelContext) private var context
    @State private var settings: AppSettings

    init(context: ModelContext) {
        _settings = State(initialValue: AppSettings.current(in: context))
    }

    var body: some View {
        Form {
            Picker("Appearance", selection: Binding(
                get: { settings.appearance },
                set: { settings.appearance = $0; try? context.save() }
            )) {
                ForEach(Appearance.allCases, id: \.self) { appearance in
                    Text(appearance.label).tag(appearance)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
        .navigationTitle("Appearance")
    }
}

/// Hands the household a JSON copy of everything they have put in (SPEC §4.5).
struct ExportView: View {
    @Environment(\.modelContext) private var context
    @State private var fileURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                Text(AppCopy.exportNote)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }

            Section {
                if let fileURL {
                    ShareLink(item: fileURL) {
                        Label("Share the file", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity, minHeight: Theme.largeTapTarget)
                    }
                    .accessibilityIdentifier("export.share")
                } else {
                    Button {
                        prepare()
                    } label: {
                        Label("Prepare export", systemImage: "doc.badge.gearshape")
                            .frame(maxWidth: .infinity, minHeight: Theme.largeTapTarget)
                    }
                    .accessibilityIdentifier("export.prepare")
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.circle")
                        .foregroundStyle(Theme.terracotta)
                }
            }
        }
        .navigationTitle("Export")
    }

    private func prepare() {
        do {
            fileURL = try Exporter.writeTemporaryFile(in: context)
            Haptics.success()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
