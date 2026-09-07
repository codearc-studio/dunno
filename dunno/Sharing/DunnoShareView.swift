import SwiftUI
import UIKit

struct DunnoShareView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var store: DunnoStore
    @EnvironmentObject private var together: DunnoTogetherCoordinator

    let activity: DunnoActivity

    @State private var mode: DunnoShareMode = .share
    @State private var payload: DunnoSharePayload?
    @State private var isPreparing = false
    @State private var sharePlayActivity: DunnoTogetherActivity?

    var body: some View {
        NavigationStack {
            ZStack {
                DunnoBackground()

                ScrollView {
                    VStack(spacing: 22) {
                        modePicker
                            .frame(maxWidth: 620)

                        shareCardPreview
                            .frame(maxWidth: 430)

                        Text(mode == .together
                             ? "send the idea and a link that opens this exact activity in dunno."
                             : "share a dunno card plus a link back to this exact activity.")
                            .font(Font.dunno(12.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 440)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 112)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("close") { dismiss() }
                        .font(Font.dunno(13, weight: .semibold))
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 9) {
                    if mode == .together {
                        Button {
                            startSharePlayPicker()
                        } label: {
                            Label("start together", systemImage: "shareplay")
                                .font(Font.dunnoRounded(14, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 50)
                        }
                        .buttonStyle(DunnoPressableStyle())
                        .dunnoGlassPanel(cornerRadius: 18, tint: Color.dunnoPurple.opacity(0.075), interactive: true)
                    }

                    shareAction
                }
                .frame(maxWidth: 620)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(item: $payload) { payload in
            DunnoSystemShareSheet(items: [payload.image, payload.message, payload.url])
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $sharePlayActivity) { activity in
            DunnoTogetherSharingController(activity: activity)
                .ignoresSafeArea()
        }
        .onChange(of: together.isActive) { _, active in
            if active { dismiss() }
        }
        .animation(reduceMotion ? nil : DunnoMotion.snappy, value: mode)
    }

    private var modePicker: some View {
        HStack(spacing: 10) {
            ForEach(DunnoShareMode.allCases) { option in
                Button {
                    mode = option
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: option.symbol)
                            .font(.system(size: 13, weight: .semibold))
                        Text(option.title)
                            .font(Font.dunno(13, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                        Spacer(minLength: 0)
                        if mode == option {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                        }
                    }
                    .foregroundStyle(mode == option ? DunnoTheme.purpleText(for: colorScheme) : Color.primary)
                    .padding(.horizontal, 13)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(DunnoPressableStyle())
                .dunnoGlassPanel(
                    cornerRadius: 17,
                    tint: mode == option ? Color.dunnoPurple.opacity(0.10) : Color.clear,
                    interactive: true
                )
                .accessibilityValue(mode == option ? "selected" : "not selected")
            }
        }
    }

    private var shareCardPreview: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / DunnoShareCardView.canvasWidth, 1)

            DunnoShareCardView(activity: activity, mode: mode)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(
                    width: DunnoShareCardView.canvasWidth * scale,
                    height: DunnoShareCardView.canvasHeight * scale,
                    alignment: .topLeading
                )
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .aspectRatio(4.0 / 5.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.24 : 0.12), radius: 28, y: 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Share card preview for \(activity.title)")
    }

    private var shareAction: some View {
        Button {
            prepareShare()
        } label: {
            HStack(spacing: 9) {
                if isPreparing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: mode == .together ? "person.2.fill" : "square.and.arrow.up")
                }

                Text(isPreparing ? "getting it ready" : mode.title)
                    .font(Font.dunnoRounded(15, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 58)
        }
        .buttonStyle(DunnoPrimaryButtonStyle())
        .disabled(isPreparing)
    }

    private func startSharePlayPicker() {
        var ids: [String] = [activity.id]
        for suggestion in store.recommendations(filters: DunnoFilters(), limit: 70) where !ids.contains(suggestion.id) {
            ids.append(suggestion.id)
        }
        sharePlayActivity = DunnoTogetherActivity(candidateIDs: ids)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func prepareShare() {
        guard !isPreparing else { return }
        isPreparing = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        Task { @MainActor in
            // Let the pressed state settle before rendering a 4:5 image so sharing never
            // feels like the button itself froze.
            await Task.yield()

            let renderer = ImageRenderer(content: DunnoShareCardView(activity: activity, mode: mode))
            renderer.scale = 2
            renderer.isOpaque = true

            guard let image = renderer.uiImage else {
                isPreparing = false
                return
            }

            payload = DunnoSharePayload(
                image: image,
                message: shareMessage,
                url: DunnoShareLink.url(for: activity, mode: mode)
            )
            isPreparing = false
        }
    }

    private var shareMessage: String {
        switch mode {
        case .share:
            "dunno gave me this: \(activity.title)\n\(activity.hook)"
        case .together:
            "do this with me: \(activity.title)\n\(activity.hook)"
        }
    }
}

private struct DunnoSharePayload: Identifiable {
    let id = UUID()
    let image: UIImage
    let message: String
    let url: URL
}

private struct DunnoSystemShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

private struct DunnoShareCardView: View {
    static let canvasWidth: CGFloat = 540
    static let canvasHeight: CGFloat = 675

    let activity: DunnoActivity
    let mode: DunnoShareMode

    private var accent: Color { DunnoTheme.categoryAccent(activity.category) }

    var body: some View {
        ZStack {
            Color(hex: 0x0A0B10)

            RadialGradient(
                colors: [accent.opacity(0.34), accent.opacity(0.09), .clear],
                center: UnitPoint(x: 0.93, y: 0.05),
                startRadius: 10,
                endRadius: 380
            )

            LinearGradient(
                colors: [Color.dunnoPurple.opacity(0.12), .clear, Color.dunnoBlue.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Text("dunno.")
                        .font(Font.dunnoRounded(24, weight: .bold))
                        .foregroundStyle(.white)

                    Spacer()

                    Text(activity.category.rawValue.lowercased())
                        .font(Font.dunno(11, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(accent)
                        .padding(.horizontal, 12)
                        .frame(height: 31)
                        .background(Color.white.opacity(0.07), in: Capsule())
                }

                Spacer(minLength: 42)

                ZStack {
                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                        .fill(accent.opacity(0.13))
                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                        .stroke(accent.opacity(0.22), lineWidth: 1)
                    Image(systemName: activity.symbol)
                        .font(.system(size: 37, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .frame(width: 78, height: 78)

                Text(mode.cardKicker)
                    .font(Font.dunno(13, weight: .bold))
                    .tracking(0.25)
                    .foregroundStyle(accent)
                    .padding(.top, 28)

                Text(activity.title)
                    .font(Font.dunnoRounded(42, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(4)
                    .minimumScaleFactor(0.72)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)

                Text(activity.hook)
                    .font(Font.dunno(19, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.68))
                    .lineLimit(4)
                    .lineSpacing(3.5)
                    .minimumScaleFactor(0.78)
                    .padding(.top, 16)

                Spacer(minLength: 28)

                HStack(spacing: 10) {
                    shareMetadata(activity.durationLabel, symbol: "clock")
                    shareMetadata(activity.energy.shortLabel, symbol: activity.energy.symbol)
                }

                HStack {
                    Text("dunno.codearc.studio")
                        .font(Font.dunno(12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.46))

                    Spacer()

                    Image(systemName: mode == .together ? "person.2.fill" : "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.46))
                }
                .padding(.top, 30)
            }
            .padding(38)
        }
        .frame(width: Self.canvasWidth, height: Self.canvasHeight)
    }

    private func shareMetadata(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(Font.dunno(12, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.76))
            .padding(.horizontal, 13)
            .frame(height: 36)
            .background(Color.white.opacity(0.075), in: Capsule())
    }
}
