import Foundation
import AppTrackingTransparency
#if canImport(GoogleUserMessagingPlatform)
import GoogleUserMessagingPlatform
#endif

/// Google's UMP consent flow (GDPR / UK / Swiss) and Apple's tracking prompt,
/// sequenced the way the networks and the reviewers expect:
///
///   launch → UMP consent (if the region needs it) → start ads
///   first run ends → ATT prompt
///
/// Without a certified CMP, Google serves only Limited Ads in the EEA/UK/CH,
/// so this is revenue, not paperwork.
///
/// Package: https://github.com/googleads/swift-package-manager-google-user-messaging-platform.git
final class ConsentManager: ObservableObject {
    static let shared = ConsentManager()

    @Published private(set) var canRequestAds = false
    @Published private(set) var privacyOptionsRequired = false

    private init() {}

    /// Runs the consent flow. Returns once ads may be requested (or once we know
    /// they may not). Safe to call every launch — required, in fact.
    @MainActor
    func gather() async {
        #if canImport(GoogleUserMessagingPlatform)
        await gatherWithUMP()
        #else
        canRequestAds = true
        #endif
    }

    /// Apple's prompt. Asked after the first completed run, not on launch —
    /// it converts far better once someone has actually played.
    @MainActor
    func requestTracking() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }

    #if canImport(GoogleUserMessagingPlatform)
    @MainActor
    private func gatherWithUMP() async {
        let params = RequestParameters()
        params.isTaggedForUnderAgeOfConsent = false

        #if DEBUG
        // Force the EEA flow on your own device to see the form:
        // let debug = DebugSettings(); debug.geography = .EEA
        // debug.testDeviceIdentifiers = ["<hashed id printed in the console>"]
        // params.debugSettings = debug
        #endif

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            ConsentInformation.shared.requestConsentInfoUpdate(with: params) { _ in cont.resume() }
        }

        if let vc = UIKitBridge.topViewController {
            try? await ConsentForm.loadAndPresentIfRequired(from: vc)
        }

        canRequestAds = ConsentInformation.shared.canRequestAds
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    /// The "privacy options" entry point GDPR requires once consent has been given.
    @MainActor
    func presentPrivacyOptions() async {
        guard let vc = UIKitBridge.topViewController else { return }
        try? await ConsentForm.presentPrivacyOptionsForm(from: vc)
    }
    #else
    @MainActor
    func presentPrivacyOptions() async {}
    #endif
}

