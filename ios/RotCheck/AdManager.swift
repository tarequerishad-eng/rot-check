import SwiftUI

/// One interface the game talks to. Who actually fills the slot is this
/// file's problem, not the game's.
protocol AdManaging: AnyObject {
    /// `completion(true)` means the unit ran to completion — for a rewarded
    /// slot that is the difference between earning the reward and not.
    func show(_ slot: AdSlot, completion: @escaping (Bool) -> Void)
}

// MARK: - House ads
//
// Always available, so a no-fill never leaves a dead end — and so the full ad
// experience can be demoed to a buyer before any network is live.
final class HouseAdManager: ObservableObject, AdManaging {

    struct Active {
        let slot: AdSlot
        let sponsor: Sponsor
        var remaining: Int
        var completion: (Bool) -> Void
    }

    @Published var active: Active?
    private var timer: Timer?

    func show(_ slot: AdSlot, completion: @escaping (Bool) -> Void) {
        guard active == nil else { completion(false); return }   // never stack two units
        let sponsor = Deck.sponsors.randomElement() ?? Deck.sponsors[0]
        active = Active(slot: slot, sponsor: sponsor, remaining: slot == .rewarded ? 6 : 5, completion: completion)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.countdown()
        }
    }

    private func countdown() {
        guard var a = active else { return }
        a.remaining -= 1
        active = a
        if a.remaining <= 0 { timer?.invalidate(); timer = nil }
    }

    /// Called by the overlay's dismiss button once the countdown finishes.
    func dismiss() {
        guard let a = active else { return }
        timer?.invalidate(); timer = nil
        active = nil
        a.completion(true)
    }
}

// MARK: - AdMob (Google Mobile Ads SDK v12+)
//
// Wrapped in canImport so the app builds and runs on house ads before the
// package is added. Once it resolves, this takes over automatically.
//
// Package: https://github.com/googleads/swift-package-manager-google-mobile-ads.git
// v12 dropped the GAD prefix: MobileAds.shared, InterstitialAd, RewardedAd,
// NativeAd, AdLoader, Request, present(from:).

#if canImport(GoogleMobileAds)
import GoogleMobileAds

final class AdMobManager: NSObject, ObservableObject, AdManaging {

    /// Set once at start so the sponsor card can pull a native ad without the
    /// game model knowing the SDK exists.
    private(set) static var shared: AdMobManager?

    @Published private(set) var isReady = false

    private var interstitial: InterstitialAd?
    private var rewarded: RewardedAd?
    private var nativeAd: NativeAd?
    private var nativeLoader: AdLoader?
    private var completion: ((Bool) -> Void)?
    private var earnedReward = false
    private var started = false

    /// House ads cover any no-fill, so the player never hits a dead end.
    private let house: HouseAdManager

    init(house: HouseAdManager) {
        self.house = house
        super.init()
        Self.shared = self
    }

    /// Call only after consent has been gathered (see ConsentManager).
    func start() {
        guard !started else { return }
        started = true
        MobileAds.shared.requestConfiguration.tagForChildDirectedTreatment = NSNumber(value: false)
        MobileAds.shared.start { [weak self] _ in
            self?.isReady = true
            self?.preload()
        }
    }

    private func preload() {
        if interstitial == nil {
            InterstitialAd.load(with: Config.adUnitInterstitial, request: Request()) { [weak self] ad, _ in
                self?.interstitial = ad
                ad?.fullScreenContentDelegate = self
            }
        }
        if rewarded == nil {
            RewardedAd.load(with: Config.adUnitRewarded, request: Request()) { [weak self] ad, _ in
                self?.rewarded = ad
                ad?.fullScreenContentDelegate = self
            }
        }
        if nativeAd == nil { loadNative() }
    }

    // MARK: Native (fills the in-deck sponsor card)

    private func loadNative() {
        guard let root = UIKitBridge.rootViewController else { return }
        let loader = AdLoader(adUnitID: Config.adUnitNative, rootViewController: root, adTypes: [.native], options: nil)
        loader.delegate = self
        nativeLoader = loader
        loader.load(Request())
    }

    /// Hands the preloaded native ad to a card and immediately loads the next.
    /// Each NativeAd may only be shown once — reuse doesn't count as an impression.
    func takeNative() -> NativeAd? {
        let ad = nativeAd
        nativeAd = nil
        if ad != nil { loadNative() }
        return ad
    }

    // MARK: Full-screen

    func show(_ slot: AdSlot, completion: @escaping (Bool) -> Void) {
        guard let root = UIKitBridge.topViewController else {
            house.show(slot, completion: completion); return
        }
        self.completion = completion
        earnedReward = false

        switch slot {
        case .interstitial:
            guard let ad = interstitial else {
                self.completion = nil
                house.show(slot, completion: completion); return
            }
            interstitial = nil
            ad.present(from: root)

        case .rewarded:
            guard let ad = rewarded else {
                self.completion = nil
                house.show(slot, completion: completion); return
            }
            rewarded = nil
            ad.present(from: root) { [weak self] in
                self?.earnedReward = true
            }
        }
    }
}

extension AdMobManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        let done = completion
        completion = nil
        // A dismissed rewarded ad only counts if the reward callback fired.
        let wasRewarded = ad is RewardedAd
        done?(wasRewarded ? earnedReward : true)
        preload()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        let done = completion
        completion = nil
        preload()
        if let done { house.show(ad is RewardedAd ? .rewarded : .interstitial, completion: done) }
    }
}

extension AdMobManager: NativeAdLoaderDelegate {
    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        self.nativeAd = nativeAd
    }

    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        // No fill: the house card renders instead. Try again on the next preload.
    }
}
#endif
