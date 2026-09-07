import SwiftUI
import TipKit
import UIKit

struct ProfileView: View {
    @EnvironmentObject private var store: DunnoStore
    @EnvironmentObject private var nearby: DunnoNearbyService
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(DunnoAppearance.storageKey) private var appearanceRawValue = DunnoAppearance.system.rawValue
    @State private var showingEdit = false
    @State private var showingHidden = false
    @State private var showingAbout = false
    @State private var confirmReset = false
    @State private var confirmResetLearning = false

    var body: some View {
        NavigationStack {
            ZStack {
                DunnoBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        fineTuneButton
                        TipView(DunnoSystemSurfacesTip())

                        if usesWideLayout {
                            HStack(alignment: .top, spacing: 16) {
                                VStack(spacing: 16) {
                                    appearanceSection
                                    nearbySection
                                    profileSection("sounds like you", values: store.profile.roles)
                                    profileSection("you're into", values: store.profile.interests)
                                    profileSection("dunno should be good at", values: store.profile.goals)
                                }
                                .frame(maxWidth: .infinity, alignment: .top)

                                VStack(spacing: 16) {
                                    behaviorSection
                                    appSection
                                    supportAndLegalSection
                                    dataSection
                                }
                                .frame(maxWidth: .infinity, alignment: .top)
                            }
                        } else {
                            appearanceSection
                            behaviorSection
                            nearbySection

                            profileSection("sounds like you", values: store.profile.roles)
                            profileSection("you're into", values: store.profile.interests)
                            profileSection("dunno should be good at", values: store.profile.goals)

                            appSection
                            supportAndLegalSection
                            dataSection
                        }

                        footer
                    }
                    .frame(maxWidth: 1040, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 15)
                    .padding(.bottom, 30)
                    .frame(maxWidth: .infinity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showingEdit) {
            PreferenceEditorView()
                .environmentObject(store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingHidden) {
            HiddenSuggestionsView()
                .environmentObject(store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingAbout) {
            AboutDunnoView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .alert("Reset what Dunno learned?", isPresented: $confirmResetLearning) {
            Button("Cancel", role: .cancel) { }
            Button("Reset learned taste", role: .destructive) { store.resetBehaviorLearning() }
        } message: {
            Text("This clears behavior-based learning from starts, saves, completions, and ‘worth it?’ feedback. Your preferences, Saved ideas, Did It history, and hidden suggestions stay put.")
        }
        .alert("Reset Dunno?", isPresented: $confirmReset) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) { store.resetAll() }
        } message: {
            Text("This clears your preferences, saves, current activity, history, and onboarding choices.")
        }
    }

    private var usesWideLayout: Bool {
        horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize
    }

    private var fineTuneButton: some View {
        Button {
            showingEdit = true
        } label: {
            HStack(spacing: 11) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.dunnoPurple)

                Text("fine-tune dunno")
                    .font(Font.dunno(15, weight: .semibold))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DunnoTheme.tertiaryText(for: colorScheme))
            }
            .padding(.horizontal, 15)
            .frame(minHeight: 50)
            .dunnoGlassPanel(cornerRadius: 19, tint: Color.dunnoPurple.opacity(0.035), interactive: true)
        }
        .buttonStyle(DunnoPressableStyle())
        .frame(maxWidth: usesWideLayout ? 520 : .infinity, alignment: .leading)
        .accessibilityHint("Opens your Dunno preferences.")
    }

    private var header: some View {
        HStack(spacing: 16) {
            DunnoBrandIcon(size: 66)
                .shadow(color: Color.dunnoPurple.opacity(0.10), radius: 18, y: 8)

            VStack(alignment: .leading, spacing: 5) {
                Text("you")
                    .font(Font.dunnoRounded(34, weight: .bold))
                    .tracking(-0.45)

                Text("A few broad hints. The moment still comes first.")
                    .font(Font.dunno(13.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineSpacing(1)
            }
        }
    }


    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            DunnoSectionHeader(
                title: "appearance",
                subtitle: "Keep Dunno in light or dark mode, or let your device decide."
            )

            DunnoAppearancePicker(selection: $appearanceRawValue)
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dunnoSolidPanel(cornerRadius: 23, accent: Color.dunnoPurple)
    }

    private var behaviorSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            DunnoSectionHeader(
                title: "suggestions",
                subtitle: "Dunno learns gently from what you start, save, finish, and say was worth it. Normal Not Now swipes still don't train it."
            )

            Toggle(
                isOn: Binding(
                    get: { store.neverRepeatCompleted },
                    set: { store.setNeverRepeatCompleted($0) }
                )
            ) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("never repeat completed ideas")
                        .font(Font.dunno(15, weight: .semibold))

                    Text("Off by default. Anything in Did It stays out of future suggestions when this is on.")
                        .font(Font.dunno(12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.trailing, 8)
            }
            .tint(Color.dunnoPurple)

            if !store.hiddenActivities.isEmpty {
                Divider()

                Button {
                    showingHidden = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.dunnoPurple)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("suggestions you're seeing less of")
                                .font(Font.dunno(14, weight: .semibold))
                                .foregroundStyle(.primary)

                            Text("\(store.hiddenActivities.count) hidden")
                                .font(Font.dunno(11.5, weight: .medium))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DunnoTheme.tertiaryText(for: colorScheme))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(DunnoPressableStyle())
            }

            if !store.behaviorAffinities.isEmpty {
                Divider()

                Button {
                    confirmResetLearning = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.dunnoPurple)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("reset learned taste")
                                .font(Font.dunno(14, weight: .semibold))
                                .foregroundStyle(.primary)

                            Text("keeps your choices, saved ideas, and Did It history")
                                .font(Font.dunno(11.5, weight: .medium))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DunnoTheme.tertiaryText(for: colorScheme))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(DunnoPressableStyle())
            }
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dunnoSolidPanel(cornerRadius: 23, accent: Color.dunnoTeal)
    }

    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: 15) {
            DunnoSectionHeader(
                title: "nearby",
                subtitle: "Optional. Dunno can use your location while the app is open to find real places that fit an idea. Your location is never saved."
            )

            HStack(spacing: 12) {
                Image(systemName: nearby.isEnabled ? "location.fill" : "location")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(nearby.isEnabled ? Color.dunnoTeal : Color.dunnoPurple)
                    .frame(width: 34, height: 34)
                    .background(
                        (nearby.isEnabled ? Color.dunnoTeal : Color.dunnoPurple).opacity(0.09),
                        in: Circle()
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(nearbyStatusTitle)
                        .font(Font.dunno(14.5, weight: .semibold))

                    Text(nearbyStatusSubtitle)
                        .font(Font.dunno(11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
            }

            if nearby.isEnabled && nearby.requiresSettings {
                Button {
                    nearby.openLocationSettings()
                } label: {
                    Label("open settings", systemImage: "gear")
                        .font(Font.dunno(13.5, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 46)
                }
                .buttonStyle(DunnoPressableStyle())
                .dunnoGlassPanel(cornerRadius: 17, tint: Color.dunnoPurple.opacity(0.06), interactive: true)
            } else if nearby.isEnabled && nearby.authorizationStatus == .notDetermined {
                Button {
                    nearby.requestAccessOrRefresh()
                } label: {
                    Label("allow while using dunno", systemImage: "location.fill")
                        .font(Font.dunno(13.5, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 46)
                }
                .buttonStyle(DunnoPressableStyle())
                .dunnoGlassPanel(cornerRadius: 17, tint: Color.dunnoTeal.opacity(0.08), interactive: true)
            }

            Button {
                if nearby.isEnabled {
                    nearby.setEnabled(false)
                } else {
                    nearby.setEnabled(true, requestPermission: true)
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Text(nearby.isEnabled ? "turn off nearby ideas" : "turn on nearby ideas")
                    .font(Font.dunno(12.5, weight: .semibold))
                    .foregroundStyle(nearby.isEnabled ? Color.secondary : DunnoTheme.purpleText(for: colorScheme))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 42)
            }
            .buttonStyle(DunnoPressableStyle())
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dunnoSolidPanel(cornerRadius: 23, accent: Color.dunnoTeal)
    }

    private var nearbyStatusTitle: String {
        if !nearby.isEnabled { return "nearby ideas are off" }
        if nearby.requiresSettings { return "nearby needs location access" }
        if nearby.authorizationStatus == .notDetermined { return "ready when you are" }
        if nearby.isLocating { return "checking what's around you" }
        if nearby.isAuthorized { return "nearby ideas are on" }
        return "nearby isn't available"
    }

    private var nearbyStatusSubtitle: String {
        if !nearby.isEnabled {
            return "Everything still works normally without location."
        }
        if nearby.requiresSettings {
            return "Dunno can't request location again until you change it in Settings."
        }
        if nearby.authorizationStatus == .notDetermined {
            return "Tap below when you want Dunno to check for useful places nearby."
        }
        if nearby.isLocating {
            return "One foreground location check. No background tracking."
        }
        if nearby.isAuthorized {
            return "Only checked while Dunno is open. Coordinates and place results aren't stored in your profile."
        }
        return nearby.lastError ?? "Everything else in Dunno still works normally."
    }

    private func profileSection(_ title: String, values: [String]) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            DunnoSectionHeader(title: title)

            if values.isEmpty {
                Text("nothing selected — that's fine.")
                    .font(Font.dunno(13.5, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: 7) {
                    ForEach(values, id: \.self) { value in
                        Text(value.lowercased())
                            .font(Font.dunno(12.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 11)
                            .frame(minHeight: 34)
                            .background(Color.primary.opacity(0.05), in: Capsule())
                    }
                }
            }
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dunnoSolidPanel(cornerRadius: 23)
    }

    private var appSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DunnoSectionHeader(title: "dunno")

            VStack(spacing: 0) {
                settingsButton("about dunno", icon: "info.circle", tint: .dunnoPurple) {
                    showingAbout = true
                }

                rowDivider

                settingsLink(
                    "visit the website",
                    icon: "safari",
                    tint: .dunnoBlue,
                    destination: DunnoReleaseInfo.website
                )
            }
            .padding(.horizontal, 4)
            .dunnoSolidPanel(cornerRadius: 23)
        }
    }

    private var supportAndLegalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DunnoSectionHeader(title: "help & legal")

            VStack(spacing: 0) {
                settingsLink(
                    "send feedback",
                    icon: "bubble.left.and.bubble.right",
                    tint: .dunnoTeal,
                    destination: DunnoReleaseInfo.feedbackURL
                )

                rowDivider

                settingsLink(
                    "support",
                    icon: "questionmark.circle",
                    tint: .dunnoBlue,
                    destination: DunnoReleaseInfo.support
                )

                rowDivider

                settingsLink(
                    "privacy policy",
                    icon: "hand.raised",
                    tint: .dunnoPurple,
                    destination: DunnoReleaseInfo.privacy
                )

                rowDivider

                settingsLink(
                    "terms of use",
                    icon: "doc.text",
                    tint: .secondary,
                    destination: DunnoReleaseInfo.terms
                )
            }
            .padding(.horizontal, 4)
            .dunnoSolidPanel(cornerRadius: 23)
        }
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DunnoSectionHeader(title: "your data")

            VStack(spacing: 0) {
                settingsButton("redo onboarding", icon: "arrow.counterclockwise", tint: .dunnoBlue) {
                    store.resetOnboarding()
                }

                rowDivider

                settingsButton("reset everything", icon: "trash", tint: .red) {
                    confirmReset = true
                }
            }
            .padding(.horizontal, 4)
            .dunnoSolidPanel(cornerRadius: 23)
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            DunnoWordmark(height: 21)

            Text(DunnoReleaseInfo.versionDisplay)
                .font(Font.dunno(10.5, weight: .medium))
                .foregroundStyle(DunnoTheme.tertiaryText(for: colorScheme))

            Link(destination: DunnoReleaseInfo.codeArc) {
                Text("made by CodeArc.studio")
                    .font(Font.dunno(11.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the CodeArc.studio website.")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }

    private var rowDivider: some View {
        Divider()
            .padding(.leading, 52)
    }

    private func settingsButton(_ title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            settingsRow(title, icon: icon, tint: tint, showsExternalLink: false)
        }
        .buttonStyle(DunnoPressableStyle())
    }

    private func settingsLink(_ title: String, icon: String, tint: Color, destination: URL) -> some View {
        Link(destination: destination) {
            settingsRow(title, icon: icon, tint: tint, showsExternalLink: true)
        }
        .buttonStyle(DunnoPressableStyle())
        .accessibilityHint("Opens in your browser.")
    }

    private func settingsRow(_ title: String, icon: String, tint: Color, showsExternalLink: Bool) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34)

            Text(title)
                .font(Font.dunno(15, weight: .medium))
                .foregroundStyle(.primary)

            Spacer()

            Image(systemName: showsExternalLink ? "arrow.up.right" : "chevron.right")
                .font(.system(size: showsExternalLink ? 10 : 11, weight: .semibold))
                .foregroundStyle(DunnoTheme.tertiaryText(for: colorScheme))
        }
        .padding(.horizontal, 13)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}


private struct DunnoAppearancePicker: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Binding var selection: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 9) {
                ForEach(DunnoAppearance.allCases) { appearance in
                    option(appearance)
                }
            }

            VStack(spacing: 9) {
                ForEach(DunnoAppearance.allCases) { appearance in
                    option(appearance)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Appearance")
    }

    private func option(_ appearance: DunnoAppearance) -> some View {
        let selected = selection == appearance.rawValue

        return Button {
            guard selection != appearance.rawValue else { return }
            withAnimation(reduceMotion ? nil : DunnoMotion.snappy) {
                selection = appearance.rawValue
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 9) {
                appearancePreview(appearance)

                HStack(spacing: 5) {
                    Text(appearance.title)
                        .font(Font.dunno(12, weight: .semibold))
                        .lineLimit(1)

                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(DunnoTheme.purpleText(for: colorScheme))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .foregroundStyle(selected ? Color.primary : Color.secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 106 : 96)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(selected ? Color.dunnoPurple.opacity(colorScheme == .dark ? 0.10 : 0.07) : Color.primary.opacity(0.025))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        selected ? DunnoTheme.purpleText(for: colorScheme).opacity(0.72) : Color.primary.opacity(0.065),
                        lineWidth: selected ? 1.35 : 0.75
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(DunnoPressableStyle())
        .accessibilityLabel(appearance.title)
        .accessibilityValue(selected ? "selected" : "not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint("Changes Dunno's appearance across the entire app.")
    }

    private func appearancePreview(_ appearance: DunnoAppearance) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(previewBackground(appearance))

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.dunnoPurple)
                        .frame(width: 8, height: 8)
                    Capsule()
                        .fill(previewInk(appearance).opacity(0.24))
                        .frame(width: 28, height: 4)
                }

                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(previewSurface(appearance))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(DunnoTheme.primaryGradient)
                            .frame(width: 25, height: 4)
                            .padding(.leading, 7)
                    }
                    .frame(height: 25)
            }
            .padding(8)
        }
        .frame(height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            if appearance == .system {
                GeometryReader { proxy in
                    Rectangle()
                        .fill(Color.black.opacity(0.84))
                        .frame(width: proxy.size.width / 2)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .blendMode(.multiply)
                        .allowsHitTesting(false)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func previewBackground(_ appearance: DunnoAppearance) -> Color {
        switch appearance {
        case .system, .light: Color(hex: 0xF1F2F7)
        case .dark: Color(hex: 0x090A0E)
        }
    }

    private func previewSurface(_ appearance: DunnoAppearance) -> Color {
        switch appearance {
        case .system, .light: Color.white.opacity(0.88)
        case .dark: Color(hex: 0x171A20)
        }
    }

    private func previewInk(_ appearance: DunnoAppearance) -> Color {
        appearance == .dark ? .white : .black
    }
}
