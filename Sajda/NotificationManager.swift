import Foundation
import AppKit
import UserNotifications

struct NotificationManager {

    /// Requests banner/badge/sound authorization. The completion is hopped to
    /// the main queue so callers can touch UI state directly. The adhan itself
    /// is played by the app (see `AdhanAudioPlayer`), but without this the
    /// banner never appears at all.
    static func requestPermission(_ completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async { completion?(granted) }
        }
    }

    /// Current authorization status on the main queue — drives the Allow /
    /// Open System Settings rows in onboarding and Settings.
    static func authorizationStatus(_ completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let status = settings.authorizationStatus
            DispatchQueue.main.async { completion(status) }
        }
    }

    /// Deep-links to the Notifications section of System Settings, where a
    /// denied prompt can only be undone (macOS never re-prompts after deny).
    static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }

    /// The prayers of `prayerOrder` that are still in the future at `now`,
    /// keyed by prayer name. Shared by the notification scheduler and the
    /// app-side adhan triggers so both always cover exactly the same prayers —
    /// a prayer already past must never be scheduled, or launching the app
    /// after it would fire its adhan on the spot.
    static func pendingPrayerTimes(for prayerTimes: [String: Date],
                                   prayerOrder: [String],
                                   now: Date = Date()) -> [String: Date] {
        var pending: [String: Date] = [:]
        for prayerName in prayerOrder {
            guard let prayerTime = prayerTimes[prayerName], prayerTime > now else { continue }
            pending[prayerName] = prayerTime
        }
        return pending
    }

    static func scheduleNotifications(for prayerTimes: [String: Date], prayerOrder: [String], prayerConfigs: [String: PrayerSoundConfig]) {
        cancelNotifications()

        for (prayerName, prayerTime) in pendingPrayerTimes(for: prayerTimes, prayerOrder: prayerOrder) {
            let content = UNMutableNotificationContent()
            content.title = NSLocalizedString(prayerName, comment: "")
            content.body = String(format: NSLocalizedString("notification_body", comment: ""), NSLocalizedString(prayerName, comment: ""))

            // Sound is played via the app-side countdown timer / adhan triggers
            // (NSSound/AVAudioPlayer, no duration limit).
            // Notification payload must stay silent — long CAF files (>30s) are rejected
            // by UNNotificationSound, causing the system to play nothing.
            content.sound = nil

            let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: prayerTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            let request = UNNotificationRequest(identifier: prayerName, content: content, trigger: trigger)

            UNUserNotificationCenter.current().add(request)
        }
    }

    static func cancelNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}
