import SwiftUI
import UIKit
import Combine

// MARK: - Types

enum Mode { case endless, daily }
enum Phase { case title, playing, over }

/// Ad units the game asks for. The manager decides who fills them.
enum AdSlot { case interstitial, rewarded }

/// One judged card, for the Daily Rot result grid.
enum CardResult: Int, Codable {
    case miss = 0, hit = 1, highHit = 2
}

/// A card as it appears in the stack: a term to judge, or a paid slot.
struct PlayCard: Identifiable, Equatable {
    let id = UUID()
    let term: Term?
    let sponsor: Sponsor?
    let isHighRot: Bool

    var isSponsor: Bool { sponsor != nil }
    static func == (a: PlayCard, b: PlayCard) -> Bool { a.id == b.id }
}

/// Deterministic RNG so everyone gets the same Daily Rot from the same date.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - Model

final class GameModel: ObservableObject {

    // MARK: Tuning — same numbers as the web build
    private let startMeter: Double  = 100
    private let drainBase: Double   = 7.5   // percent per second at level 1
    private let rewardTime: Double  = 11    // percent returned per correct card
    private let penalty: Double     = 22    // percent lost on a miss
    private let adGap: ClosedRange<Int> = 5...8
    private let hardChance: Double  = 0.08  // ordinary card promoted to High Rot
    private let hardTricky: Double  = 0.45  // a deck-flagged tricky term
    private let hardBonus: Int      = 3     // score multiplier on High Rot
    private let hardRisk: Double    = 1.5   // penalty multiplier if you blow one
    private let dailyCount          = 20

    // MARK: Published state
    @Published private(set) var phase: Phase = .title
    @Published private(set) var mode: Mode = .endless
    @Published private(set) var stack: [PlayCard] = []      // last element is on top
    @Published private(set) var score = 0
    @Published private(set) var streak = 0
    @Published private(set) var multiplier = 1
    @Published private(set) var meter: Double = 100
    @Published private(set) var bestStreak = 0
    @Published private(set) var highRotHits = 0
    @Published private(set) var cardsJudged = 0
    @Published private(set) var accuracy = 0
    @Published private(set) var didRevive = false
    @Published private(set) var didDouble = false
    @Published var scorePop: String? = nil                  // floating "+900"
    @Published private(set) var isSponsorTop = false
    @Published private(set) var best: Int

    // Daily Rot
    @Published private(set) var dailyResults: [CardResult] = []
    @Published private(set) var dailyElapsed: TimeInterval = 0
    @Published private(set) var daily: DailyRecord

    /// Persisted outcome of the most recent Daily Rot.
    struct DailyRecord: Codable {
        var date = ""               // "yyyy-MM-dd", local
        var number = 0
        var score = 0
        var results: [CardResult] = []
        var elapsed: Double = 0
        var streak = 0
        var best = 0

        static func load() -> DailyRecord {
            guard let d = UserDefaults.standard.data(forKey: "daily"),
                  let r = try? JSONDecoder().decode(DailyRecord.self, from: d) else { return DailyRecord() }
            return r
        }
        func save() {
            if let d = try? JSONEncoder().encode(self) { UserDefaults.standard.set(d, forKey: "daily") }
        }
    }

    // MARK: Advertiser-facing counters
    @Published private(set) var metrics: Metrics

    struct Metrics: Codable {
        var runs = 0, sponsorCards = 0, sponsorSwipes = 0
        var interstitials = 0, rewarded = 0, impressions = 0
        var seconds: Double = 0

        static func load() -> Metrics {
            guard let d = UserDefaults.standard.data(forKey: "metrics"),
                  let m = try? JSONDecoder().decode(Metrics.self, from: d) else { return Metrics() }
            return m
        }
        func save() {
            if let d = try? JSONEncoder().encode(self) { UserDefaults.standard.set(d, forKey: "metrics") }
        }
    }

    /// Extrapolates observed inventory to 100k DAU at blended eCPMs.
    var projectedMonthly: Int {
        let runs = Double(max(1, metrics.runs))
        let dau = 100_000.0, days = 30.0
        let deck   = Double(metrics.sponsorCards) / runs * 4  / 1000 * dau * days
        let inter  = Double(metrics.interstitials) / runs * 9  / 1000 * dau * days
        let reward = Double(metrics.rewarded) / runs * 22 / 1000 * dau * days
        return Int(deck + inter + reward)
    }

    // MARK: Wiring (set by the app)
    var ads: AdManaging?
    /// Remove Ads entitlement. Kills interstitials and in-deck ads; rewarded
    /// stays because the player asks for it.
    var adsRemoved: () -> Bool = { false }
    /// Fires when a run ends, and again if the score is doubled. The app uses
    /// it for leaderboards and the tracking prompt so this model stays free of
    /// GameKit and ATT.
    var onRunEnded: ((GameModel) -> Void)?

    // MARK: Internals
    private var queue: [Term] = []
    private var queueIndex = 0
    private var untilAd = 0
    private var right = 0, wrong = 0
    private var ticker: AnyCancellable?
    private var lastTick: Date?
    private var lastInterstitial: Date?

