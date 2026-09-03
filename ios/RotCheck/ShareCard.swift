import Foundation

/// The share text. The Daily grid is the growth mechanic: it shows how you did
/// without spoiling which cards you saw, so it's safe to post and it invites
/// the reader to beat it.
enum ShareCard {

    /// 🟩 hit · 🟨 High Rot hit · 🟥 miss, five per row.
    static func grid(_ results: [CardResult]) -> String {
        let cells = results.map { r -> String in
            switch r {
            case .hit:     return "🟩"
            case .highHit: return "🟨"
            case .miss:    return "🟥"
            }
        }
        return stride(from: 0, to: cells.count, by: 5)
            .map { cells[$0 ..< min($0 + 5, cells.count)].joined() }
            .joined(separator: "\n")
    }

    static func daily(number: Int, score: Int, results: [CardResult], elapsed: TimeInterval, streak: Int) -> String {
        let hits = results.filter { $0 != .miss }.count
        var lines = [
            "ROT CHECK #\(number) · \(score.formatted())",
            grid(results),
            "\(hits)/\(results.count) · \(clock(elapsed))" + (streak > 1 ? " · 🔥\(streak)" : "")
        ]
        lines.append(Config.shareURL)
        return lines.joined(separator: "\n")
    }

    static func endless(score: Int, rank: String, bestStreak: Int) -> String {
        """
        ROT CHECK — \(score.formatted()) pts
        \(rank) · ×\(max(1, bestStreak)) best streak
        Real slang or AI slop? \(Config.shareURL)
        """
    }

    static func clock(_ t: TimeInterval) -> String {
        let s = Int(t.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
