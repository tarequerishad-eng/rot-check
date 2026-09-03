import Foundation
import GameKit

/// Two leaderboards, no backend. Configure both in App Store Connect →
/// Game Center with the IDs from `Config`:
///   • endless — Classic, all-time, higher is better
///   • daily   — Recurring, resets every day, higher is better
final class GameCenterManager: NSObject, ObservableObject {
    static let shared = GameCenterManager()

    @Published private(set) var isAuthenticated = false

    private override init() { super.init() }

    /// Call once at launch. Game Center may present its own sign-in sheet.
    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, _ in
            if let vc = viewController, let top = UIKitBridge.topViewController {
                top.present(vc, animated: true)
            }
            self?.isAuthenticated = GKLocalPlayer.local.isAuthenticated
            // We have our own leaderboard button; keep Apple's floating one off.
            GKAccessPoint.shared.isActive = false
        }
    }

    func submit(_ score: Int, mode: Mode) {
        guard isAuthenticated, score > 0 else { return }
        let id = mode == .daily ? Config.leaderboardDaily : Config.leaderboardEndless
        Task {
            try? await GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [id])
        }
    }

    func showLeaderboard(mode: Mode) {
        guard let top = UIKitBridge.topViewController else { return }
        let id = mode == .daily ? Config.leaderboardDaily : Config.leaderboardEndless
        let vc = GKGameCenterViewController(leaderboardID: id, playerScope: .global, timeScope: .allTime)
        vc.gameCenterDelegate = self
        top.present(vc, animated: true)
    }
}

extension GameCenterManager: GKGameCenterControllerDelegate {
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