    var rank: String { Deck.rank(for: score) }
    var bestRank: String { Deck.rank(for: best) }

    init() {
        best = UserDefaults.standard.integer(forKey: "best")
        metrics = Metrics.load()
        daily = DailyRecord.load()
    }

    // MARK: - Daily Rot calendar

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var todayKey: String { Self.dayFormatter.string(from: Date()) }

    /// Daily Rot #1 is `Config.dailyEpoch`; every local day after increments it.
    var dailyNumber: Int {
        let cal = Calendar.current
        let from = cal.startOfDay(for: Config.dailyEpoch)
        let to = cal.startOfDay(for: Date())
        return max(1, (cal.dateComponents([.day], from: from, to: to).day ?? 0) + 1)
    }

    var dailyDoneToday: Bool { daily.date == todayKey }

    private var dailySeed: UInt64 {
        // Two rounds of mixing so consecutive days don't share structure.
        var g = SplitMix64(seed: UInt64(dailyNumber) &* 0x9E37_79B9_7F4A_7C15)
        return g.next()
    }

    // MARK: - Run lifecycle

    func startEndless() {
        mode = .endless
        queue = DeckLoader.shared.terms.shuffled()
        queueIndex = 0
        untilAd = Int.random(in: adGap)
        resetRunStats()
        meter = startMeter
        stack = []
        fill()
        phase = .playing
        metrics.runs += 1; metrics.save()
        resumeTimer()
    }

    /// Twenty fixed cards, the same for everyone today. No meter, no sponsor
    /// cards, one attempt — that's what makes the result shareable and fair.
    func startDaily() {
        guard !dailyDoneToday else { showDailyResult(); return }
        mode = .daily
        var g = SplitMix64(seed: dailySeed)
        let terms = DeckLoader.shared.terms
        let reals = terms.filter { $0.isReal }.shuffled(using: &g).prefix(dailyCount / 2)
        let fakes = terms.filter { !$0.isReal }.shuffled(using: &g).prefix(dailyCount - dailyCount / 2)
        var picks = Array(reals) + Array(fakes)
        picks.shuffle(using: &g)

        stack = picks.map { term in
            let odds = term.tricky ? hardTricky : hardChance
            return PlayCard(term: term, sponsor: nil, isHighRot: Double.random(in: 0..<1, using: &g) < odds)
        }.reversed()   // first pick ends up on top

        resetRunStats()
        dailyResults = []
        dailyElapsed = 0
        meter = 100
        isSponsorTop = false
        phase = .playing
        metrics.runs += 1; metrics.save()
        resumeTimer()
    }

    /// Re-open today's finished Daily Rot (from the title screen).
    func showDailyResult() {
        mode = .daily
        score = daily.score
        dailyResults = daily.results
        dailyElapsed = daily.elapsed
        highRotHits = daily.results.filter { $0 == .highHit }.count
        let hits = daily.results.filter { $0 != .miss }.count
        accuracy = daily.results.isEmpty ? 0 : Int(Double(hits) / Double(daily.results.count) * 100)
        phase = .over
    }

    private func resetRunStats() {
        score = 0; streak = 0; multiplier = 1; bestStreak = 0
        right = 0; wrong = 0; cardsJudged = 0; highRotHits = 0
        didRevive = false; didDouble = false
        scorePop = nil
    }

    func backToTitle() {
        pauseTimer()
        phase = .title
        isSponsorTop = false
    }

    // MARK: - Answering

    /// choice == true means the player swiped REAL (right).
    func answer(_ choice: Bool) {
        guard phase == .playing, let card = stack.last else { return }

        if card.isSponsor {
            meter = min(100, meter + 8)
            metrics.sponsorSwipes += 1; metrics.save()
            Haptics.tap(.light)
        } else if let term = card.term {
            cardsJudged += 1
            if choice == term.isReal {
                right += 1
                streak += 1
                bestStreak = max(bestStreak, streak)
                multiplier = streak >= 15 ? 10 : streak >= 10 ? 5 : streak >= 6 ? 3 : streak >= 3 ? 2 : 1
                let gained = 100 * multiplier * (card.isHighRot ? hardBonus : 1)
                score += gained
                if mode == .endless { meter = min(100, meter + rewardTime) }
                if card.isHighRot {
                    highRotHits += 1
                    flashScore("+\(gained.formatted())")
                    Haptics.success()
                } else {
                    Haptics.tap(.light)
                }
                if mode == .daily { dailyResults.append(card.isHighRot ? .highHit : .hit) }
            } else {
                wrong += 1
                streak = 0
                multiplier = 1
                if mode == .endless { meter -= penalty * (card.isHighRot ? hardRisk : 1) }
                Haptics.error()
                if mode == .daily { dailyResults.append(.miss) }
            }
        }

        stack.removeLast()

        switch mode {
        case .daily:
            if stack.isEmpty { finishDaily() }
        case .endless:
            if meter <= 0 { finishEndless() } else { fill() }
        }
    }

