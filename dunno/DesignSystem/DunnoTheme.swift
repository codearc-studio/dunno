import SwiftUI
import UIKit

extension Color {
    static let dunnoPurple = Color(hex: 0x8A6CFF)
    static let dunnoBlue = Color(hex: 0x5B8CFF)
    static let dunnoTeal = Color(hex: 0x42D6B7)
    static let dunnoCharcoal = Color(hex: 0x111318)
    static let dunnoOffWhite = Color(hex: 0xF5F6F8)
    static let dunnoRose = Color(hex: 0xFF6474)

    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

enum DunnoMotion {
    /// Tiny feedback: button presses, chips, and selection changes.
    static let micro = Animation.spring(duration: 0.20, bounce: 0.05)
    /// Standard interface state changes.
    static let snappy = Animation.spring(duration: 0.30, bounce: 0.08)
    /// Content entering or settling into place.
    static let settle = Animation.spring(duration: 0.42, bounce: 0.06)
    /// Gesture-driven reset. Keeps velocity feeling connected to the finger.
    static let interactive = Animation.interactiveSpring(response: 0.28, dampingFraction: 0.88)
}

struct DunnoTheme {
    static let positiveAction = Color.dunnoTeal
    static let negativeAction = Color.dunnoRose

    // Dunno's brand gradient is intentionally compact and cool. Teal is used as
    // reflected/accent light elsewhere instead of forcing three hues into every surface.
    static let primaryGradient = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: Color(hex: 0x9A7CFF), location: 0.00),
            .init(color: Color(hex: 0x746FFF), location: 0.46),
            .init(color: Color(hex: 0x5E8BFF), location: 1.00)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let buttonGradient = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: Color(hex: 0x9577FF), location: 0.00),
            .init(color: Color(hex: 0x786CFF), location: 0.42),
            .init(color: Color(hex: 0x617FFF), location: 1.00)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let softBrandGradient = LinearGradient(
        colors: [
            Color.dunnoPurple.opacity(0.085),
            Color.dunnoBlue.opacity(0.035),
            Color.clear
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x090A0E) : Color(hex: 0xF5F6F9)
    }

    static func surface(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x121419) : Color(hex: 0xFAFAFC)
    }

    static func elevatedSurface(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x171A20) : Color.white
    }

    static func cardSurface(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x151820) : Color(hex: 0xFFFFFF)
    }

    static func secondaryText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xA7ABB5) : Color(hex: 0x606570)
    }

    static func tertiaryText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x727782) : Color(hex: 0x8B909A)
    }

    static func divider(for scheme: ColorScheme) -> Color {
        Color.primary.opacity(scheme == .dark ? 0.075 : 0.065)
    }

    static func categoryAccent(_ category: DunnoCategory) -> Color {
        switch category {
        case .create: Color(hex: 0x9A7CFF)
        case .tech: Color(hex: 0x6C91FF)
        case .explore: Color(hex: 0x4FD4BD)
        case .learn: Color(hex: 0x8292FF)
        case .relax: Color(hex: 0xA58BFF)
        case .active: Color(hex: 0x48D5A6)
        case .social: Color(hex: 0xF38AA4)
        case .food: Color(hex: 0xF2A767)
        case .play: Color(hex: 0x8979FF)
        case .productive: Color(hex: 0x7E9DBD)
        }
    }

    /// Legacy name kept so older components compile. The current card language is a
    /// restrained neutral surface with a very slight directional light shift.
    static func activityCardGradient(_ category: DunnoCategory, scheme: ColorScheme) -> LinearGradient {
        let base = cardSurface(for: scheme)
        return LinearGradient(
            colors: [
                base,
                scheme == .dark ? Color(hex: 0x12151B) : Color(hex: 0xF9FAFC)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func categoryGradient(_ category: DunnoCategory) -> LinearGradient {
        let accent = categoryAccent(category)
        return LinearGradient(
            colors: [accent.opacity(0.96), accent.opacity(0.72)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func categoryTintSurface(_ category: DunnoCategory, scheme: ColorScheme) -> Color {
        categoryAccent(category).opacity(scheme == .dark ? 0.115 : 0.085)
    }
}

private extension Font.Weight {
    var dunnoUIKitWeight: UIFont.Weight {
        if self == .ultraLight { return .ultraLight }
        if self == .thin { return .thin }
        if self == .light { return .light }
        if self == .medium { return .medium }
        if self == .semibold { return .semibold }
        if self == .bold { return .bold }
        if self == .heavy { return .heavy }
        if self == .black { return .black }
        return .regular
    }
}

private func dunnoUIKitTextStyle(for size: CGFloat) -> UIFont.TextStyle {
    switch size {
    case ...10.5: return .caption2
    case ...12.5: return .caption1
    case ...13.5: return .footnote
    case ...15.5: return .subheadline
    case ...18: return .body
    case ...22: return .title3
    case ...28: return .title2
    case ...33: return .title1
    default: return .largeTitle
    }
}

extension Font {
    // SF Pro is the default voice. Rounded is reserved for expressive titles and key actions.
    // UIFontMetrics keeps Dunno's carefully chosen base sizes while allowing Dynamic Type
    // to scale them with the user's accessibility settings. A generous cap prevents the
    // most expressive display sizes from overwhelming card geometry at AX sizes.
    static func dunno(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let base = UIFont.systemFont(ofSize: size, weight: weight.dunnoUIKitWeight)
        let metrics = UIFontMetrics(forTextStyle: dunnoUIKitTextStyle(for: size))
        let scaled = metrics.scaledFont(for: base, maximumPointSize: max(size * 2.0, size + 8))
        return Font(scaled)
    }

    static func dunnoRounded(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let system = UIFont.systemFont(ofSize: size, weight: weight.dunnoUIKitWeight)
        let descriptor = system.fontDescriptor.withDesign(.rounded) ?? system.fontDescriptor
        let base = UIFont(descriptor: descriptor, size: size)
        let metrics = UIFontMetrics(forTextStyle: dunnoUIKitTextStyle(for: size))
        let scaled = metrics.scaledFont(for: base, maximumPointSize: max(size * 2.0, size + 8))
        return Font(scaled)
    }
}

struct DunnoBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            DunnoTheme.background(for: colorScheme)

            // Two soft pools of reflected brand light give Liquid Glass something to refract
            // without turning the screen itself into a gradient poster.
            RadialGradient(
                colors: [
                    Color.dunnoPurple.opacity(colorScheme == .dark ? 0.065 : 0.038),
                    .clear
                ],
                center: UnitPoint(x: 0.93, y: -0.02),
                startRadius: 0,
                endRadius: 360
            )

        }
        .ignoresSafeArea()
    }
}

private struct DunnoSolidPanelModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let cornerRadius: CGFloat
    let accent: Color?

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(DunnoTheme.elevatedSurface(for: colorScheme))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(colorScheme == .dark ? 0.075 : 0.06), lineWidth: 0.8)
            }
            .overlay(alignment: .topLeading) {
                if let accent {
                    LinearGradient(
                        colors: [
                            accent.opacity(colorScheme == .dark ? 0.32 : 0.22),
                            accent.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 30, height: 1)
                    .padding(.leading, 18)
                    .padding(.top, 9)
                }
            }
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.10 : 0.035),
                radius: 11,
                y: 6
            )
    }
}

