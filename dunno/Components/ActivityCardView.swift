import SwiftUI

/// The primary "Dunno card" used for in-the-moment recommendations.
/// It is intentionally a content surface, not Liquid Glass. Brand color appears as reflected light.
struct ActivityCardView: View {
    let activity: DunnoActivity
    var compact = false
    var showsContent = true

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var cornerRadius: CGFloat { compact ? 25 : 32 }
    private var accent: Color { DunnoTheme.categoryAccent(activity.category) }
    private var usesAccessibilityLayout: Bool { dynamicTypeSize.isAccessibilitySize }
    private var cardMinHeight: CGFloat {
        if compact { return usesAccessibilityLayout ? 286 : 218 }
        return usesAccessibilityLayout ? 510 : 382
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            cardBackground

            if showsContent {
                content
            }
        }
        .frame(maxWidth: .infinity, minHeight: cardMinHeight, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.085 : 0.065), lineWidth: 0.8)
        }
        .overlay(alignment: .top) {
            // A restrained top-edge catch light: enough depth to feel physical without
            // reading like a decorative stripe across the card.
            LinearGradient(
                colors: [Color.white.opacity(colorScheme == .dark ? 0.038 : 0.22), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: compact ? 26 : 34)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .allowsHitTesting(false)
        }
        .shadow(
            color: Color.black.opacity(showsContent ? (colorScheme == .dark ? 0.22 : 0.07) : (colorScheme == .dark ? 0.12 : 0.035)),
            radius: compact ? 12 : (showsContent ? 18 : 11),
            y: compact ? 6 : (showsContent ? 10 : 6)
        )
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(!showsContent)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double tap to open details. Use not now or do it to choose what happens next.")
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            categoryHeader

            Spacer(minLength: compact ? 20 : 32)

            VStack(alignment: .leading, spacing: compact ? 8 : 11) {
                Text(activity.title)
                    .font(Font.dunnoRounded(compact ? 23 : 32, weight: .bold))
                    .foregroundStyle(.primary)
                    // Activity titles are content, not labels. Never truncate them —
                    // long ideas should use the empty vertical space in the card instead.
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(2)
                    .tracking(-0.35)

                Text(activity.hook)
                    .font(Font.dunno(compact ? 14 : 15.5, weight: .medium))
                    .foregroundStyle(DunnoTheme.secondaryText(for: colorScheme))
                    .lineSpacing(2.5)
                    // Keep the supporting thought complete too. Spacers collapse before
                    // either text block, so the card stays balanced without ellipses.
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
            }

            Spacer(minLength: compact ? 20 : 30)

            metadataRow
        }
        .padding(compact ? 19 : 23)
    }

    private var categoryHeader: some View {
        HStack(spacing: 11) {
            DunnoArtworkIcon(
                systemName: activity.category.symbol,
                size: compact ? 42 : 48,
                fallbackColor: accent
            )
            .shadow(color: accent.opacity(0.08), radius: 8, y: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.category.rawValue.lowercased())
                    .font(Font.dunno(10, weight: .bold))
                    .tracking(0.35)
                    .foregroundStyle(accent)

                if !compact {
                    Text("for right now")
                        .font(Font.dunno(12, weight: .medium))
                        .foregroundStyle(DunnoTheme.tertiaryText(for: colorScheme))
                }
            }

            Spacer(minLength: 46)
        }
    }

    private var metadataRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                metadata(activity.durationLabel, systemImage: "clock")

                Circle()
                    .fill(Color.primary.opacity(0.20))
                    .frame(width: 3, height: 3)

                metadata(activity.energy.shortLabel, systemImage: activity.energy.symbol)

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 7) {
                metadata(activity.durationLabel, systemImage: "clock")
                metadata("\(activity.energy.shortLabel) energy", systemImage: activity.energy.symbol)
            }
        }
    }

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(DunnoTheme.cardSurface(for: colorScheme))

            if showsContent {
                // RadialGradient gives the same soft category reflection as a blurred
                // circle without forcing an offscreen blur pass while the card moves.
                RadialGradient(
                    colors: [
                        accent.opacity(colorScheme == .dark ? 0.12 : 0.065),
                        accent.opacity(colorScheme == .dark ? 0.035 : 0.018),
                        .clear
                    ],
                    center: UnitPoint(x: 0.98, y: 0.02),
                    startRadius: 0,
                    endRadius: compact ? 150 : 245
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        }
    }

    private var accessibilityLabel: String {
        "\(activity.title). \(activity.hook). \(activity.category.rawValue). \(activity.durationLabel). \(activity.energy.shortLabel) energy."
    }

    private func metadata(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(Font.dunno(compact ? 11.5 : 12.5, weight: .semibold))
            .foregroundStyle(DunnoTheme.secondaryText(for: colorScheme))
    }
}
