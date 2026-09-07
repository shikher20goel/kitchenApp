import SwiftUI

/// A list of short words the household can add to and remove from — likes, dislikes, excluded
/// ingredients. Return adds the typed text; each chip has its own remove button, so nothing needs
/// a swipe or a long press.
struct ChipField: View {
    let title: String
    var placeholder: String = "Add"
    /// Optional type-ahead: the suggestions shown while typing.
    var suggestions: (String) -> [String] = { _ in [] }
    @Binding var values: [String]

    @State private var draft: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            if !values.isEmpty {
                FlowLayout(spacing: Theme.Spacing.s) {
                    ForEach(values, id: \.self) { value in
                        chip(value)
                    }
                }
            }

            HStack(spacing: Theme.Spacing.s) {
                TextField(placeholder, text: $draft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    .onSubmit { commit(draft) }
                    .accessibilityLabel("\(title): add")
                if !draft.isEmpty {
                    Button("Add") { commit(draft) }
                        .buttonStyle(.borderless)
                }
            }

            let matches = suggestions(draft)
            if !matches.isEmpty {
                FlowLayout(spacing: Theme.Spacing.s) {
                    ForEach(matches.prefix(6), id: \.self) { suggestion in
                        Button { commit(suggestion) } label: {
                            Text(suggestion)
                                .font(.footnote)
                                .padding(.horizontal, Theme.Spacing.m)
                                .padding(.vertical, Theme.Spacing.xs)
                                .background(Theme.surfaceElevated, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func chip(_ value: String) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text(value)
            Button {
                values.removeAll { $0 == value }
                Haptics.tap()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(value)")
        }
        .font(.subheadline)
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .background(Theme.saffron.opacity(0.15), in: Capsule())
    }

    private func commit(_ text: String) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        if !values.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) {
            values.append(value)
            Haptics.tap()
        }
        draft = ""
        isFocused = true
    }
}

/// Wraps its children onto as many lines as they need. Used for chips and filter pills.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = layout(subviews: subviews, width: width)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        return CGSize(width: proposal.width ?? rows.map { $0.width }.max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = layout(subviews: subviews, width: bounds.width)
        for row in rows {
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: bounds.minX + item.x, y: bounds.minY + row.y),
                    proposal: ProposedViewSize(item.size)
                )
            }
        }
    }

    private struct Row {
        var y: CGFloat
        var height: CGFloat
        var width: CGFloat
        var items: [(index: Int, x: CGFloat, size: CGSize)]
    }

    private func layout(subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row(y: 0, height: 0, width: 0, items: [])
        var x: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                rows.append(current)
                current = Row(y: current.y + current.height + spacing, height: 0, width: 0, items: [])
                x = 0
            }
            current.items.append((index: index, x: x, size: size))
            current.height = max(current.height, size.height)
            x += size.width + spacing
            current.width = x - spacing
        }
        if !current.items.isEmpty { rows.append(current) }
        return rows
    }
}
