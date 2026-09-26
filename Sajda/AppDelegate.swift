// MARK: - AppDelegate.swift (Control Center revamp)
//
// Lifecycle + data owner for the SwiftUI `MenuBarExtra` scene in
// SajdaMenuBarApp.swift. The menu bar UI itself is now SwiftUI-native
// (`SajdaControlCenterMenu` inside `MacControlCenterMenu`); this delegate keeps
// the AppKit-side responsibilities: prayer engine startup, notifications,
// onboarding window, wake-from-sleep, and in-menu actions (welcome / stop
// adhan) driven from SwiftUI instead of an NSStatusItem context menu.

import SwiftUI
import Combine
import NavigationStack
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject, NSWindowDelegate, UNUserNotificationCenterDelegate {
    let vm = PrayerTimeViewModel()
    let languageManager = LanguageManager()
    /// Shared navigation stack for the menu pages (Main <-> Settings <-> sub-pages).
    /// Owned here so it survives menu open/close cycles; injected into the
    /// `MenuBarExtra` scene from `SajdaMenuBarApp`.
    let navigationModel = NavigationModel()

    /// Mirrors `AdhanAudioPlayer` state so the menu can enable/disable
    /// "Stop Adhan" without an NSMenuItem.
    @Published var canStopAdhan = false
    private var cancellables = Set<AnyCancellable>()
    @AppStorage("showOnboardingAtLaunch") private var showOnboardingAtLaunch = true

    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Bundle.setLanguage(languageManager.language)

        UNUserNotificationCenter.current().delegate = self

        let showInDock = UserDefaults.standard.bool(forKey: "showInDock")
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)

        vm.startLocationProcess()
        UpdateChecker.shared.checkIfDue()

        NotificationCenter.default.addObserver(self, selector: #selector(adhanDidStart(_:)), name: .adhanDidStart, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(adhanDidStop(_:)), name: .adhanDidStop, object: nil)

        if self.showOnboardingAtLaunch {
            self.showOnboardingWindow()
        }
        
        // --- PERBAIKAN UNTUK BUG WAKE-FROM-SLEEP ---
        // Menambahkan observer untuk mendeteksi saat Mac bangun dari mode sleep.
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(systemDidWake), name: NSWorkspace.didWakeNotification, object: nil)
    }
    
    // --- FUNGSI BARU UNTUK MENANGANI WAKE-FROM-SLEEP ---
    // Fungsi ini dipanggil saat Mac bangun, memaksa pembaruan waktu shalat.
    @objc private func systemDidWake() {
        // Tunggu sebentar untuk memastikan koneksi jaringan sudah siap jika diperlukan
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.vm.updatePrayerTimes()
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Timer-based playback in PrayerTimeViewModel already handles audio.
        // This delegate fires only when the popover is open (app is "foreground").
        // We still play here as a safety net so audio is not missed if the timer
        // fires while the user is interacting with the menu.
        let prayerName = notification.request.identifier
        let config = vm.soundConfig(for: prayerName)
        AdhanAudioPlayer.shared.play(adhanType: config.adhanType, customFilePath: config.customFilePath, prayerName: prayerName)
        completionHandler([.banner])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // User clicked the notification — ensure audio plays even if the timer missed.
        let prayerName = response.notification.request.identifier
        let config = vm.soundConfig(for: prayerName)
        AdhanAudioPlayer.shared.play(adhanType: config.adhanType, customFilePath: config.customFilePath, prayerName: prayerName)
        completionHandler()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    @objc private func adhanDidStart(_ notification: Notification) {
        DispatchQueue.main.async { self.canStopAdhan = true }
    }

    @objc private func adhanDidStop(_ notification: Notification) {
        DispatchQueue.main.async { self.canStopAdhan = false }
    }

    /// In-menu action (replaces the old NSStatusItem context menu item).
    func stopAdhanFromMenu() {
        AdhanAudioPlayer.shared.stop()
    }

    @objc func showOnboardingWindow() {
        if let existingWindow = onboardingWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let onboardingView = LanguageManagerView(manager: languageManager) {
            OnboardingView()
                .environmentObject(vm)
                .environmentObject(NavigationModel())
        }

        let hostingController = NSHostingController(rootView: onboardingView)
        let window = NSWindow(contentViewController: hostingController)
        
        window.setContentSize(NSSize(width: 380, height: 490))
        window.styleMask.remove(.resizable)
        window.center()
        
        window.title = "Sajda Pro Welcome"
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true
        
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        self.onboardingWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return true
    }
    
    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) == self.onboardingWindow {
            self.onboardingWindow = nil
        }
}
}
