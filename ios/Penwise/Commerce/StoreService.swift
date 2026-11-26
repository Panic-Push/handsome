import Foundation
import StoreKit

/// Premium purchases with StoreKit 2: a monthly and a yearly subscription
/// (with a free week) and a one-off lifetime unlock.
///
/// Front end: show `products` on the paywall (sorted yearly, monthly,
/// lifetime), call `purchase(_:)` and `restore()`, and read `isPremium`.
/// The product ids must match App Store Connect (see docs/app-store/).
@MainActor
final class StoreService: ObservableObject {
    static let shared = StoreService()

    enum ProductID: String, CaseIterable {
        case yearly = "app.penwise.premium.yearly"
        case monthly = "app.penwise.premium.monthly"
        case lifetime = "app.penwise.premium.lifetime"
    }

    enum PurchaseOutcome: Equatable {
        case purchased
        case pending
        case cancelled
        case failed(String)
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPremium: Bool
    /// Which product unlocked Premium (nil when not Premium).
    @Published private(set) var activeProductID: String?
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?

    private var updates: Task<Void, Never>?
    private static let cacheKey = "penwise.store.isPremium"

    private init() {
        // Remember the last known state so Premium works offline at launch.
        isPremium = UserDefaults.standard.bool(forKey: StoreService.cacheKey)
    }

    /// Call once at launch: listens for renewals/refunds and loads products.
    func start() async {
        if updates == nil {
            updates = Task { [weak self] in
                for await update in Transaction.updates {
                    if case .verified(let transaction) = update {
                        await transaction.finish()
                    }
                    await self?.refreshEntitlements()
                }
            }
        }
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await Product.products(for: ProductID.allCases.map(\.rawValue))
            let order = ProductID.allCases.map(\.rawValue)
            products = loaded.sorted { (order.firstIndex(of: $0.id) ?? 9) < (order.firstIndex(of: $1.id) ?? 9) }
            lastError = nil
        } catch {
            lastError = "Couldn't load Premium options. Check your connection and try again."
        }
    }

    func product(_ id: ProductID) -> Product? { products.first { $0.id == id.rawValue } }

    func purchase(_ product: Product) async -> PurchaseOutcome {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    return .failed("The purchase couldn't be verified.")
                }
                await transaction.finish()
                await refreshEntitlements()
                return .purchased
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .cancelled
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// Restores purchases (App Store review requires a visible Restore button).
    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            lastError = "Couldn't restore purchases. Try again in a moment."
        }
        await refreshEntitlements()
    }

    /// Re-reads the current entitlements from StoreKit.
    func refreshEntitlements() async {
        var active: String?
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement,
                  ProductID(rawValue: transaction.productID) != nil,
                  transaction.revocationDate == nil else { continue }
            if let expiry = transaction.expirationDate, expiry < Date() { continue }
            active = transaction.productID
        }
        activeProductID = active
        isPremium = active != nil
        UserDefaults.standard.set(isPremium, forKey: StoreService.cacheKey)
    }

    /// "7 days free, then $29.99/year" style text for a subscription.
    func offerText(for product: Product) -> String {
        guard let subscription = product.subscription else { return "\(product.displayPrice) once" }
        let period = subscription.subscriptionPeriod.unit == .year ? "year" : "month"
        if let intro = subscription.introductoryOffer, intro.paymentMode == .freeTrial {
            let days = intro.period.unit == .week ? intro.period.value * 7 : intro.period.value
            return "\(days) days free, then \(product.displayPrice)/\(period)"
        }
        return "\(product.displayPrice)/\(period)"
    }
}
