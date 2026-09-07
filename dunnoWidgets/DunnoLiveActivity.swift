import ActivityKit
import SwiftUI
import WidgetKit

struct DunnoLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DunnoActivityAttributes.self) { context in
            DunnoLiveActivityLockScreen(context: context)
                .activityBackgroundTint(DunnoLivePalette.surface)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("dunno.")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    DunnoLiveClock(context: context, compact: false)
                        .frame(maxWidth: 92, alignment: .trailing)
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(displayTimerEnd(context) == nil ? "doing now" : "timer on")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(DunnoLivePalette.secondary)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 10) {
                            DunnoLiveActivityIcon(symbol: displaySymbol(context), size: 32)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(displayTitle(context))
                                    .font(.system(size: 16.5, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.80)
                                    .allowsTightening(true)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                HStack(spacing: 6) {
                                    DunnoLiveChip(symbol: "clock", text: compactDuration(displayDuration(context)))
                                    DunnoLiveChip(text: displayCategory(context).lowercased())
                                }
                            }
                        }
                    }
                    .padding(.top, 2)
                }
            } compactLeading: {
                Text("d")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(DunnoLivePalette.accent)
            } compactTrailing: {
                DunnoLiveClock(context: context, compact: true)
                    .frame(maxWidth: 46, alignment: .trailing)
            } minimal: {
                Text("d")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(DunnoLivePalette.accent)
            }
            .contentMargins(.horizontal, 11, for: .expanded)
            .contentMargins(.vertical, 8, for: .expanded)
            .contentMargins(.horizontal, 4, for: .compactLeading)
            .contentMargins(.horizontal, 4, for: .compactTrailing)
            .contentMargins(.all, 4, for: .minimal)
            .keylineTint(DunnoLivePalette.accent)
        }
    }
}

private struct DunnoLiveActivityLockScreen: View {
    let context: ActivityViewContext<DunnoActivityAttributes>

    var body: some View {
        ZStack {
            DunnoLiveBackdrop()

            VStack(alignment: .leading, spacing: 14) {
                header

                HStack(alignment: .top, spacing: 12) {
                    DunnoLiveActivityIcon(symbol: displaySymbol(context), size: 44)

                    Text(displayTitle(context))
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                        .allowsTightening(true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                footer
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("dunno.")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(displayTimerEnd(context) == nil ? "doing now" : "timer on")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(DunnoLivePalette.accentSoft)
                    .lineLimit(1)
            }

            Spacer(minLength: 10)

            DunnoLiveClock(context: context, compact: false)
                .frame(width: 98, alignment: .trailing)
        }
    }

    private var footer: some View {
        HStack(spacing: 7) {
            DunnoLiveChip(symbol: "clock", text: compactDuration(displayDuration(context)))
            DunnoLiveChip(text: displayCategory(context).lowercased())

            Spacer(minLength: 8)

            HStack(spacing: 5) {
                Text("open")
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .bold))
            }
            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.82))
            .padding(.horizontal, 9)
            .frame(height: 27)
            .background(
                Capsule(style: .continuous)
                    .fill(.white.opacity(0.075))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(.white.opacity(0.085), lineWidth: 0.7)
                    )
            )
        }
    }
}

private struct DunnoLiveBackdrop: View {
    var body: some View {
        ZStack {
            DunnoLivePalette.surface

            LinearGradient(
                colors: [
                    DunnoLivePalette.accent.opacity(0.22),
                    DunnoLivePalette.blue.opacity(0.08),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    DunnoLivePalette.accent.opacity(0.14),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 180
            )
        }
    }
}

private struct DunnoLiveActivityIcon: View {
    let symbol: String
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .fill(.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                        .strokeBorder(.white.opacity(0.09), lineWidth: 0.8)
                )

            Image(systemName: symbol.isEmpty ? "sparkles" : symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(DunnoLivePalette.accentSoft)
        }
        .frame(width: size, height: size)
    }
}

private struct DunnoLiveClock: View {
    let context: ActivityViewContext<DunnoActivityAttributes>
    let compact: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: compact ? 0 : 2) {
            if !compact {
                Text(displayTimerEnd(context) == nil ? "elapsed" : "remaining")
                    .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(DunnoLivePalette.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Group {
                if let end = displayTimerEnd(context) {
                    Text(end, style: .timer)
                } else {
                    Text(context.attributes.startedAt, style: .timer)
                }
            }
            .font(clockFont)
            .foregroundStyle(.white)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.68)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var clockFont: Font {
        .system(size: compact ? 10.5 : 15, weight: .bold, design: .monospaced)
    }
}

private struct DunnoLiveChip: View {
    var symbol: String?
    let text: String

    init(symbol: String? = nil, text: String) {
        self.symbol = symbol
        self.text = text
    }

    var body: some View {
        HStack(spacing: 4) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 8.5, weight: .semibold))
            }
            Text(text)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
        .foregroundStyle(DunnoLivePalette.secondary)
        .padding(.horizontal, 8)
        .frame(height: 25)
        .background(
            Capsule(style: .continuous)
                .fill(.white.opacity(0.055))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(.white.opacity(0.065), lineWidth: 0.7)
                )
        )
    }
}

private func displayTitle(_ context: ActivityViewContext<DunnoActivityAttributes>) -> String {
    context.state.title.isEmpty ? context.attributes.title : context.state.title
}

private func displayCategory(_ context: ActivityViewContext<DunnoActivityAttributes>) -> String {
    context.state.category.isEmpty ? context.attributes.category : context.state.category
}

private func displaySymbol(_ context: ActivityViewContext<DunnoActivityAttributes>) -> String {
    context.state.symbol.isEmpty ? context.attributes.symbol : context.state.symbol
}

private func displayDuration(_ context: ActivityViewContext<DunnoActivityAttributes>) -> String {
    context.state.duration.isEmpty ? context.attributes.duration : context.state.duration
}

private func displayTimerEnd(_ context: ActivityViewContext<DunnoActivityAttributes>) -> Date? {
    context.state.timerEndAt
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

private enum DunnoLivePalette {
    static let accent = Color(red: 138 / 255, green: 108 / 255, blue: 255 / 255)
    static let accentSoft = Color(red: 184 / 255, green: 166 / 255, blue: 255 / 255)
    static let blue = Color(red: 91 / 255, green: 140 / 255, blue: 255 / 255)
    static let surface = Color(red: 12 / 255, green: 13 / 255, blue: 18 / 255).opacity(0.99)
    static let secondary = Color.white.opacity(0.62)
}
