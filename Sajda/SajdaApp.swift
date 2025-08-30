// MARK: - GANTI FILE: Sajda/SajdaApp.swift
// Salin dan tempel SELURUH kode ini.

import SwiftUI

// --- PERBAIKAN: Pindahkan definisi global ke sini agar bisa diakses dari mana saja ---
extension Notification.Name {
    /// Notifikasi yang disiarkan saat popover ditutup atau kehilangan fokus.
    static let popoverDidClose = Notification.Name("com.sajda.popoverDidClose")
    
    /// Notifikasi yang disiarkan saat waktu shalat telah diperbarui.
    static let prayerTimesUpdated = Notification.Name("prayerTimesUpdated")
}

@main
struct SajdaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            OnboardingView()
                .environmentObject(appDelegate.vm)
        }
    }
}
