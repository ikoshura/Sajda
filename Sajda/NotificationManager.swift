// MARK: - PASTIKAN FILE INI (NotificationManager.swift) BERISI KODE DI BAWAH INI.

import Foundation
import UserNotifications

struct NotificationManager {
    
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }
    
    static func scheduleNotifications(for prayerTimes: [String: Date], prayerOrder: [String], adhanSound: AdhanSound, customSoundPath: String) {
        cancelNotifications()
        
        for prayerName in prayerOrder {
            guard let prayerTime = prayerTimes[prayerName] else { continue }
            
            if prayerTime > Date() {
                let content = UNMutableNotificationContent()
                content.title = prayerName
                content.body = "It's time for the \(prayerName) prayer."
                
                switch adhanSound {
                case .none:
                    content.sound = nil
                case .defaultBeep:
                    content.sound = UNNotificationSound.default
                case .custom:
                    content.sound = nil // ViewModel akan memutar suara secara terpisah
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
    }
}
