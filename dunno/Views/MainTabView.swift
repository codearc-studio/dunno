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
    @State private var selection: Tab = .forYou
    @State private var accessoryActivity: DunnoActivity?

    var body: some View {
        Group {
            if #available(iOS 26.1, *) {
                baseTabView
                    .tabViewBottomAccessory(isEnabled: store.currentActivity != nil) {
                        doingNowAccessory
                    }
            } else {
                baseTabView
                    .tabViewBottomAccessory {
                        doingNowAccessory
                    }
            }
        }
        .sheet(item: $accessoryActivity) { activity in
            ActivityDetailView(activity: activity)
                .environmentObject(store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var baseTabView: some View {
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
        .tint(Color.dunnoPurple)
        .tabBarMinimizeBehavior(.onScrollDown)
    }

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
        Image(selected ? selectedName : unselectedName)
            .renderingMode(.original)
    }
}

private struct DoingNowAccessory: View {
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let activity: DunnoActivity
    let open: () -> Void
    let complete: () -> Void
    let cancel: () -> Void

    private var accent: Color { DunnoTheme.categoryAccent(activity.category) }

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
                DunnoArtworkIcon(
                    systemName: activity.category.symbol,
                    size: 23,
                    fallbackColor: accent
                )

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
                    DunnoArtworkIcon(
                        systemName: activity.category.symbol,
                        size: 30,
                        fallbackColor: accent
                    )

                    VStack(alignment: .leading, spacing: 1) {
                        Text("doing now")
                            .font(Font.dunno(9, weight: .bold))
                            .foregroundStyle(accent)
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
                    .foregroundStyle(Color.dunnoTeal)
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
