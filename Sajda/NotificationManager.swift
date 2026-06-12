import Foundation
import UserNotifications

struct NotificationManager {

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    static func scheduleNotifications(for prayerTimes: [String: Date], prayerOrder: [String], prayerConfigs: [String: PrayerSoundConfig]) {
        cancelNotifications()

        for prayerName in prayerOrder {
            guard let prayerTime = prayerTimes[prayerName] else { continue }

            if prayerTime > Date() {
                let content = UNMutableNotificationContent()
                content.title = NSLocalizedString(prayerName, comment: "")
                content.body = String(format: NSLocalizedString("notification_body", comment: ""), NSLocalizedString(prayerName, comment: ""))
                
                let config = prayerConfigs[prayerName]
                let adhanSound = config?.adhanType ?? .defaultBeep
                switch adhanSound {
                case .none:
                    content.sound = nil
                case .defaultBeep:
                    content.sound = UNNotificationSound.default
                case .custom:
                    content.sound = UNNotificationSound.default
                default:
                    if let fileName = config?.adhanType.bundleFileName {
                        content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: fileName + ".caf"))
                    } else {
                        content.sound = UNNotificationSound.default
                    }
                }

                let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: prayerTime)
                let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
                let request = UNNotificationRequest(identifier: prayerName, content: content, trigger: trigger)

                UNUserNotificationCenter.current().add(request)
            }
        }
    }

    static func cancelNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}
