import UIKit

/// Every identifier that has to match something outside the code — the bundle
/// ID, store products, leaderboards, ad units — lives here so a change is one
/// edit, not a hunt.
enum Config {

    /// Change this once and everything below follows.
    static let bundleID = "com.tareque.rotcheck"

    // MARK: App Store Connect
    static let removeAdsProductID  = bundleID + ".removeads"      // non-consumable, $2.99
    static let leaderboardEndless  = bundleID + ".endless"        // classic, all-time
    static let leaderboardDaily    = bundleID + ".daily"          // recurring, resets daily

    /// Shown in the share text. Replace with the real App Store link once the
    /// app record exists — App Store Connect shows it before the app is live.
    static let shareURL = "https://apps.apple.com/app/rot-check"

    // MARK: AdMob
    //
    // The unit IDs below are Google's public *test* units. They serve real-looking
    // test creatives and are safe during development. Swap for your own before
    // release, or the account can be flagged.
    static let admobAppID          = "ca-app-pub-3940256099942544~1458002511"   // TODO: yours (goes in Info.plist too)
    static let adUnitInterstitial  = "ca-app-pub-3940256099942544/4411468910"   // TODO: yours
    static let adUnitRewarded      = "ca-app-pub-3940256099942544/1712485313"   // TODO: yours
    static let adUnitNative        = "ca-app-pub-3940256099942544/3986624511"   // TODO: yours

    /// Minimum seconds between interstitials. Networks reward sane pacing and
    /// players tolerate it; firing on every quick retry does neither.
    static let interstitialMinGap: TimeInterval = 45

    // MARK: Content
    /// Optional remote deck. Any static host works (GitHub raw, Cloudflare Pages).
    /// nil = bundled deck only.
    static let deckURL: URL? = nil   // e.g. URL(string: "https://raw.githubusercontent.com/you/rotcheck-content/main/deck.json")

    /// Daily Rot #1 is this date. Every day after increments the number.
    static let dailyEpoch = DateComponents(calendar: .current, year: 2026, month: 9, day: 14).date ?? Date()
}

/// The one UIKit lookup several managers need.
enum UIKitBridge {
    static var rootViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    }

    /// Walks presented controllers so sheets get presented on top of sheets.
    static var topViewController: UIViewController? {
        var top = rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
