import AppIntents
import CoreSpotlight
import Foundation
import SwiftUI

@main
struct dunnoApp: App {
    @StateObject private var store = DunnoStore()
    @StateObject private var nearby = DunnoNearbyService()
    @StateObject private var together = DunnoTogetherCoordinator()
    @StateObject private var sharedWithYou = DunnoSharedWithYouStore()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(DunnoAppearance.storageKey) private var appearanceRawValue = DunnoAppearance.system.rawValue

    init() {
        DunnoAppShortcuts.updateAppShortcutParameters()
        DunnoTipConfiguration.configure()
        DunnoSpotlightIndexer.indexActivitiesIfNeeded(ActivityCatalog.all)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(nearby)
                .environmentObject(together)
                .environmentObject(sharedWithYou)
                .preferredColorScheme(
                    (DunnoAppearance(rawValue: appearanceRawValue) ?? .system).colorScheme
                )
                .onReceive(NotificationCenter.default.publisher(for: .dunnoIntentStateDidChange)) { _ in
                    store.syncCurrentActivityFromPersistence()
                }
                .onReceive(NotificationCenter.default.publisher(for: .dunnoTogetherStartedActivity)) { notification in
                    guard let activityID = notification.userInfo?["activityID"] as? String,
                          let startedAt = notification.userInfo?["startedAt"] as? Date,
                          let activity = store.activity(id: activityID) else { return }
                    if store.currentActivityID != activityID || store.currentActivityStartedAt != startedAt {
                        store.beginCurrentActivity(activity, startedAt: startedAt)
                    }
                }
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    guard let url = activity.webpageURL else { return }
                    handleIncomingURL(url)
                }
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                          let id = DunnoSpotlightIndexer.activityID(from: identifier) else { return }
                    store.presentActivity(id: id)
                }
                .onChange(of: scenePhase) {
                    if scenePhase == .active {
                        store.syncCurrentActivityFromPersistence()
                        store.expireCurrentActivityIfNeeded()
                        store.expireFiltersIfNeeded()
                        nearby.refreshIfAuthorized()
                        sharedWithYou.refresh()
                    }
                }
        }
    }

    private func handleIncomingURL(_ url: URL) {
        if DunnoEventDeepLink.matches(url) {
            store.incomingShare = nil
            store.externalActivity = nil
            NotificationCenter.default.post(name: .dunnoOpenForYou, object: nil)
            return
        }

        store.handleIncomingShareURL(url)
    }

}

private enum DunnoEventDeepLink {
    static let host = "dunno.codearc.studio"
    static let path = "/event/dunno2"

    static func matches(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              url.host?.lowercased() == host else { return false }

        let normalizedPath: String
        if url.path.count > 1, url.path.hasSuffix("/") {
            normalizedPath = String(url.path.dropLast())
        } else {
            normalizedPath = url.path
        }

        return normalizedPath == path
    }
}

extension Notification.Name {
    static let dunnoOpenForYou = Notification.Name("dunno.openForYou")
}
