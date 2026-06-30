import Foundation
import StoreKit

@Observable
@MainActor
final class ProService {

    static let productId = "com.nimva.pro.monthly"

    private(set) var isProUser: Bool = false
    private(set) var purchaseInProgress: Bool = false
    private(set) var product: Product? = nil

    // In DEBUG builds, PRO is always unlocked so every screen is testable
    // without a real subscription or sandbox account.
    #if DEBUG
    var isProEnabled: Bool { true }
    #else
    var isProEnabled: Bool { isProUser }
    #endif

    init() {
        Task { await refresh() }
    }

    // MARK: - Public API

    /// Loads the product from the App Store (or StoreKit config in simulator)
    /// and checks whether the user currently has an active entitlement.
    func refresh() async {
        async let productLoad = loadProduct()
        async let entitlementCheck = checkEntitlement()
        product = await productLoad
        isProUser = await entitlementCheck
    }

    /// Initiates the purchase flow. Returns true if the purchase succeeded.
    @discardableResult
    func purchase() async throws -> Bool {
        guard let product else { return false }
        purchaseInProgress = true
        defer { purchaseInProgress = false }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            isProUser = true
            return true
        case .pending, .userCancelled:
            return false
        @unknown default:
            return false
        }
    }

    /// Restores purchases — call from the Settings restore button.
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            isProUser = await checkEntitlement()
        } catch {
            // Restore failed silently — the user can try again
        }
    }

    // MARK: - Private

    private func loadProduct() async -> Product? {
        guard let products = try? await Product.products(for: [Self.productId]) else { return nil }
        return products.first
    }

    private func checkEntitlement() async -> Bool {
        for await result in Transaction.currentEntitlements(for: Self.productId) {
            guard let transaction = try? checkVerified(result) else { continue }
            if transaction.revocationDate == nil { return true }
        }
        return false
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let value):
            return value
        }
    }
}

enum StoreError: Error {
    case failedVerification
}
