import SwiftUI

struct AboutDunnoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                DunnoBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        hero
                        privacyCard
                        linksCard
                        makerCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 34)
                }
            }
            .navigationTitle("about dunno")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("done") { dismiss() }
                }
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            DunnoBrandIcon(size: 92)
                .shadow(color: Color.dunnoPurple.opacity(0.12), radius: 22, y: 10)

            DunnoWordmark(height: 30)

            Text("for when you dunno what to do.")
                .font(Font.dunnoRounded(19, weight: .semibold))
                .foregroundStyle(.primary)

            Text("Dunno helps you find something that actually fits the moment, without turning your free time into another thing to optimize.")
                .font(Font.dunno(14, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(DunnoReleaseInfo.versionDisplay)
                .font(Font.dunno(11, weight: .medium))
                .foregroundStyle(DunnoTheme.tertiaryText(for: colorScheme))
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            DunnoSectionHeader(title: "privacy, simply")

            aboutPoint(
                icon: "person.crop.circle.badge.xmark",
                title: "no account",
                text: "You can use Dunno without creating an account or signing in."
            )

            aboutPoint(
                icon: "iphone",
                title: "your dunno stays on your device",
                text: "Your preferences, saved ideas, history, and current activity are stored locally on this device."
            )

            aboutPoint(
                icon: "eye.slash",
                title: "no third-party tracking",
                text: "This release doesn't include advertising or third-party tracking SDKs."
            )

            Link(destination: DunnoReleaseInfo.privacy) {
                Label("read the full privacy policy", systemImage: "arrow.up.right")
                    .font(Font.dunno(13.5, weight: .semibold))
                    .foregroundStyle(DunnoTheme.purpleText(for: colorScheme))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dunnoSolidPanel(cornerRadius: 24, accent: Color.dunnoPurple)
    }

    private var linksCard: some View {
        VStack(spacing: 0) {
            aboutLink("dunno website", icon: "safari", url: DunnoReleaseInfo.website)
            Divider().padding(.leading, 48)
            aboutLink("support", icon: "questionmark.circle", url: DunnoReleaseInfo.support)
            Divider().padding(.leading, 48)
            aboutLink("send feedback", icon: "bubble.left.and.bubble.right", url: DunnoReleaseInfo.feedbackURL)
            Divider().padding(.leading, 48)
            aboutLink("terms of use", icon: "doc.text", url: DunnoReleaseInfo.terms)
        }
        .padding(.horizontal, 4)
        .dunnoSolidPanel(cornerRadius: 24)
    }

    private var makerCard: some View {
        Link(destination: DunnoReleaseInfo.codeArc) {
            HStack(spacing: 13) {
                Image(systemName: "hammer")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.dunnoBlue)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text("made by CodeArc.studio")
                        .font(Font.dunno(14.5, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("clean. modern. reliable.")
                        .font(Font.dunno(11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DunnoTheme.tertiaryText(for: colorScheme))
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(DunnoPressableStyle())
        .dunnoSolidPanel(cornerRadius: 22)
    }

    private func aboutPoint(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.dunnoPurple)
                .frame(width: 28, height: 28)
                .background(Color.dunnoPurple.opacity(0.08), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Font.dunno(13.5, weight: .semibold))

                Text(text)
                    .font(Font.dunno(12.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func aboutLink(_ title: String, icon: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.dunnoBlue)
                    .frame(width: 30)

                Text(title)
                    .font(Font.dunno(14.5, weight: .medium))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DunnoTheme.tertiaryText(for: colorScheme))
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(DunnoPressableStyle())
    }
}

enum DunnoReleaseInfo {
    static let website = URL(string: "https://dunno.codearc.studio")!
    static let privacy = URL(string: "https://dunno.codearc.studio/privacy")!
    static let terms = URL(string: "https://dunno.codearc.studio/terms")!
    static let support = URL(string: "https://dunno.codearc.studio/support")!
    static let codeArc = URL(string: "https://codearc.studio")!

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    static var versionDisplay: String {
        "version \(version) (\(build))"
    }

    static var feedbackURL: URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "contact@codearc.studio"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Dunno feedback — \(version) (\(build))")
        ]
        return components.url ?? URL(string: "mailto:contact@codearc.studio")!
    }
}
