// Salin dan tempel SELURUH kode ini ke dalam file SajdaApp.swift

import SwiftUI

@main
struct SajdaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { }
    }
}

// TAMBAHKAN EKSTENSI INI DI BAWAH
extension Notification.Name {
    /// Notifikasi yang disiarkan saat popover ditutup atau kehilangan fokus.
    static let popoverDidClose = Notification.Name("com.sajda.popoverDidClose")
}
