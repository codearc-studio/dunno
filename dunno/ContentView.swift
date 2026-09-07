import Foundation
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: DunnoStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mainTabResetID = UUID()

    var body: some View {
        ZStack {
            if store.profile.onboardingComplete {
                MainTabView()
                    .id(mainTabResetID)
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : DunnoMotion.settle, value: store.profile.onboardingComplete)
        .onReceive(NotificationCenter.default.publisher(for: .dunnoOpenForYou)) { _ in
            mainTabResetID = UUID()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DunnoStore(defaults: UserDefaults(suiteName: "preview.dunno")!, runDiagnostics: false))
}