private struct DunnoGlassPanelModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    let cornerRadius: CGFloat
    let tint: Color?
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(DunnoTheme.elevatedSurface(for: colorScheme).opacity(0.98))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke((tint ?? Color.primary).opacity(0.11), lineWidth: 0.8)
                }
        } else {
            content
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.primary.opacity(0.012))
                }
                .glassEffect(
                    .regular.tint(tint).interactive(interactive),
                    in: .rect(cornerRadius: cornerRadius)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.primary.opacity(0.055), lineWidth: 0.7)
                }
        }
    }
}

private struct DunnoGlassCapsuleModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    let tint: Color?
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background { Capsule().fill(DunnoTheme.elevatedSurface(for: colorScheme).opacity(0.98)) }
                .overlay { Capsule().stroke((tint ?? Color.primary).opacity(0.10), lineWidth: 0.8) }
        } else {
            content
                .background { Capsule().fill(Color.primary.opacity(0.012)) }
                .glassEffect(
                    .regular.tint(tint).interactive(interactive),
                    in: Capsule()
                )
                .overlay { Capsule().stroke(Color.primary.opacity(0.05), lineWidth: 0.7) }
        }
    }
}

extension View {
    func dunnoSolidPanel(
        cornerRadius: CGFloat = 24,
        accent: Color? = nil
    ) -> some View {
        modifier(DunnoSolidPanelModifier(cornerRadius: cornerRadius, accent: accent))
    }

    func dunnoGlassPanel(
        cornerRadius: CGFloat = 24,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        modifier(DunnoGlassPanelModifier(cornerRadius: cornerRadius, tint: tint, interactive: interactive))
    }

    func dunnoGlassCapsule(
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        modifier(DunnoGlassCapsuleModifier(tint: tint, interactive: interactive))
    }
}

struct DunnoPressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(reduceMotion ? nil : DunnoMotion.micro, value: configuration.isPressed)
    }
}

struct DunnoSectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 4) {
            Text(title.lowercased())
                .font(Font.dunnoRounded(21, weight: .bold))

