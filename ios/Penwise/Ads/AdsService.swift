import AppTrackingTransparency
import Foundation
import GoogleMobileAds
import UIKit
import UserMessagingPlatform

/// Ads with Google AdMob, behind Google's consent form (EU/UK/Switzerland)
/// and Apple's tracking prompt.
///
/// - Premium users never see ads and the ad SDK is not started for them.
/// - Learners not confirmed as adults (`AppSettings.ageBand`) are treated as
///   minors: no tracking prompt, ads tagged as under the age of consent.
/// - Ads appear only on Home and the entry screen (`AdSlot`), never in a lesson.
///
/// Front end: call `start()` once the first screen is visible; read
/// `showsAds`; show a "Privacy choices" button when `privacyOptionsRequired`
/// and call `showPrivacyOptions()`.
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
            return (Bundle.main.object(forInfoDictionaryKey: key) as? String) ?? AdsService.testBannerUnit
            #endif
        }
    }

    /// Google's public test banner unit.
    nonisolated static let testBannerUnit = "ca-app-pub-3940256099942544/2435281174"

    /// The SDK is started and consent allows ads.
    @Published private(set) var isReady = false
    /// Show a "Privacy choices" button in Settings when true (EU/UK users).
    @Published private(set) var privacyOptionsRequired = false

    private var started = false

    private init() {}

    /// True when an ad may be shown now.
    var showsAds: Bool { isReady && !StoreService.shared.isPremium }

    /// True if the learner should be treated as a minor for ads.
    var treatAsMinor: Bool { AppSettings.shared.ageBand != .adult }

    /// Gathers consent and starts the ad SDK. Safe to call more than once.
    func start() async {
        guard !started, !StoreService.shared.isPremium else { return }
        started = true

        let parameters = RequestParameters()
        parameters.isTaggedForUnderAgeOfConsent = treatAsMinor
        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: parameters)
            if let root = AdsService.rootViewController() {
                try await ConsentForm.loadAndPresentIfRequired(from: root)
            }
        } catch {
            // Consent info could not be updated (offline): use what was stored last time.
        }
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        guard ConsentInformation.shared.canRequestAds else { return }

        if treatAsMinor {
            MobileAds.shared.requestConfiguration.tagForUnderAgeOfConsent = true
        } else if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }
        MobileAds.shared.start(completionHandler: nil)
        isReady = true
    }

    /// Lets the learner change their consent choices (required when
    /// `privacyOptionsRequired` is true).
    func showPrivacyOptions() async {
        guard let root = AdsService.rootViewController() else { return }
        try? await ConsentForm.presentPrivacyOptionsForm(from: root)
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    /// Clears stored consent (used when deleting all data).
    func resetConsent() {
        ConsentInformation.shared.reset()
        started = false
        isReady = false
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
