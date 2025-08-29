// Salin dan tempel seluruh kode ini ke dalam file SajdaApp.swift

import SwiftUI

@main
struct SajdaApp: App {
    // Gunakan AppDelegate untuk mengelola siklus hidup aplikasi
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Karena ini adalah aplikasi menu bar murni, kita tidak memerlukan scene utama.
        // Sebagai gantinya, kita gunakan "Settings" scene agar aplikasi tetap berjalan
        // saat semua jendela lain (seperti About) ditutup.
        Settings { }
    }
}

// AppDelegate adalah cara standar untuk mengelola aplikasi macOS
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Saat aplikasi selesai diluncurkan, buat item di status bar.
        PopoverController.shared.setupStatusItem()
    }
}
