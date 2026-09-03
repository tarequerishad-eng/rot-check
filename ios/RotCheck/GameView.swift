import SwiftUI

struct GameView: View {
    @ObservedObject var model: GameModel
    @State private var exitEdge: Edge = .trailing

    var body: some View {
        VStack(spacing: 0) {
            hud
            arena
            controls
        }
    }

    // MARK: HUD

    private var hud: some View {
        VStack(spacing: 10) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    StatLabel(text: "Score")
                    Text(model.score.formatted())
                        .font(Fonts.display(30)).foregroundStyle(Theme.ink)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                Spacer()
                if model.mode == .daily {
                    VStack(alignment: .trailing, spacing: 2) {
                        StatLabel(text: "Card \(min(20, model.dailyResults.count + 1)) of 20")
                        Text(ShareCard.clock(model.dailyElapsed))
                            .font(Fonts.display(30)).foregroundStyle(Theme.inkSoft)
                            .monospacedDigit()
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        StatLabel(text: "Streak")
                        Text("×\(model.multiplier)")
                            .font(Fonts.display(30)).foregroundStyle(multiplierColour)
                            .monospacedDigit()
                            .scaleEffect(model.multiplier >= 10 ? 1.08 : 1)
                            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: model.multiplier)
                    }
                }
            }

            if model.mode == .daily { dailyProgress } else { meter }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    private var meter: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surfaceHi)
                Capsule()
                    .fill(LinearGradient(colors: [Theme.fake, Theme.sponsor, Theme.real], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * CGFloat(max(0, min(100, model.meter)) / 100))
                    .opacity(model.meter < 25 ? 0.55 : 1)
            }
        }
        .frame(height: 9)
        .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
    }

    /// Twenty segments that fill with the result colour as you go.
    private var dailyProgress: some View {
        HStack(spacing: 3) {
            ForEach(0..<20, id: \.self) { i in
                Capsule().fill(segmentColour(i)).frame(height: 9)
            }
        }
    }

    private func segmentColour(_ i: Int) -> Color {
        guard i < model.dailyResults.count else { return Theme.surfaceHi }
        switch model.dailyResults[i] {
        case .hit:     return Theme.real
        case .highHit: return Theme.sponsor
        case .miss:    return Theme.fake
        }
    }

    private var multiplierColour: Color {
        model.multiplier >= 10 ? Theme.fake : model.multiplier >= 3 ? Theme.sponsor : Theme.inkSoft
    }

    // MARK: Card stack

    private var arena: some View {
        ZStack {
            let visible = Array(model.stack.suffix(3))
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, card in
                let depth = visible.count - 1 - index
                CardView(card: card, depth: depth) { right in swipe(right) }
                    .zIndex(Double(index))
                    .transition(.asymmetric(
                        insertion: .identity,
                        removal: .move(edge: exitEdge).combined(with: .opacity)
                    ))
            }

            if let pop = model.scorePop {
                Text(pop)
                    .font(Fonts.display(38)).foregroundStyle(Theme.ink)
                    .shadow(color: Theme.ink.opacity(0.7), radius: 20)
                    .offset(y: -60)
                    .transition(.scale.combined(with: .opacity))
                    .allowsHitTesting(false)
                    .zIndex(100)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 22)
        .animation(.easeOut(duration: 0.3), value: model.scorePop)
    }

    private func swipe(_ right: Bool) {
        exitEdge = right ? .trailing : .leading
        withAnimation(.easeOut(duration: 0.3)) { model.answer(right) }
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 11) {
            HStack(spacing: 12) {
                button("← FAKE", Theme.fake) { swipe(false) }
                button("REAL →", Theme.real) { swipe(true) }
            }
            Text("Drag the card, or tap a side")
                .font(Fonts.mono(11)).foregroundStyle(Theme.inkFaint)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 20)
    }

    private func button(_ title: String, _ colour: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Fonts.display(19)).tracking(1)
                .foregroundStyle(Theme.ground)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(colour))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Game over

struct GameOverView: View {
    @ObservedObject var model: GameModel
    @ObservedObject var store: Store

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.mode == .daily { dailyHeader } else { endlessHeader }

            Spacer(minLength: 14)

