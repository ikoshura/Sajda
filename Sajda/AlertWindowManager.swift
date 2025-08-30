// MARK: - GANTI FILE: Sajda/AlertWindowManager.swift
// Salin dan tempel SELURUH kode ini.

import SwiftUI

class AlertWindowManager {
    static let shared = AlertWindowManager()
    private var window: NSWindow?

    private init() {}

    func showAlert() {
        guard window == nil else { return }

        let alertView = PrayerTimerAlertView {
            self.closeAlert()
        }
        
        let hostingController = NSHostingController(rootView: alertView)
        let newWindow = NSWindow(contentViewController: hostingController)
        
        // --- PERBAIKAN UTAMA DI BAWAH INI ---
        
        // 1. Set style mask dengan benar
        newWindow.styleMask = .borderless
        
        // 2. Set level jendela agar tampil di atas
        newWindow.level = .floating
        
        // 3. Buat latar belakang jendela transparan (agar blur dari VisualEffectView terlihat)
        newWindow.isOpaque = false
        // Gunakan NSColor.clear, bukan Color.clear, karena ini adalah properti AppKit
        newWindow.backgroundColor = NSColor.clear
        
        // --- Akhir Perbaikan ---
        
        newWindow.center()
        
        self.window = newWindow
        self.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeAlert() {
        window?.close()
        window = nil
    }
}
