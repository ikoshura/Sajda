// MARK: - GANTI FILE: Sajda/PrayerTimerMonitor.swift
// Salin dan tempel SELURUH kode ini.

import SwiftUI
import Combine

class PrayerTimerMonitor {
    @AppStorage("isPrayerTimerEnabled") private var isEnabled: Bool = false
    @AppStorage("prayerTimerDuration") private var duration: Int = 5
    
    private var timer: Timer?

    init() {
        // --- PERBAIKAN: Gunakan cara standar untuk mendengarkan notifikasi dan perubahan pengaturan ---
        NotificationCenter.default.addObserver(self, selector: #selector(handlePrayerTimeUpdate), name: .prayerTimesUpdated, object: nil)
        
        // Memantau perubahan UserDefaults secara umum
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: UserDefaults.didChangeNotification, object: nil)
    }

    @objc private func handlePrayerTimeUpdate(notification: Notification) {
        rescheduleTimer(userInfo: notification.userInfo)
    }
    
    @objc private func settingsChanged() {
        // Panggil rescheduleTimer tanpa info, yang akan memaksa pembacaan ulang pengaturan
        rescheduleTimer()
    }
    
    private func rescheduleTimer(userInfo: [AnyHashable: Any]? = nil) {
        timer?.invalidate()

        guard isEnabled else {
            print("Prayer Timer is disabled. No timer will be scheduled.")
            return
        }
        
        // Jika dipicu oleh perubahan shalat, gunakan data baru
        if let info = userInfo,
           let prayerTimes = info["prayerTimes"] as? [String: Date],
           let _ = info["nextPrayerName"] as? String {
            
            // Temukan waktu shalat yang baru saja berlalu
            guard let prayerThatJustPassed = prayerTimes.values
                    .filter({ $0 < Date() })
                    .max() else { return }

            let triggerTime = prayerThatJustPassed.addingTimeInterval(TimeInterval(duration * 60))
            
            let timeUntilTrigger = triggerTime.timeIntervalSinceNow
            guard timeUntilTrigger > 0 else { return }
            
            print("Prayer Timer: Alert scheduled based on prayer time update. Firing in \(String(format: "%.1f", timeUntilTrigger / 60)) minutes.")

            timer = Timer.scheduledTimer(withTimeInterval: timeUntilTrigger, repeats: false) { _ in
                AlertWindowManager.shared.showAlert()
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