            if let subtitle {
                Text(subtitle)
                    .font(Font.dunno(13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineSpacing(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

enum DunnoArtwork {
    /// Maps branded concepts to the user's custom artwork. Utility/navigation symbols deliberately
    /// stay native SF Symbols by not routing them through DunnoArtworkIcon.
    static let assetBySystemName: [String: String] = [
        "airplane": "DunnoIconAirplane",
        "arrow.triangle.2.circlepath": "DunnoIconShuffle",
        "book.fill": "DunnoIconBook",
        "bookmark.fill": "DunnoIconBookmark",
        "checkmark.circle.fill": "DunnoIconCheckmarkCircle",
        "chevron.left.forwardslash.chevron.right": "DunnoIconDeveloper",
        "figure.2.and.child.holdinghands": "DunnoIconParent",
        "figure.run": "DunnoIconRun",
        "fork.knife": "DunnoIconFood",
        "gamecontroller.fill": "DunnoIconGameController",
        "graduationcap.fill": "DunnoIconGraduationCap",
        "hammer.fill": "DunnoIconHammer",
        "laptopcomputer": "DunnoIconLaptop",
        "leaf.fill": "DunnoIconLeaf",
        "location.fill": "DunnoIconLocation",
        "moon.stars.fill": "DunnoIconMoonStars",
        "music.note": "DunnoIconMusicNote",
        "paintbrush.fill": "DunnoIconPaintbrush",
        "paintbrush.pointed.fill": "DunnoIconPaintbrushPointed",
        "person.2.fill": "DunnoIconPeople",
        "rectangle.stack.fill": "DunnoIconCardStack",
        "safari.fill": "DunnoIconSafari",
        "slider.horizontal.3": "DunnoIconSliders",
        "sparkles": "DunnoIconSparkles",
        "square.grid.2x2.fill": "DunnoIconGrid",
        "tv.fill": "DunnoIconTV",
        "wand.and.stars": "DunnoIconWand"
    ]

    static func assetName(for systemName: String) -> String? {
        assetBySystemName[systemName]
    }
}

/// Displays Dunno's custom icon artwork when available, with an SF Symbol fallback.
struct DunnoArtworkIcon: View {
    let systemName: String
    var size: CGFloat = 44
    var fallbackColor: Color = .primary
    var fallbackWeight: Font.Weight = .semibold

    var body: some View {
        Group {
            if let assetName = DunnoArtwork.assetName(for: systemName) {
                Image(assetName)
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
            } else {
                Image(systemName: systemName)
                    .font(.system(size: size * 0.46, weight: fallbackWeight))
                    .foregroundStyle(fallbackColor)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct DunnoFeatureIcon: View {
    let systemName: String
    var size: CGFloat = 48

    var body: some View {
        DunnoArtworkIcon(
            systemName: systemName,
            size: size,
            fallbackColor: Color.dunnoPurple,
            fallbackWeight: .bold
        )
        .shadow(color: Color.dunnoBlue.opacity(0.05), radius: size * 0.055, y: size * 0.02)
    }
}

struct DunnoWordmark: View {
    var height: CGFloat = 34

    var body: some View {
        Image("DunnoWordmark")
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .accessibilityLabel("dunno")
    }
}

struct DunnoBrandIcon: View {
    var size: CGFloat = 96

    var body: some View {
        Image("DunnoBrandIcon")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct DunnoPill: View {
    let title: String
    let systemImage: String?
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .semibold))
                }

                Text(title.lowercased())
                    .font(Font.dunno(14, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 14)
            .frame(minHeight: 42)
            .dunnoGlassCapsule(
                tint: isSelected ? Color.dunnoPurple.opacity(0.58) : nil,
                interactive: true
            )
        }
        .buttonStyle(DunnoPressableStyle())
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "selected" : "not selected")
        .accessibilityHint("Double tap to change this choice.")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct DunnoPrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Font.dunnoRounded(17, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 58)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(DunnoTheme.buttonGradient)
                    .opacity(configuration.isPressed ? 0.88 : 1)
            }
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [Color.white.opacity(0.22), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 16)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .allowsHitTesting(false)
            }
            .glassEffect(
                .regular.tint(Color.dunnoPurple.opacity(0.12)).interactive(),
                in: .rect(cornerRadius: 20)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.17), lineWidth: 0.75)
            }
            .shadow(color: Color.dunnoPurple.opacity(0.17), radius: 18, y: 8)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : DunnoMotion.micro, value: configuration.isPressed)
    }
}

/// Utility buttons always use native SF Symbols. Branded artwork is reserved for content/categories.
struct DunnoIconButton: View {
    let systemName: String
    var tint: Color? = nil
    var foreground: Color = .primary
    var size: CGFloat = 46
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: max(14, size * 0.34), weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: size, height: size)
                .dunnoGlassCapsule(tint: tint, interactive: true)
        }
        .buttonStyle(DunnoPressableStyle())
        .accessibilityLabel(systemName)
    }
}
