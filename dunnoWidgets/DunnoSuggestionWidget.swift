import SwiftUI
import WidgetKit

nonisolated struct DunnoWidgetEntry: TimelineEntry {
    let date: Date
    let suggestion: DunnoSharedSuggestion?
    let currentActivity: DunnoSharedCurrentActivity?
}

nonisolated struct DunnoWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DunnoWidgetEntry {
        DunnoWidgetEntry(date: Date(), suggestion: .preview, currentActivity: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (DunnoWidgetEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DunnoWidgetEntry>) -> Void) {
        let now = Date()
        completion(
            Timeline(
                entries: [entry(date: now)],
                policy: .after(now.addingTimeInterval(90 * 60))
            )
        )
    }

    private func entry(date: Date = Date()) -> DunnoWidgetEntry {
        DunnoWidgetEntry(
            date: date,
            suggestion: DunnoSharedSystemState.currentSuggestion(),
            currentActivity: DunnoSharedSystemState.currentActivity()
        )
    }
}

struct DunnoSuggestionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: DunnoSharedSystemState.widgetKind, provider: DunnoWidgetProvider()) { entry in
            DunnoWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    DunnoWidgetBackground()
                }
        }
        .configurationDisplayName("dunno?")
        .description("A good thing to do, right when you need one.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

private struct DunnoWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DunnoWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            small
        case .systemMedium:
            medium
        case .accessoryCircular:
            circular
        case .accessoryRectangular:
            rectangular
        default:
            small
        }
    }

    private var small: some View {
        Group {
            if let current = entry.currentActivity {
                VStack(alignment: .leading, spacing: 10) {
                    smallHeader(title: "doing now", symbol: current.activity.symbol)

                    Text(current.activity.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .minimumScaleFactor(0.76)
                        .allowsTightening(true)
                        .layoutPriority(3)

                    Spacer(minLength: 0)

                    HStack(spacing: 7) {
                        widgetCapsule(text: compactDuration(current.activity.duration), symbol: "clock")
                        Spacer(minLength: 4)
                        currentClock(current)
                    }
                }
            } else if let suggestion = entry.suggestion {
                VStack(alignment: .leading, spacing: 10) {
                    smallHeader(title: suggestion.category.lowercased(), symbol: suggestion.symbol)

                    Text(suggestion.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .minimumScaleFactor(0.76)
                        .allowsTightening(true)
                        .layoutPriority(3)

                    Spacer(minLength: 0)

                    HStack(spacing: 7) {
                        widgetCapsule(text: compactDuration(suggestion.duration), symbol: "clock")
                        Spacer(minLength: 4)
                        Button(intent: StartDunnoWidgetIdeaIntent(activityID: suggestion.id)) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(DunnoWidgetPalette.actionGradient))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Do this")
                    }
                }
            } else {
                emptyState
            }
        }
    }

    private var medium: some View {
        Group {
            if let current = entry.currentActivity {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(alignment: .center, spacing: 8) {
                        DunnoWidgetWordmark(style: .auto)
                        statusPill("doing now")
                        Spacer(minLength: 6)
                        activitySymbolBadge(symbol: current.activity.symbol)
                    }

                    Text(current.activity.title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.80)
                        .allowsTightening(true)
                        .layoutPriority(3)

                    HStack(alignment: .bottom, spacing: 10) {
                        HStack(spacing: 6) {
                            widgetCapsule(text: compactDuration(current.activity.duration), symbol: "clock")
                            widgetCapsule(text: current.timerEndAt == nil ? "elapsed" : "timer on", symbol: current.timerEndAt == nil ? "clock.arrow.circlepath" : "timer")
                        }

                        Spacer(minLength: 4)

                        currentClock(current, large: true)
                    }
                }
            } else if let suggestion = entry.suggestion {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 8) {
                        DunnoWidgetWordmark(style: .auto)
                        Spacer(minLength: 6)
                        activitySymbolBadge(symbol: suggestion.symbol)
                    }

                    Text(suggestion.title)
                        .font(.system(size: 19.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.80)
                        .allowsTightening(true)
                        .layoutPriority(4)

                    Text(suggestion.hook)
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)
                        .allowsTightening(true)

                    Spacer(minLength: 0)

                    HStack(spacing: 8) {
                        widgetCapsule(text: compactDuration(suggestion.duration), symbol: "clock")
                        Spacer(minLength: 4)
                        Button(intent: NextDunnoWidgetIdeaIntent()) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("different")
                            }
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10)
                            .frame(height: 31)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(.primary.opacity(0.07))
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .strokeBorder(.primary.opacity(0.08), lineWidth: 0.7)
                                    )
                            )
                        }
                        .buttonStyle(.plain)

                        Button(intent: StartDunnoWidgetIdeaIntent(activityID: suggestion.id)) {
                            HStack(spacing: 5) {
                                Text("do it")
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .frame(height: 31)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(DunnoWidgetPalette.actionGradient)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                emptyState
            }
        }
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            Text("d")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Color.dunnoWidgetAccent)
                .widgetAccentable()
        }
        .accessibilityLabel(entry.currentActivity == nil ? "Dunno, get an idea" : "Dunno, activity in progress")
    }

    private var rectangular: some View {
        Group {
            if let current = entry.currentActivity {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("dunno.")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("doing now")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.dunnoWidgetAccent)
                        Spacer(minLength: 4)
                        currentClock(current, accessory: true)
                    }

                    Text(current.activity.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    HStack(spacing: 5) {
                        Image(systemName: current.activity.symbol)
                            .font(.system(size: 9, weight: .semibold))
                        Text(compactDuration(current.activity.duration))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                }
            } else if let suggestion = entry.suggestion {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("dunno.")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(suggestion.category.lowercased())
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.dunnoWidgetAccent)
                        Spacer(minLength: 4)
                        Text(compactDuration(suggestion.duration))
                            .font(.system(size: 9.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }

                    Text(suggestion.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                }
            } else {
                HStack(spacing: 8) {
                    Text("dunno.")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                    Text("open for ideas")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            DunnoWidgetWordmark(style: .auto)
            Spacer(minLength: 0)
            Text("open dunno once to load your ideas")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .lineLimit(3)
                .minimumScaleFactor(0.82)
        }
    }

    private func smallHeader(title: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("dunno.")
                .font(.system(size: 15.5, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.dunnoWidgetAccent)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if !symbol.isEmpty {
                    Image(systemName: symbol)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Color.dunnoWidgetAccent)
                }
            }
        }
    }

    private func header(title: String, symbol: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            DunnoWidgetWordmark(style: .auto)
            Spacer(minLength: 4)
            statusPill(title)
            if !symbol.isEmpty {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.dunnoWidgetAccent)
            }
        }
    }

    @ViewBuilder
    private func currentClock(
        _ current: DunnoSharedCurrentActivity,
        large: Bool = false,
        accessory: Bool = false
    ) -> some View {
        if let end = current.timerEndAt {
            Text(end, style: .timer)
                .font(clockFont(large: large, accessory: accessory))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        } else {
            Text(current.startedAt, style: .timer)
                .font(clockFont(large: large, accessory: accessory))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func clockFont(large: Bool, accessory: Bool) -> Font {
        if accessory { return .system(size: 10.5, weight: .semibold, design: .monospaced) }
        if large { return .system(size: 18, weight: .bold, design: .monospaced) }
        return .system(size: 11.5, weight: .semibold, design: .monospaced)
    }

    private func widgetCapsule(text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .frame(height: 27)
            .background(
                Capsule(style: .continuous)
                    .fill(.primary.opacity(0.065))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(.primary.opacity(0.075), lineWidth: 0.7)
                    )
            )
    }

    private func statusPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.dunnoWidgetAccent)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.dunnoWidgetAccent.opacity(0.12))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Color.dunnoWidgetAccent.opacity(0.15), lineWidth: 0.7)
                    )
            )
    }

    private func activitySymbolBadge(symbol: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.dunnoWidgetAccent.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(Color.dunnoWidgetAccent.opacity(0.16), lineWidth: 0.7)
                )

            Image(systemName: symbol.isEmpty ? "sparkles" : symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.dunnoWidgetAccent)
        }
        .frame(width: 34, height: 34)
    }

    private func compactDuration(_ duration: String) -> String {
        var value = duration
            .replacingOccurrences(of: "minutes", with: "min", options: .caseInsensitive)
            .replacingOccurrences(of: "minute", with: "min", options: .caseInsensitive)
            .replacingOccurrences(of: "hours", with: "hr", options: .caseInsensitive)
            .replacingOccurrences(of: "hour", with: "hr", options: .caseInsensitive)
            .replacingOccurrences(of: "about ", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "around ", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " to ", with: "–", options: .caseInsensitive)

        while value.contains("  ") {
            value = value.replacingOccurrences(of: "  ", with: " ")
        }

        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct DunnoWidgetWordmark: View {
    enum Style {
        case auto
        case light
    }

    @Environment(\.colorScheme) private var colorScheme
    let style: Style

    var body: some View {
        Text("dunno.")
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundStyle(foregroundColor)
            .lineLimit(1)
            .accessibilityHidden(true)
    }

    private var foregroundColor: Color {
        switch style {
        case .light:
            return .white
        case .auto:
            return colorScheme == .dark ? .white : .primary
        }
    }
}

private struct DunnoWidgetBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(colorScheme == .dark ? 0x0E0F14 : 0xF8F8FC)

            LinearGradient(
                colors: [
                    Color.dunnoWidgetAccent.opacity(colorScheme == .dark ? 0.20 : 0.13),
                    Color.dunnoWidgetBlue.opacity(colorScheme == .dark ? 0.09 : 0.06),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color.dunnoWidgetAccent.opacity(colorScheme == .dark ? 0.16 : 0.09),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 145
            )
        }
    }
}

private enum DunnoWidgetPalette {
    static let actionGradient = LinearGradient(
        colors: [Color.dunnoWidgetAccent, Color.dunnoWidgetBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

private extension DunnoSharedSuggestion {
    nonisolated static let preview = DunnoSharedSuggestion(
        id: "preview",
        title: "take a 10-minute walk without headphones",
        hook: "just you and whatever's around",
        category: "Active",
        symbol: "figure.walk",
        duration: "10 min"
    )
}

private extension Color {
    static let dunnoWidgetAccent = Color(red: 138 / 255, green: 108 / 255, blue: 255 / 255)
    static let dunnoWidgetBlue = Color(red: 91 / 255, green: 140 / 255, blue: 255 / 255)

    init(_ hex: UInt) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
