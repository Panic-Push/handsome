import AppTrackingTransparency
import Foundation
import GoogleMobileAds
import UIKit
import UserMessagingPlatform

/// Advertising is available only to confirmed adult learners on the free plan.
@MainActor
final class AdsService: ObservableObject {
    static let shared = AdsService()

    enum Placement {
        case homeBanner
        case entry

        /// Real unit ids come from Info.plist; debug builds always use Google's test ids.
        var unitID: String {
            #if DEBUG
            return AdsService.testBannerUnit
            #else
            let key = self == .homeBanner ? "PenwiseAdUnitHomeBanner" : "PenwiseAdUnitEntry"
            return (Bundle.main.object(forInfoDictionaryKey: key) as? String) ?? ""
            #endif
        }
    }

    /// Google's public test banner unit.
    nonisolated static let testBannerUnit = "ca-app-pub-3940256099942544/2435281174"

    /// The SDK is started and consent allows ads.
    @Published private(set) var isReady = false
    /// Show a "Privacy choices" button in Settings when true (EU/UK users).
    @Published private(set) var privacyOptionsRequired = false

    private var loading = false
    private var generation = 0

    var eligible: Bool {
        AppSettings.shared.ageBand == .adult && StoreService.shared.checkedEntitlements && !StoreService.shared.isPremium
    }

    var showsAds: Bool { eligible && isReady }

    func start() async {
        guard eligible, !loading, !isReady else { return }
        let token = generation
        loading = true
        defer { if token == generation { loading = false } }
        let parameters = RequestParameters()
        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: parameters)
            guard eligible, token == generation, let root = Self.rootViewController() else { return }
            try await ConsentForm.loadAndPresentIfRequired(from: root)
        } catch {
            return
        }
        guard eligible, token == generation else { return }
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        guard ConsentInformation.shared.canRequestAds else { return }
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }
        guard eligible, token == generation else { return }
        _ = await MobileAds.shared.start()
        if eligible, token == generation { isReady = ConsentInformation.shared.canRequestAds }
    }

    func showPrivacyOptions() async {
        guard eligible, let root = Self.rootViewController() else { return }
        isReady = false
        try? await ConsentForm.presentPrivacyOptionsForm(from: root)
        guard eligible else { return }
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        if ConsentInformation.shared.canRequestAds { await start() }
    }

    func resetConsent() {
        generation += 1
        loading = false
        isReady = false
        privacyOptionsRequired = false
        ConsentInformation.shared.reset()
    }

    static func rootViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ??
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
