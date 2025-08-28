// Buat file baru bernama NotificationManager.swift dan salin kode ini ke dalamnya

import Foundation
import UserNotifications

struct NotificationManager {
    
    // 1. Meminta izin kepada pengguna untuk mengirim notifikasi
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    // 2. Menjadwalkan notifikasi untuk semua waktu sholat
    static func scheduleNotifications(for prayerTimes: [String: Date], prayerOrder: [String]) {
        // Hapus dulu notifikasi lama agar tidak ada tumpukan
        cancelNotifications()
        
        for prayerName in prayerOrder {
            guard let prayerTime = prayerTimes[prayerName] else { continue }
            
            // Hanya jadwalkan notifikasi untuk waktu yang akan datang
            if prayerTime > Date() {
                let content = UNMutableNotificationContent()
                content.title = prayerName
                content.body = "It's time for the \(prayerName) prayer."
                content.sound = UNNotificationSound.default

                let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: prayerTime)
                let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

                let request = UNNotificationRequest(identifier: prayerName, content: content, trigger: trigger)
                
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("Error scheduling notification for \(prayerName): \(error.localizedDescription)")
                    } else {
                        print("Successfully scheduled notification for \(prayerName) at \(prayerTime)")
                    }
                }
            }
        }
    }
    
    // 3. Membatalkan semua notifikasi yang terjadwal
    static func cancelNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("All pending notifications cancelled.")
    }
}
