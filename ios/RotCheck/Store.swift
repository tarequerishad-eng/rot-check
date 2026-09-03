import Foundation
import StoreKit

/// Remove Ads — a single non-consumable via StoreKit 2. Kills interstitials
/// and in-deck ads; rewarded stays because the player asks for it.
///
/// Product ID is `Config.removeAdsProductID`. Create it in App Store Connect
/// (and in a local .storekit configuration for testing) with the same ID.
@MainActor
final class Store: ObservableObject {
    static let shared = Store()

    enum State: Equatable { case idle, loading, purchasing, failed(String) }

    @Published private(set) var hasRemovedAds: Bool
    @Published private(set) var removeAds: Product?
    @Published private(set) var state: State = .idle

    private var updates: Task<Void, Never>?
    private static let key = "store.removeAds"

    private init() {
        hasRemovedAds = UserDefaults.standard.bool(forKey: Self.key)
        updates = listenForTransactions()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit { updates?.cancel() }

    var priceText: String { removeAds?.displayPrice ?? "$2.99" }

    // MARK: Products

    func loadProducts() async {
        state = .loading
        do {
            removeAds = try await Product.products(for: [Config.removeAdsProductID]).first
            state = .idle
        } catch {
            state = .failed("Store unavailable. Try again in a moment.")
        }
    }

    // MARK: Purchase

    func purchaseRemoveAds() async {
        guard let product = removeAds else { await loadProducts(); return }
        state = .purchasing
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    grant()
                }
                state = .idle
            case .userCancelled, .pending:
                state = .idle
            @unknown default:
                state = .idle
            }
        } catch {
            state = .failed("Purchase didn't go through. You weren't charged.")
        }
    }

    /// Apple requires a visible Restore button for non-consumables.
    func restore() async {
        state = .loading
        try? await AppStore.sync()
        await refreshEntitlements()
        state = .idle
    }

    // MARK: Entitlements

    func refreshEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result,
               t.productID == Config.removeAdsProductID,
               t.revocationDate == nil {
                owned = true
            }
        }
        if owned { grant() }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let t) = result else { continue }
                await t.finish()
                if t.productID == Config.removeAdsProductID {
                    await MainActor.run { self?.grant() }
                }
            }
        }
    }

    private func grant() {
        hasRemovedAds = true
        UserDefaults.standard.set(true, forKey: Self.key)
    }
}
