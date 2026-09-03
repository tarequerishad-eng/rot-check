import SwiftUI

@main
@MainActor
struct RotCheckApp: App {
    @StateObject private var model = GameModel()
    @StateObject private var house = HouseAdManager()
    @StateObject private var store = Store.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(model: model, house: house, store: store)
                .preferredColorScheme(.dark)          // the game commits to one world
                .statusBarHidden()
                .task { await bootstrap() }
                .onChange(of: scenePhase) { phase in
                    // Backgrounding must never silently drain the meter.
                    switch phase {
                    case .active:                model.resumeTimer()
                    case .inactive, .background: model.pauseTimer()
                    @unknown default:            break
                    }
                }
        }
    }

    /// Launch sequence. Order matters:
    ///   consent → ads may start · Game Center · remote deck · run-end hooks
    private func bootstrap() async {
        model.adsRemoved = { Store.shared.hasRemovedAds }

        model.onRunEnded = { m in
            GameCenterManager.shared.submit(m.score, mode: m.mode)
            // Apple's tracking prompt after the first completed run — it converts
            // far better once someone has actually played.
            if m.metrics.runs == 1 {
                Task { await ConsentManager.shared.requestTracking() }
            }
        }

        GameCenterManager.shared.authenticate()
        Task { await DeckLoader.shared.refresh() }

        await ConsentManager.shared.gather()
        configureAds()
    }

    private func configureAds() {
        #if canImport(GoogleMobileAds)
        let admob = AdMobManager(house: house)
        model.ads = admob
        if ConsentManager.shared.canRequestAds { admob.start() }
        #else
        model.ads = house
        #endif
    }
}
