import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: DunnoStore
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(DunnoAppearance.storageKey) private var appearanceRawValue = DunnoAppearance.system.rawValue
    @State private var showingEdit = false
    @State private var showingHidden = false
    @State private var showingAbout = false
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            ZStack {
                DunnoBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header

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
                        .accessibilityHint("Opens your Dunno preferences.")

                        appearanceSection
                        behaviorSection

                        profileSection("sounds like you", values: store.profile.roles)
                        profileSection("you're into", values: store.profile.interests)
                        profileSection("dunno should be good at", values: store.profile.goals)

                        appSection
                        supportAndLegalSection
                        dataSection
                        footer
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 15)
                    .padding(.bottom, 30)
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
        .alert("Reset Dunno?", isPresented: $confirmReset) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) { store.resetAll() }
        } message: {
            Text("This clears your preferences, saves, current activity, history, and onboarding choices.")
        }
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
                subtitle: "Keep Dunno in light or dark mode, or let your iPhone decide."
            )

            Picker("appearance", selection: $appearanceRawValue) {
                ForEach(DunnoAppearance.allCases) { appearance in
                    Text(appearance.title).tag(appearance.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .tint(DunnoTheme.selectedControlFill(for: colorScheme))
            .accessibilityHint("Changes Dunno's appearance across the entire app.")
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dunnoSolidPanel(cornerRadius: 23, accent: Color.dunnoPurple)
    }

    private var behaviorSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            DunnoSectionHeader(title: "suggestions")

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
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dunnoSolidPanel(cornerRadius: 23, accent: Color.dunnoTeal)
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
