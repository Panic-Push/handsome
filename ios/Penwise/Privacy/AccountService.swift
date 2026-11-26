import Foundation

/// Deleting the learner's data. Everything Penwise stores lives on this iPad
/// (nothing is sent to a Penwise server), so deleting it here deletes it
/// everywhere.
///
/// Front end: Settings needs a "Delete all my data" button (with a
/// confirmation) that calls `deleteAllData()`. Apple requires in-app account
/// deletion for apps that offer Sign in with Apple; this covers the data
/// side. Also link to https://appleid.apple.com so learners can stop using
/// Apple sign-in with Penwise (see docs/app-store/review-notes.md).
@MainActor
enum AccountService {
    /// Keys the Sign in with Apple section stores (see SettingsView).
    static let appleAccountKeys = ["penwise.account.appleUser", "penwise.account.email", "penwise.account.name"]

    /// Erases progress, journeys, plan, reports, settings, the Apple sign-in
    /// details, recorded samples and ad consent. Purchases are kept by the
    /// App Store and come back with Restore.
    static func deleteAllData() {
        ProgressStore.shared.reset()
        JourneyStore.shared.reset()
        PlanStore.shared.reset()
        AdsService.shared.resetConsent()

        if let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
        }
        for key in appleAccountKeys { UserDefaults.standard.removeObject(forKey: key) }

        let fm = FileManager.default
        if let items = try? fm.contentsOfDirectory(at: FileStore.documents, includingPropertiesForKeys: nil) {
            for item in items { try? fm.removeItem(at: item) }
        }
    }
}
