import Foundation

/// Serves the deck in three layers: bundled (always present), cached remote
/// (last good download), live remote (fetched on launch when `Config.deckURL`
/// is set). Content updates ship without an App Store review.
final class DeckLoader: ObservableObject {
    static let shared = DeckLoader()

    @Published private(set) var terms: [Term] = []
    @Published private(set) var version = 0

    private static let cacheName = "deck.json"

    private init() {
        let bundled = Self.loadBundled()
        if let cached = Self.loadCached(), cached.version >= bundled.version, cached.terms.count >= 50 {
            apply(cached)
        } else {
            apply(bundled)
        }
    }

    private func apply(_ file: DeckFile) {
        terms = file.terms
        version = file.version
    }

    // MARK: Bundled

    private static func loadBundled() -> DeckFile {
        guard let url = Bundle.main.url(forResource: "deck", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(DeckFile.self, from: data)
        else {
            assertionFailure("deck.json missing from the bundle — run tools/make-deck.py and add it to the target")
            return DeckFile(version: 0, updated: "", terms: [])
        }
        return file
    }

    // MARK: Cache

    private static var cacheURL: URL? {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(cacheName)
    }

    private static func loadCached() -> DeckFile? {
        guard let url = cacheURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(DeckFile.self, from: data)
    }

    // MARK: Remote

    /// Fetches the remote deck if configured. Only replaces the live deck when
    /// the download is newer and sane — a bad deploy can't empty the game.
    func refresh() async {
        guard let url = Config.deckURL else { return }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 8

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let file = try? JSONDecoder().decode(DeckFile.self, from: data),
              file.terms.count >= 50
        else { return }

        let currentVersion = await MainActor.run { self.version }
        guard file.version > currentVersion else { return }

        if let cache = Self.cacheURL { try? data.write(to: cache, options: .atomic) }
        await MainActor.run { self.apply(file) }
    }
}
