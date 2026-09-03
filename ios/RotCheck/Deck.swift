import Foundation

/// One entry in the deck. The content itself lives in `deck.json` (bundled,
/// and optionally refreshed from `Config.deckURL`) so adding a hundred terms
/// is a data change, not a code change.
///
/// JSON shape is deliberately terse — the file is downloaded on launch:
///   { "t": "rizz", "r": true, "k": false, "n": "Charisma, the flirting kind." }
struct Term: Codable, Identifiable, Hashable {
    let text: String
    let isReal: Bool
    /// Genuinely tricky — one letter from something real, or real but obscure.
    /// Rolls much better odds of becoming a High Rot card.
    let tricky: Bool
    let note: String

    var id: String { text }

    enum CodingKeys: String, CodingKey {
        case text = "t", isReal = "r", tricky = "k", note = "n"
    }

    init(_ text: String, real: Bool, tricky: Bool = false, note: String) {
        self.text = text
        self.isReal = real
        self.tricky = tricky
        self.note = note
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text   = try c.decode(String.self, forKey: .text)
        isReal = try c.decode(Bool.self, forKey: .isReal)
        tricky = try c.decodeIfPresent(Bool.self, forKey: .tricky) ?? false
        note   = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
}

/// The on-disk / over-the-wire container.
struct DeckFile: Codable {
    let version: Int
    let updated: String
    let terms: [Term]
}

/// House ad creative. Serves when no network fills, so the deck never shows an
/// empty slot and the full ad experience can be demoed before any network is live.
struct Sponsor: Identifiable, Hashable {
    let id = UUID()
    let brand: String
    let copy: String
    let cta: String
}

enum Deck {
    static let sponsors: [Sponsor] = [
        Sponsor(brand: "GOOBER ENERGY",  copy: "Legally distinct from sleep.",              cta: "GET GOOBED"),
        Sponsor(brand: "ZAPPO WIRELESS", copy: "Unlimited data. Limited patience.",         cta: "SWITCH NOW"),
        Sponsor(brand: "NULLBANK",       copy: "Banking for people who don't read things.", cta: "OPEN ACCOUNT"),
        Sponsor(brand: "PIXLDROP",       copy: "Sneakers that render in under 3 seconds.",  cta: "COP A PAIR"),
        Sponsor(brand: "MOGGLE",         copy: "Language learning. Aggressively.",          cta: "TRY FREE")
    ]

    static let ranks: [(min: Int, name: String)] = [
        (0,     "NPC"),
        (800,   "Certified Yapper"),
        (2000,  "Junior Rizzler"),
        (4000,  "Aura Farmer"),
        (7000,  "Sigma Analyst"),
        (11000, "Chief Brainrot Officer")
    ]

    static func rank(for score: Int) -> String {
        ranks.last(where: { score >= $0.min })?.name ?? ranks[0].name
    }
}
