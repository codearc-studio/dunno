import SwiftUI

struct ActivityRowView: View {
    let activity: DunnoActivity
    var trailingSystemImage: String? = "chevron.right"

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var accent: Color { DunnoTheme.categoryAccent(activity.category) }
    private var textAccent: Color { DunnoTheme.categoryTextAccent(activity.category, scheme: colorScheme) }

    var body: some View {
        HStack(spacing: 14) {
            DunnoArtworkIcon(
                systemName: activity.category.symbol,
                size: 46,
                fallbackColor: accent
            )
            .frame(width: 50, height: 50)

            textContent

            Spacer(minLength: 6)

            if let trailingSystemImage {
                Image(systemName: trailingSystemImage)
                    .font(.system(size: trailingSystemImage == "chevron.right" ? 12 : 14, weight: .semibold))
                    .foregroundStyle(trailingSystemImage == "chevron.right" ? Color.secondary.opacity(0.58) : accent.opacity(0.82))
                    .frame(width: 24)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(DunnoTheme.elevatedSurface(for: colorScheme))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.065 : 0.055), lineWidth: 0.75)
        }
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(activity.title). \(activity.category.rawValue). \(activity.durationLabel). \(activity.energy.shortLabel) energy.")
        .accessibilityHint("Double tap to open details.")
    }

    private var textContent: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(activity.title)
                .font(Font.dunnoRounded(16, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .multilineTextAlignment(.leading)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    Text(activity.category.rawValue.lowercased())
                        .foregroundStyle(textAccent)

                    Circle()
                        .fill(Color.secondary.opacity(0.35))
                        .frame(width: 2.5, height: 2.5)

                    Label(activity.durationLabel, systemImage: "clock")

                    Circle()
                        .fill(Color.secondary.opacity(0.35))
                        .frame(width: 2.5, height: 2.5)

                    Text(activity.energy.shortLabel)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(activity.category.rawValue.lowercased())
                        .foregroundStyle(textAccent)
                    Text("\(activity.durationLabel) · \(activity.energy.shortLabel) energy")
                }
            }
            .font(Font.dunno(11, weight: .medium))
            .foregroundStyle(.secondary)
        }
    }
}
