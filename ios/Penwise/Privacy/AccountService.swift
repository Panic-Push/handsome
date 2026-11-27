import Foundation
import UserNotifications

@MainActor
enum AccountService {
    static func deleteAllData() {
        AppSettings.shared.ageBand = .unknown
        AppSettings.shared.style = .print
        AppSettings.shared.size = .standard
        AppSettings.shared.handedness = .right
        AppSettings.shared.pencilOnly = true
        AppSettings.shared.showAdPlaceholders = false
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        ProgressStore.shared.reset()
        JourneyStore.shared.reset()
        PlanStore.shared.reset()
        AdsService.shared.resetConsent()

        if let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
        }

        let fm = FileManager.default
        if let items = try? fm.contentsOfDirectory(at: FileStore.documents, includingPropertiesForKeys: nil) {
            for item in items { try? fm.removeItem(at: item) }
        }
    }
}
