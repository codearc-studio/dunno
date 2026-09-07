import SwiftUI
import UIKit
import StoreKit

struct MainTabView: View {
    private enum Tab: Hashable {
        case forYou
        case explore
        case library
        case you
    }

    @EnvironmentObject private var store: DunnoStore
    @EnvironmentObject private var nearby: DunnoNearbyService
    @EnvironmentObject private var together: DunnoTogetherCoordinator
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.requestReview) private var requestReview
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection: Tab = .forYou
    @State private var accessoryActivity: DunnoActivity?
    @State private var reviewRequestTask: Task<Void, Never>?

    var body: some View {
        Group {
            if #available(iOS 26.1, *) {
                modernTabView
                    .tabViewBottomAccessory(isEnabled: store.currentActivity != nil) {
                        doingNowAccessory
                    }
                    .sheet(item: $accessoryActivity) { activity in
                        activitySheet(activity)
                    }
            } else if #available(iOS 26.0, *) {
                modernTabView
                    .tabViewBottomAccessory {
                        doingNowAccessory
                    }
                    .sheet(item: $accessoryActivity) { activity in
                        activitySheet(activity)
                    }
            } else {
                legacyTabView
                    .sheet(item: $accessoryActivity) { activity in
                        activitySheet(activity)
                    }
            }
        }
        .sheet(item: $store.incomingShare) { incoming in
            ActivityDetailView(activity: incoming.activity, sharedMode: incoming.mode)
                .environmentObject(store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $store.externalActivity) { activity in
            ActivityDetailView(activity: activity)
                .environmentObject(store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: Binding(
            get: { together.isActive },
            set: { if !$0 { together.leave() } }
        )) {
            DunnoTogetherView()
                .environmentObject(store)
                .environmentObject(together)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .overlay(alignment: .bottom) {
            if let activity = store.completionFeedbackActivity {
                CompletionFeedbackCard(activity: activity)
                    .environmentObject(store)
                    .frame(maxWidth: 520)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 72)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(50)
            }
        }
        .animation(reduceMotion ? nil : DunnoMotion.snappy, value: store.completionFeedbackActivityID)
        .onAppear {
            store.syncCurrentActivityFromPersistence()
            store.repairCurrentSystemSurfacesIfNeeded()
            store.updateNearbyAvailability(nearby.availableKinds)
            nearby.refreshIfAuthorized()
            scheduleReviewRequestIfAppropriate()
        }
        .onChange(of: nearby.availableKinds) { _, kinds in
            store.updateNearbyAvailability(kinds)
        }
        .onChange(of: store.reviewRequestPending) { _, _ in scheduleReviewRequestIfAppropriate() }
        .onChange(of: store.completionFeedbackActivityID) { _, _ in scheduleReviewRequestIfAppropriate() }
        .onChange(of: selection) { _, _ in scheduleReviewRequestIfAppropriate() }
        .onChange(of: accessoryActivity?.id) { _, _ in scheduleReviewRequestIfAppropriate() }
        .onChange(of: store.incomingShare?.id) { _, _ in scheduleReviewRequestIfAppropriate() }
        .onChange(of: store.externalActivity?.id) { _, _ in scheduleReviewRequestIfAppropriate() }
        .onChange(of: together.isActive) { _, _ in scheduleReviewRequestIfAppropriate() }
        .onDisappear {
            reviewRequestTask?.cancel()
            reviewRequestTask = nil
        }
    }

    private func scheduleReviewRequestIfAppropriate() {
        reviewRequestTask?.cancel()
        reviewRequestTask = nil

        guard store.reviewRequestPending,
              store.completionFeedbackActivity == nil,
              selection == .forYou,
              accessoryActivity == nil,
              store.incomingShare == nil,
              store.externalActivity == nil,
              !together.isActive else { return }

        reviewRequestTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled,
                  store.reviewRequestPending,
                  store.completionFeedbackActivity == nil,
                  selection == .forYou,
                  accessoryActivity == nil,
                  store.incomingShare == nil,
                  store.externalActivity == nil,
                  !together.isActive else { return }

            store.markReviewRequestAttempted()
            requestReview()
            reviewRequestTask = nil
        }
    }

    @ViewBuilder
    private func activitySheet(_ activity: DunnoActivity) -> some View {
        ActivityDetailView(activity: activity)
            .environmentObject(store)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
    }

    @available(iOS 26.0, *)
    private var modernTabView: some View {
        tabView
            .tabBarMinimizeBehavior(.onScrollDown)
    }

    private var legacyTabView: some View {
        ZStack(alignment: .bottom) {
            tabView

            if let activity = store.currentActivity {
                LegacyDoingNowBar(
                    activity: activity,
                    open: { accessoryActivity = activity },
                    complete: {
                        store.complete(activity)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    },
                    cancel: {
                        store.cancelCurrentActivity()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                )
                .frame(maxWidth: 620)
                .padding(.horizontal, 12)
                .padding(.bottom, 56)
                .frame(maxWidth: .infinity)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(20)
            }
        }
        .animation(DunnoMotion.snappy, value: store.currentActivityID)
    }

    private var tabView: some View {
        TabView(selection: $selection) {
            HomeView(isActive: selection == .forYou)
                .tag(Tab.forYou)
                .tabItem {
                    tabIcon(
                        selected: selection == .forYou,
                        selectedName: "DunnoTabForYou",
                        unselectedName: "DunnoTabForYouUnselected"
                    )
                    Text("for you")
                }

            ExploreView(isActive: selection == .explore)
                .tag(Tab.explore)
                .tabItem {
                    tabIcon(
                        selected: selection == .explore,
                        selectedName: "DunnoTabExplore",
                        unselectedName: "DunnoTabExploreUnselected"
                    )
                    Text("explore")
                }

            SavedView()
                .tag(Tab.library)
                .tabItem {
                    tabIcon(
                        selected: selection == .library,
                        selectedName: "DunnoTabLibrary",
                        unselectedName: "DunnoTabLibraryUnselected"
                    )
                    Text("library")
                }

            ProfileView()
                .tag(Tab.you)
                .tabItem {
                    tabIcon(
                        selected: selection == .you,
                        selectedName: "DunnoTabYou",
                        unselectedName: "DunnoTabYouUnselected"
                    )
                    Text("you")
                }
        }
        .tint(DunnoTheme.purpleText(for: colorScheme))
    }

    @available(iOS 26.0, *)
    @ViewBuilder
    private var doingNowAccessory: some View {
        if let activity = store.currentActivity {
            DoingNowAccessory(
                activity: activity,
                open: { accessoryActivity = activity },
                complete: {
                    store.complete(activity)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                },
                cancel: {
                    store.cancelCurrentActivity()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            )
        }
    }

    @ViewBuilder
    private func tabIcon(selected: Bool, selectedName: String, unselectedName: String) -> some View {
        if selected {
            Image(selectedName)
                .renderingMode(.original)
        } else if colorScheme == .dark {
            Image(unselectedName)
                .renderingMode(.original)
        } else {
            Image(selectedName)
                .renderingMode(.original)
                .saturation(0)
                .brightness(-0.22)
                .opacity(0.62)
        }
    }
}

private struct CompletionFeedbackCard: View {
    @EnvironmentObject private var store: DunnoStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingNote = false

    let activity: DunnoActivity

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("worth it?")
                        .font(Font.dunnoRounded(18, weight: .bold))
                    Text(activity.title)
                        .font(Font.dunno(12.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 6)

                Button { store.dismissCompletionFeedback() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Skip feedback")
            }

            HStack(spacing: 9) {
                feedbackButton("yeah", symbol: "hand.thumbsup.fill", positive: true)
                feedbackButton("not really", symbol: "hand.thumbsdown.fill", positive: false)
            }

            Button {
                showingNote = true
            } label: {
                Label(store.note(for: activity).isEmpty ? "add a private note" : "edit private note", systemImage: "note.text")
                    .font(Font.dunno(12.5, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(15)
        .dunnoGlassPanel(cornerRadius: 22, tint: Color.dunnoPurple.opacity(0.055), interactive: true)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.26 : 0.10), radius: 22, y: 10)
        .accessibilityElement(children: .contain)
        .sheet(isPresented: $showingNote) {
            DunnoActivityNoteEditor(activity: activity, existingNote: store.note(for: activity))
                .environmentObject(store)
                .presentationDetents([.medium, .large])
        }
    }

    private func feedbackButton(_ title: String, symbol: String, positive: Bool) -> some View {
        Button {
            store.submitCompletionFeedback(for: activity, positive: positive)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Label(title, systemImage: symbol)
                .font(Font.dunno(13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 42)
                .foregroundStyle(positive ? DunnoTheme.tealText(for: colorScheme) : DunnoTheme.roseText(for: colorScheme))
                .background(
                    (positive ? Color.dunnoTeal : Color.dunnoRose).opacity(0.09),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
        }
        .buttonStyle(DunnoPressableStyle())
    }
}

@available(iOS 26.0, *)
private struct DoingNowAccessory: View {
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme

    let activity: DunnoActivity
    let open: () -> Void
    let complete: () -> Void
    let cancel: () -> Void

    private var accent: Color { DunnoTheme.categoryAccent(activity.category) }
    private var textAccent: Color { DunnoTheme.categoryTextAccent(activity.category, scheme: colorScheme) }

    var body: some View {
        Group {
            if placement == .inline {
                compactAccessory
            } else {
                expandedAccessory
            }
        }
        .animation(reduceMotion ? nil : DunnoMotion.snappy, value: placement)
    }

    private var compactAccessory: some View {
        Button(action: open) {
            HStack(spacing: 8) {
                DunnoArtworkIcon(systemName: activity.category.symbol, size: 23, fallbackColor: accent)

                Text(activity.title)
                    .font(Font.dunno(12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Doing now, \(activity.title)")
        .accessibilityHint("Double tap to open the activity.")
    }

    private var expandedAccessory: some View {
        HStack(spacing: 10) {
            Button(action: open) {
                HStack(spacing: 10) {
                    DunnoArtworkIcon(systemName: activity.category.symbol, size: 30, fallbackColor: accent)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("doing now")
                            .font(Font.dunno(9, weight: .bold))
                            .foregroundStyle(textAccent)
                            .tracking(0.25)

                        Text(activity.title)
                            .font(Font.dunnoRounded(13, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Doing now, \(activity.title)")
            .accessibilityHint("Double tap to open the activity.")

            Spacer(minLength: 4)

            Button(action: complete) {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DunnoTheme.tealText(for: colorScheme))
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mark done")
            .accessibilityHint("Marks this activity complete and adds it to Did It.")

            Button(action: cancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel doing now")
            .accessibilityHint("Stops the current activity without marking it done.")
        }
        .padding(.horizontal, 10)
    }
}

private struct LegacyDoingNowBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let activity: DunnoActivity
    let open: () -> Void
    let complete: () -> Void
    let cancel: () -> Void

    private var accent: Color { DunnoTheme.categoryAccent(activity.category) }
    private var textAccent: Color { DunnoTheme.categoryTextAccent(activity.category, scheme: colorScheme) }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: open) {
                HStack(spacing: 10) {
                    DunnoArtworkIcon(systemName: activity.category.symbol, size: 30, fallbackColor: accent)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("doing now")
                            .font(Font.dunno(9, weight: .bold))
                            .foregroundStyle(textAccent)
                            .tracking(0.25)

                        Text(activity.title)
                            .font(Font.dunnoRounded(13, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Doing now, \(activity.title)")
            .accessibilityHint("Double tap to open the activity.")

            Spacer(minLength: 4)

            Button(action: complete) {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DunnoTheme.tealText(for: colorScheme))
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mark done")

            Button(action: cancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel doing now")
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 56)
        .dunnoGlassPanel(cornerRadius: 20, tint: accent.opacity(0.05))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.18 : 0.08), radius: 16, y: 8)
    }
}