    private func fill() {
        while stack.count < 3 {
            stack.insert(next(), at: 0)     // index 0 is the deepest card
        }
        let top = stack.last
        isSponsorTop = top?.isSponsor ?? false
        if let top, top.isSponsor {
            metrics.sponsorCards += 1
            metrics.impressions += 1
            metrics.save()
        }
    }

    private func next() -> PlayCard {
        if untilAd <= 0 && !adsRemoved() {
            untilAd = Int.random(in: adGap)
            return PlayCard(term: nil, sponsor: Deck.sponsors.randomElement(), isHighRot: false)
        }
        untilAd -= 1
        guard !queue.isEmpty else {
            return PlayCard(term: Term("rizz", real: true, note: ""), sponsor: nil, isHighRot: false)
        }
        let term = queue[queueIndex % queue.count]
        queueIndex += 1
        // High Rot is always a dice roll so it stays unpredictable; the deck's
        // genuinely tricky terms simply roll with much better odds.
        let odds = term.tricky ? hardTricky : hardChance
        return PlayCard(term: term, sponsor: nil, isHighRot: Double.random(in: 0..<1) < odds)
    }

    private func flashScore(_ text: String) {
        scorePop = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.78) { [weak self] in
            if self?.scorePop == text { self?.scorePop = nil }
        }
    }

    // MARK: - Ending

    private func finishEndless() {
        pauseTimer()
        meter = 0
        phase = .over
        isSponsorTop = false
        let total = right + wrong
        accuracy = total > 0 ? Int(Double(right) / Double(total) * 100) : 0
        commitBest()
        Haptics.error()
        onRunEnded?(self)
        maybeInterstitial()
    }

    private func finishDaily() {
        pauseTimer()
        phase = .over
        let hits = dailyResults.filter { $0 != .miss }.count
        accuracy = Int(Double(hits) / Double(max(1, dailyResults.count)) * 100)

        // Streak: consecutive local days with a completed Daily.
        let yesterday = Self.dayFormatter.string(from: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        var record = daily
        record.streak = record.date == yesterday ? record.streak + 1 : 1
        record.date = todayKey
        record.number = dailyNumber
        record.score = score
        record.results = dailyResults
        record.elapsed = dailyElapsed
        record.best = max(record.best, score)
        record.save()
        daily = record

        Haptics.success()
        onRunEnded?(self)
        maybeInterstitial()
    }

    private func commitBest() {
        if score > best {
            best = score
            UserDefaults.standard.set(best, forKey: "best")
        }
    }

    /// Interstitial from the second run onward, never within 45 s of the last
    /// one, never for players who bought Remove Ads. Frequency capping, not greed.
    private func maybeInterstitial() {
        guard !adsRemoved(), metrics.runs >= 2 else { return }
        if let last = lastInterstitial, Date().timeIntervalSince(last) < Config.interstitialMinGap { return }
        lastInterstitial = Date()
        showAd(.interstitial) { _ in }
    }

    // MARK: - Rewarded placements (Endless only — Daily stays pure and comparable)

    /// Watch a rewarded video to continue with the score intact. Once per run.
    func revive() {
        guard mode == .endless, !didRevive else { return }
        showAd(.rewarded) { [weak self] earned in
            guard let self, earned else { return }
            self.didRevive = true
            self.meter = 60
            self.streak = 0
            self.multiplier = 1
            self.stack = []
            self.fill()
            self.phase = .playing
            self.resumeTimer()
        }
    }

    /// Watch a rewarded video to double the final score. Once per run.
    func doubleScore() {
        guard mode == .endless, !didDouble, phase == .over else { return }
        showAd(.rewarded) { [weak self] earned in
            guard let self, earned else { return }
            self.didDouble = true
            self.score *= 2
            self.flashScore("×2")
            self.commitBest()
            Haptics.success()
            self.onRunEnded?(self)
        }
    }

    private func showAd(_ slot: AdSlot, completion: @escaping (Bool) -> Void) {
        metrics.impressions += 1
        switch slot {
        case .interstitial: metrics.interstitials += 1
        case .rewarded:     metrics.rewarded += 1
        }
        metrics.save()
        guard let ads else { completion(true); return }
        ads.show(slot, completion: completion)
    }

    // MARK: - Timer
    //
    // Wall-clock deltas rather than frame counts, so a dropped frame can't make
    // the meter drain slower than real time.

    func resumeTimer() {
        guard phase == .playing else { return }
        lastTick = Date()
        ticker = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    func pauseTimer() {
        ticker?.cancel()
        ticker = nil
        lastTick = nil
        metrics.save()
    }

    private func tick() {
        guard phase == .playing else { return }
        let now = Date()
        // Clamp so returning from the background can't wipe the meter at once.
        let dt = min(0.1, now.timeIntervalSince(lastTick ?? now))
        lastTick = now
        metrics.seconds += dt

        switch mode {
        case .endless:
            let level = 1 + score / 1500
            meter -= drainBase * (1 + Double(level) * 0.16) * dt
            if meter <= 0 { finishEndless() }
        case .daily:
            dailyElapsed += dt
        }
    }
}

// MARK: - Haptics

enum Haptics {
    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error()   { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}
