import SwiftUI

struct ContentView: View {
    @ObservedObject var model: GameModel
    @ObservedObject var house: HouseAdManager
    @ObservedObject var store: Store
    @State private var showSettings = false

    var body: some View {
        ZStack {
            AmbientBackground()

            VStack(spacing: 14) {
                frame
                #if DEBUG
                MetricsDrawer(model: model)
                #endif
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .frame(maxWidth: 460)

            if house.active != nil {
                HouseAdOverlay(house: house).transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: house.active != nil)
        .sheet(isPresented: $showSettings) {
            SettingsView(store: store)
        }
    }

    private var frame: some View {
        ZStack {
            switch model.phase {
            case .title:   TitleView(model: model, store: store, showSettings: $showSettings)
            case .playing: GameView(model: model)
            case .over:    GameOverView(model: model, store: store)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [Theme.surface, Theme.ground], startPoint: .top, endPoint: .bottom))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(model.isSponsorTop ? Theme.sponsor : Theme.line, lineWidth: model.isSponsorTop ? 2 : 1)
        )
        .shadow(color: model.isSponsorTop ? Theme.sponsor.opacity(0.45) : .clear, radius: 30)
        .animation(.easeInOut(duration: 0.25), value: model.isSponsorTop)
    }
}

// MARK: - Title

struct TitleView: View {
    @ObservedObject var model: GameModel
    @ObservedObject var store: Store
    @Binding var showSettings: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text("ROT\nCHECK")
                    .font(Fonts.logo(52))
                    .foregroundStyle(
                        LinearGradient(colors: [Theme.fake, Color(hex: 0xFF7AC4), Theme.real],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .shadow(color: .black.opacity(0.55), radius: 0, y: 3)
                Spacer()
                VStack(spacing: 10) {
                    iconButton("trophy.fill") { GameCenterManager.shared.showLeaderboard(mode: .endless) }
                    iconButton("gearshape.fill") { showSettings = true }
                }
            }

            Text("Real slang, or AI slop? You get about a second to decide.")
                .font(Fonts.ui(15))
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 10)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                rule(swatch: "→", colour: Theme.real,    text: "Right if it's real")
                rule(swatch: "←", colour: Theme.fake,    text: "Left if it's made up")
                rule(swatch: "3×", colour: Theme.ink,    text: "High Rot pays triple, costs more to miss")
                if !store.hasRemovedAds {
                    rule(swatch: "$", colour: Theme.sponsor, text: "Yellow cards are ads. Swipe either way.")
                }
            }
            .padding(.top, 16)

            Spacer(minLength: 14)

            // Daily Rot is the primary action: it's the thing that brings people back.
            Button { model.startDaily() } label: {
                VStack(spacing: 2) {
                    Text(model.dailyDoneToday ? "DAILY ROT #\(model.dailyNumber) · DONE" : "DAILY ROT #\(model.dailyNumber)")
                        .font(Fonts.display(21)).tracking(1)
                    Text(model.dailyDoneToday
                         ? "\(model.daily.score.formatted()) pts · tap to share"
                         : "20 cards · one shot · same for everyone")
                        .font(Fonts.mono(10)).tracking(1)
                        .opacity(0.8)
                }
                .foregroundStyle(Theme.ground)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(colors: [Theme.sponsor, Theme.real], startPoint: .leading, endPoint: .trailing))
                )
            }
            .buttonStyle(.plain)

            Button { model.startEndless() } label: {
                VStack(spacing: 2) {
                    Text("ENDLESS").font(Fonts.display(21)).tracking(1)
                    Text("BEST \(model.best.formatted()) · \(model.bestRank.uppercased())")
                        .font(Fonts.mono(10)).tracking(1)
                        .opacity(0.8)
                }
                .foregroundStyle(Theme.ground)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(colors: [Theme.fake, Theme.real], startPoint: .leading, endPoint: .trailing))
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 10)

            if model.daily.streak > 1 {
                Text("🔥 \(model.daily.streak)-day streak")
                    .font(Fonts.mono(11))
                    .foregroundStyle(Theme.sponsor)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
            }
        }
        .padding(22)
    }

    private func iconButton(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 40, height: 40)
                .panel()
        }
        .buttonStyle(.plain)
    }

    private func rule(swatch: String, colour: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Text(swatch)
                .font(Fonts.display(12))
                .foregroundStyle(Theme.ground)
                .frame(width: 34, height: 26)
                .background(RoundedRectangle(cornerRadius: 7).fill(colour))
            Text(text)
                .font(Fonts.ui(13.5))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .panel()
    }
}