            VStack(spacing: 10) {
                if model.mode == .daily {
                    ShareLink(item: dailyShare) { primary("SHARE YOUR GRID", gradient: [Theme.sponsor, Theme.real]) }
                        .buttonStyle(.plain)
                    Button { model.startEndless() } label: { primary("PLAY ENDLESS", gradient: [Theme.fake, Theme.real]) }
                        .buttonStyle(.plain)
                    ghost("Today's leaderboard") { GameCenterManager.shared.showLeaderboard(mode: .daily) }
                } else {
                    if !model.didRevive {
                        Button { model.revive() } label: { rewarded("▶  WATCH AD, KEEP GOING") }
                            .buttonStyle(.plain)
                    }
                    if !model.didDouble {
                        Button { model.doubleScore() } label: { rewarded("▶  WATCH AD, DOUBLE IT") }
                            .buttonStyle(.plain)
                    }
                    Button { model.startEndless() } label: { primary("RUN IT BACK", gradient: [Theme.fake, Theme.real]) }
                        .buttonStyle(.plain)
                    HStack(spacing: 10) {
                        ShareLink(item: endlessShare) { ghostLabel("Share") }.buttonStyle(.plain)
                        ghost("Leaderboard") { GameCenterManager.shared.showLeaderboard(mode: .endless) }
                    }
                }
                ghost("Back") { model.backToTitle() }
            }
        }
        .padding(22)
    }

    // MARK: Headers

    private var endlessHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            StatLabel(text: model.didDouble ? "Doubled to" : "You got cooked at")
            Text(model.score.formatted())
                .font(Fonts.display(70)).foregroundStyle(Theme.ink)
                .monospacedDigit().minimumScaleFactor(0.5).lineLimit(1)
                .contentTransition(.numericText())
            Text(model.rank.uppercased())
                .font(Fonts.display(36))
                .foregroundStyle(LinearGradient(colors: [Theme.sponsor, Theme.fake], startPoint: .leading, endPoint: .trailing))
                .minimumScaleFactor(0.5).lineLimit(2)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                tile("Best streak", "×\(max(1, model.bestStreak))")
                tile("Accuracy", "\(model.accuracy)%")
                tile("High Rot nailed", "\(model.highRotHits)")
                tile("Personal best", model.best.formatted())
            }
            .padding(.top, 14)
        }
    }

    private var dailyHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            StatLabel(text: "Daily Rot #\(model.dailyNumber)")
            Text(model.score.formatted())
                .font(Fonts.display(70)).foregroundStyle(Theme.ink)
                .monospacedDigit().minimumScaleFactor(0.5).lineLimit(1)

            // The grid, drawn — the share text carries the emoji version.
            let cols = Array(repeating: GridItem(.flexible(), spacing: 5), count: 5)
            LazyVGrid(columns: cols, spacing: 5) {
                ForEach(Array(model.dailyResults.enumerated()), id: \.offset) { _, r in
                    RoundedRectangle(cornerRadius: 5)
                        .fill(r == .hit ? Theme.real : r == .highHit ? Theme.sponsor : Theme.fake)
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            .padding(.top, 12)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                tile("Correct", "\(model.dailyResults.filter { $0 != .miss }.count)/20")
                tile("Time", ShareCard.clock(model.dailyElapsed))
                tile("Streak", model.daily.streak > 0 ? "🔥\(model.daily.streak)" : "—")
            }
            .padding(.top, 12)
        }
    }

    // MARK: Share payloads

    private var dailyShare: String {
        ShareCard.daily(number: model.dailyNumber, score: model.score, results: model.dailyResults,
                        elapsed: model.dailyElapsed, streak: model.daily.streak)
    }
    private var endlessShare: String {
        ShareCard.endless(score: model.score, rank: model.rank, bestStreak: model.bestStreak)
    }

    // MARK: Buttons

    private func primary(_ title: String, gradient: [Color]) -> some View {
        Text(title)
            .font(Fonts.display(21)).tracking(1)
            .foregroundStyle(Theme.ground)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing))
            )
    }

    private func rewarded(_ title: String) -> some View {
        Text(title)
            .font(Fonts.display(16)).tracking(0.6)
            .foregroundStyle(Theme.sponsorInk)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.sponsor))
    }

    private func ghost(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { ghostLabel(title) }.buttonStyle(.plain)
    }

    private func ghostLabel(_ title: String) -> some View {
        Text(title)
            .font(Fonts.ui(14, weight: .bold))
            .foregroundStyle(Theme.inkSoft)
            .frame(maxWidth: .infinity, minHeight: 44)
            .panel(.clear, stroke: Theme.line)
    }

    private func tile(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            StatLabel(text: label)
            Text(value)
                .font(Fonts.display(21)).foregroundStyle(Theme.ink)
                .monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11).padding(.vertical, 9)
        .panel()
    }
}
