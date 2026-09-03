import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: Store
    @ObservedObject private var consent = ConsentManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var reminderOn = Reminders.isEnabled
    @State private var reminderTime: Date = {
        let t = Reminders.time
        return Calendar.current.date(bySettingHour: t.hour, minute: t.minute, second: 0, of: Date()) ?? Date()
    }()
    @State private var reminderDenied = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.groundDeep.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        removeAdsCard
                        reminderCard
                        leaderboardsCard
                        if consent.privacyOptionsRequired { privacyCard }
                        aboutCard
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.font(Fonts.ui(15, weight: .bold)).foregroundStyle(Theme.real)
                }
            }
            .toolbarBackground(Theme.groundDeep, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Remove Ads

    private var removeAdsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            StatLabel(text: "Remove ads")
            if store.hasRemovedAds {
                Text("Ads are off. Thank you — this is what keeps the deck growing.")
                    .font(Fonts.ui(14)).foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("No interstitials, no ads in the deck. Rewarded videos stay — they're yours to choose.")
                    .font(Fonts.ui(14)).foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    Task { await store.purchaseRemoveAds() }
                } label: {
                    HStack {
                        Text("REMOVE ADS").font(Fonts.display(17)).tracking(0.8)
                        Spacer()
                        Text(store.priceText).font(Fonts.mono(14))
                    }
                    .foregroundStyle(Theme.sponsorInk)
                    .padding(.horizontal, 16).frame(minHeight: 50)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.sponsor))
                }
                .buttonStyle(.plain)
                .disabled(store.state == .purchasing || store.state == .loading)
            }

            Button("Restore purchases") { Task { await store.restore() } }
                .font(Fonts.ui(13, weight: .bold)).foregroundStyle(Theme.inkFaint)

            if case .failed(let message) = store.state {
                Text(message).font(Fonts.ui(12)).foregroundStyle(Theme.fake)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel(Theme.surface, stroke: store.hasRemovedAds ? Theme.line : Theme.sponsor, radius: 16)
    }

    // MARK: Daily reminder

    private var reminderCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            StatLabel(text: "Daily reminder")
            Toggle(isOn: $reminderOn) {
                Text("Tell me when today's Rot is ready")
                    .font(Fonts.ui(14)).foregroundStyle(Theme.ink)
            }
            .tint(Theme.real)
            .onChange(of: reminderOn) { on in
                Task {
                    if on {
                        let c = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
                        let ok = await Reminders.enable(hour: c.hour ?? 18, minute: c.minute ?? 30)
                        if !ok { reminderOn = false; reminderDenied = true }
                    } else {
                        Reminders.disable()
                    }
                }
            }
            if reminderOn {
                DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    .font(Fonts.ui(14)).foregroundStyle(Theme.inkSoft)
                    .tint(Theme.real)
                    .onChange(of: reminderTime) { t in
                        let c = Calendar.current.dateComponents([.hour, .minute], from: t)
                        Task { _ = await Reminders.enable(hour: c.hour ?? 18, minute: c.minute ?? 30) }
                    }
            }
            if reminderDenied {
                Text("Notifications are off for Rot Check in iOS Settings.")
                    .font(Fonts.ui(12)).foregroundStyle(Theme.fake)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel(Theme.surface, stroke: Theme.line, radius: 16)
    }

    // MARK: Leaderboards

    private var leaderboardsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            StatLabel(text: "Leaderboards")
            HStack(spacing: 10) {
                Button("Endless") { GameCenterManager.shared.showLeaderboard(mode: .endless) }
                Button("Daily Rot") { GameCenterManager.shared.showLeaderboard(mode: .daily) }
            }
            .buttonStyle(.plain)
            .font(Fonts.ui(14, weight: .bold))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel(Theme.surface, stroke: Theme.line, radius: 16)
    }

    // MARK: Privacy options (GDPR entry point — shown only when required)

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            StatLabel(text: "Privacy")
            Button("Ad privacy options") { Task { await consent.presentPrivacyOptions() } }
                .font(Fonts.ui(14, weight: .bold)).foregroundStyle(Theme.ink)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel(Theme.surface, stroke: Theme.line, radius: 16)
    }

    // MARK: About

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            StatLabel(text: "About")
            Text("Rot Check \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(Fonts.ui(13)).foregroundStyle(Theme.inkSoft)
            Text("The fake terms are invented. The real ones are, unfortunately, real.")
                .font(Fonts.ui(12)).foregroundStyle(Theme.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel(Theme.surface, stroke: Theme.line, radius: 16)
    }
}
