import SwiftUI
import UIKit

struct MainTabView: View {
    private enum Tab: Hashable {
        case forYou
        case explore
        case library
        case you
    }

    @EnvironmentObject private var store: DunnoStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var selection: Tab = .forYou
    @State private var accessoryActivity: DunnoActivity?

    @ViewBuilder
    var body: some View {
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
                .padding(.horizontal, 12)
                .padding(.bottom, 56)
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

            ExploreView()
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
                    .frame(width: 34, height: 34)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mark done")
            .accessibilityHint("Marks this activity complete and adds it to Did It.")

            Button(action: cancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
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
                    .frame(width: 34, height: 34)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mark done")

            Button(action: cancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
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