// MARK: - House ad overlay

struct HouseAdOverlay: View {
    @ObservedObject var house: HouseAdManager

    var body: some View {
        if let active = house.active {
            let total = Double(active.slot == .rewarded ? 6 : 5)
            let progress = max(0, min(1, (total - Double(active.remaining)) / total))

            ZStack {
                Theme.groundDeep.ignoresSafeArea()
                VStack(spacing: 16) {
                    Text(active.slot == .rewarded ? "REWARDED VIDEO" : "ADVERTISEMENT")
                        .font(Fonts.mono(10)).tracking(2)
                        .foregroundStyle(Theme.sponsorInk)
                        .padding(.horizontal, 11).padding(.vertical, 5)
                        .background(Capsule().fill(Theme.sponsor))

                    ZStack {
                        Circle().stroke(Theme.surfaceHi, lineWidth: 10).frame(width: 100, height: 100)
                        Circle().trim(from: 0, to: progress)
                            .stroke(Theme.sponsor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: progress)
                        if active.remaining > 0 {
                            Text("\(active.remaining)").font(Fonts.display(30)).foregroundStyle(Theme.ink)
                        }
                    }

                    Text(active.sponsor.brand)
                        .font(Fonts.display(38)).foregroundStyle(Theme.sponsor)
                        .multilineTextAlignment(.center)
                    Text(active.sponsor.copy)
                        .font(Fonts.ui(15)).foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)

                    if active.remaining <= 0 {
                        Button { house.dismiss() } label: {
                            Text(active.slot == .rewarded ? "Claim reward" : "Continue")
                                .font(Fonts.ui(14, weight: .bold))
                                .foregroundStyle(Theme.ink)
                                .frame(maxWidth: 220).padding(.vertical, 13)
                                .panel(.clear, stroke: Theme.line)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(28)
            }
        }
    }
}

// MARK: - Advertiser drawer (DEBUG builds only)

struct MetricsDrawer: View {
    @ObservedObject var model: GameModel
    @State private var open = false

    var body: some View {
        VStack(spacing: 0) {
            Button { withAnimation(.easeInOut(duration: 0.2)) { open.toggle() } } label: {
                HStack {
                    Text("AD INVENTORY · LIVE FROM THIS DEVICE").font(Fonts.mono(11)).tracking(1.4)
                    Spacer()
                    Image(systemName: "chevron.down").rotationEffect(.degrees(open ? 180 : 0))
                }
                .foregroundStyle(Theme.inkSoft)
                .padding(.horizontal, 16).padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if open {
                VStack(alignment: .leading, spacing: 0) {
                    row("Sessions", model.metrics.runs)
                    row("In-deck sponsor cards", model.metrics.sponsorCards, highlight: true)
                    row("Sponsor card swipes", model.metrics.sponsorSwipes)
                    row("Interstitials", model.metrics.interstitials)
                    row("Rewarded completions", model.metrics.rewarded, highlight: true)
                    row("Total impressions", model.metrics.impressions)

                    VStack(alignment: .leading, spacing: 4) {
                        StatLabel(text: "Projected monthly · at 100,000 DAU")
                        Text("$\(model.projectedMonthly.formatted())")
                            .font(Fonts.display(32)).foregroundStyle(Theme.sponsor)
                    }
                    .padding(13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.groundDeep))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.sponsor, lineWidth: 1))
                    .padding(.top, 14)
                }
                .padding(.horizontal, 16).padding(.bottom, 18)
            }
        }
        .panel(Theme.surface, stroke: Theme.line, radius: 16)
    }

    private func row(_ label: String, _ value: Int, highlight: Bool = false) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.inkSoft)
            Spacer()
            Text(value.formatted()).foregroundStyle(highlight ? Theme.sponsor : Theme.ink).monospacedDigit()
        }
        .font(Fonts.mono(12))
        .padding(.vertical, 8)
        .overlay(Rectangle().fill(Theme.line).frame(height: 1), alignment: .bottom)
    }
}
