import SwiftUI
import UIKit

struct ActivityDetailView: View {
    @EnvironmentObject private var store: DunnoStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let activity: DunnoActivity
    var startsNow: Bool = false

    @State private var showingReplaceConfirmation = false
    @State private var showingRemoveConfirmation = false

    private var isCurrent: Bool { store.currentActivityID == activity.id }
    private var isCompleted: Bool { store.isCompleted(activity) }
    private var accent: Color { DunnoTheme.categoryAccent(activity.category) }
    private var textAccent: Color { DunnoTheme.categoryTextAccent(activity.category, scheme: colorScheme) }

    var body: some View {
        NavigationStack {
            ZStack {
                DunnoBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 25) {
                        if isCurrent {
                            currentStatus
                                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        }

                        hero
                        descriptionBlock
                        metadata
                        steps
                        tags
                    }
                    .padding(.horizontal, 21)
                    .padding(.top, 12)
                    .padding(.bottom, 112)
                }
            }
            .navigationTitle(activity.category.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    trailingToolbar
                }
            }
            .safeAreaInset(edge: .bottom) {
                primaryAction
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
        }
        .animation(reduceMotion ? nil : DunnoMotion.snappy, value: isCurrent)
        .animation(reduceMotion ? nil : DunnoMotion.snappy, value: isCompleted)
        .alert("Switch what you're doing?", isPresented: $showingReplaceConfirmation) {
            Button("Keep current", role: .cancel) { }
            Button("Switch to this") {
                store.beginCurrentActivity(activity)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                dismiss()
            }
        } message: {
            if let current = store.currentActivity {
                Text("You're already doing “\(current.title)”. Switching won't mark it done.")
            }
        }
        .alert("Remove from Did It?", isPresented: $showingRemoveConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                store.removeCompleted(activity)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                dismiss()
            }
        } message: {
            Text("This only removes the completion from your history. The idea can be suggested again.")
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                DunnoArtworkIcon(
                    systemName: activity.category.symbol,
                    size: 52,
                    fallbackColor: accent
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(activity.category.rawValue.lowercased())
                        .font(Font.dunno(10, weight: .bold))
                        .tracking(0.35)
                        .foregroundStyle(textAccent)

                    Text(isCurrent ? "doing now" : isCompleted ? "in did it" : "an idea for you")
                        .font(Font.dunno(12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(activity.title)
                    .font(Font.dunnoRounded(32, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                    .tracking(-0.45)
                    .fixedSize(horizontal: false, vertical: true)

                Text(activity.hook)
                    .font(Font.dunno(17, weight: .medium))
                    .foregroundStyle(DunnoTheme.secondaryText(for: colorScheme))
                    .lineSpacing(2.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var descriptionBlock: some View {
        Text(activity.description)
            .font(Font.dunno(16, weight: .medium))
            .foregroundStyle(DunnoTheme.secondaryText(for: colorScheme))
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var metadata: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                infoBox("time", value: activity.durationLabel, icon: "clock")
                infoBox("energy", value: activity.energy.shortLabel, icon: activity.energy.symbol)
            }

            VStack(spacing: 10) {
                infoBox("time", value: activity.durationLabel, icon: "clock")
                infoBox("energy", value: activity.energy.shortLabel, icon: activity.energy.symbol)
            }
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 17) {
            DunnoSectionHeader(title: "try it like this")

            VStack(spacing: 0) {
                ForEach(activity.steps.indices, id: \.self) { index in
                    let step = activity.steps[index]

                    HStack(alignment: .top, spacing: 14) {
                        Text("\(index + 1)")
                            .font(Font.dunno(11, weight: .bold))
                            .foregroundStyle(textAccent)
                            .frame(width: 27, height: 27)
                            .background(accent.opacity(0.10), in: Circle())

                        Text(step)
                            .font(Font.dunno(15, weight: .medium))
                            .lineSpacing(2)
                            .padding(.top, 3)

                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 13)

                    if index != activity.steps.indices.last {
                        Divider()
                            .opacity(0.55)
                            .padding(.leading, 41)
                    }
                }
            }
        }
        .padding(18)
        .dunnoSolidPanel(cornerRadius: 24, accent: accent)
    }

    private var tags: some View {
        FlowLayout(spacing: 8) {
            ForEach(activity.tags.prefix(5), id: \.self) { tag in
                Text(tag)
                    .font(Font.dunno(11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 11)
                    .frame(minHeight: 31)
                    .background(Color.primary.opacity(colorScheme == .dark ? 0.055 : 0.045), in: Capsule())
            }
        }
    }

    @ViewBuilder
    private var trailingToolbar: some View {
        if isCurrent {
            EmptyView()
        } else if isCompleted {
            Button(role: .destructive) {
                showingRemoveConfirmation = true
            } label: {
                Image(systemName: "trash")
            }
            .accessibilityLabel("Remove from Did It")
        } else {
            Menu {
                Button {
                    store.toggleSaved(activity)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Label(
                        store.isSaved(activity) ? "remove from saved" : "save for later",
                        systemImage: store.isSaved(activity) ? "bookmark.slash" : "bookmark"
                    )
                }

                Button {
                    store.complete(activity)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    dismiss()
                } label: {
                    Label("already did this", systemImage: "checkmark.circle")
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .accessibilityLabel("More options")
        }
    }

    private var currentStatus: some View {
        HStack(spacing: 12) {
            Image(systemName: "play.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DunnoTheme.tealText(for: colorScheme))
                .frame(width: 32, height: 32)
                .background(Color.dunnoTeal.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(startsNow ? "alright. this is the one." : "doing now")
                    .font(Font.dunnoRounded(14, weight: .bold))
                Text(startsNow ? "Dunno will keep it close until you're done." : "Your current pick is waiting in the tab bar.")
                    .font(Font.dunno(12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            Button {
                store.cancelCurrentActivity()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel doing now")
            .accessibilityHint("Stops this activity without adding it to Did It.")
        }
        .padding(14)
        .dunnoGlassPanel(cornerRadius: 20, tint: Color.dunnoTeal.opacity(0.07))
    }

    @ViewBuilder
    private var primaryAction: some View {
        if isCurrent {
            Button {
                store.complete(activity)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
            } label: {
                Label("i'm done", systemImage: "checkmark")
            }
            .buttonStyle(DunnoPrimaryButtonStyle())
        } else if isCompleted {
            Button {
                requestStart()
            } label: {
                Label("do again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(DunnoPrimaryButtonStyle())
        } else {
            Button {
                requestStart()
            } label: {
                Label("do this", systemImage: "play.fill")
            }
            .buttonStyle(DunnoPrimaryButtonStyle())
        }
    }

    private func requestStart() {
        if let current = store.currentActivity, current.id != activity.id {
            showingReplaceConfirmation = true
            return
        }

        store.beginCurrentActivity(activity)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }

    private func infoBox(_ title: String, value: String, icon: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 30, height: 30)
                .background(accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Font.dunno(10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(Font.dunno(14, weight: .semibold))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            }

            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity)
        .background(DunnoTheme.elevatedSurface(for: colorScheme), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.055), lineWidth: 0.75)
        }
    }
}
