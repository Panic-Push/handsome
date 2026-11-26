import SwiftUI

@main
struct PenwiseApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HomeView()
                .task {
                    // Purchases first (Premium users never start the ad SDK), then ads.
                    await StoreService.shared.start()
                    await AdsService.shared.start()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                PlanStore.shared.refresh()
                Task { await StoreService.shared.refreshEntitlements() }
            }
        }
    }
}
