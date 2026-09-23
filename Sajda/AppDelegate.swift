// MARK: - GANTI SELURUH FILE: AppDelegate.swift (VERSI FINAL DENGAN KONTROL PENUH)

import SwiftUI
import Combine
import NavigationStack
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject, NSWindowDelegate, UNUserNotificationCenterDelegate {
    let vm = PrayerTimeViewModel()
    let languageManager = LanguageManager()
    
    var menuBarExtra: FluidMenuBarExtra?
    private var cancellables = Set<AnyCancellable>()
    private var stopAdhanMenuItem: NSMenuItem?
    @AppStorage("showOnboardingAtLaunch") private var showOnboardingAtLaunch = true
    
    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Bundle.setLanguage(languageManager.language)

        UNUserNotificationCenter.current().delegate = self

        setupMenuBar()
        vm.startLocationProcess()

        vm.$menuTitle.debounce(for: .milliseconds(100), scheduler: RunLoop.main).sink { [weak self] newTitle in self?.menuBarExtra?.updateTitle(to: newTitle) }.store(in: &cancellables)
        vm.$isPrayerImminent.sink { [weak self] _ in self?.updateMenuBarUrgentAppearance() }.store(in: &cancellables)
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification).debounce(for: .milliseconds(50), scheduler: RunLoop.main).sink { [weak self] _ in
            self?.updateIconForMode(self?.vm.menuBarTextMode ?? .iconExactTime)
            self?.updateMenuBarUrgentAppearance()
        }.store(in: &cancellables)
    
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
    
    private func setupMenuBar() {
        let showInDock = UserDefaults.standard.bool(forKey: "showInDock")
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
        
        self.menuBarExtra = FluidMenuBarExtra(title: vm.menuTitle.string, systemImage: "moon.zzz.fill") {
            LanguageManagerView(manager: self.languageManager) {
                ContentView()
                    .environmentObject(self.vm)
                    .environmentObject(NavigationModel())
            }
        }
        updateIconForMode(vm.menuBarTextMode)
        updateMenuBarUrgentAppearance()
        setupContextMenu()
    }
    
    private func setupContextMenu() {
        guard let button = menuBarExtra?.statusItem.button else { return }
        let menu = NSMenu()
        let welcomeItem = NSMenuItem(title: NSLocalizedString("Show Welcome Window", comment: ""), action: #selector(showOnboardingWindow), keyEquivalent: "")
        welcomeItem.target = self
        menu.addItem(welcomeItem)
        menu.addItem(NSMenuItem.separator())
        let stopAdhanItem = NSMenuItem(title: NSLocalizedString("Stop Adhan", comment: ""), action: #selector(stopAdhan), keyEquivalent: "")
        stopAdhanItem.target = self
        stopAdhanItem.isEnabled = false
        menu.addItem(stopAdhanItem)
        self.stopAdhanMenuItem = stopAdhanItem
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: NSLocalizedString("Quit Sajda Pro", comment: ""), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        button.menu = menu

        NotificationCenter.default.addObserver(self, selector: #selector(adhanDidStart(_:)), name: .adhanDidStart, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(adhanDidStop(_:)), name: .adhanDidStop, object: nil)
    }

    @objc private func adhanDidStart(_ notification: Notification) {
        stopAdhanMenuItem?.isEnabled = true
    }

    @objc private func adhanDidStop(_ notification: Notification) {
        stopAdhanMenuItem?.isEnabled = false
    }

    @objc private func stopAdhan() {
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
    
    private func updateIconForMode(_ mode: MenuBarTextMode) {
        // `mode` is now read from `vm` inside applyMenuBarIcon (kept for existing call sites).
        applyMenuBarIcon()
    }

    private func updateMenuBarUrgentAppearance() {
        // Re-tint the icon for the current imminent state without touching
        // `contentTintColor` (setting it breaks menu-bar vibrancy → black text).
        applyMenuBarIcon()
    }

    private func applyMenuBarIcon() {
        let mode = vm.menuBarTextMode
        let shouldShowIcon: Bool
        switch mode {
        case .hidden, .iconCountdown, .iconExactTime:
            shouldShowIcon = true
        case .countdown, .exactTime:
            shouldShowIcon = false
        }
        guard let button = menuBarExtra?.statusItem.button else { return }
        if shouldShowIcon {
            button.imagePosition = .imageLeading
            if vm.isPrayerImminent, let redIcon = tintedMenuBarIcon() {
                button.image = redIcon
            } else if let image = NSImage(named: "MenuBarMosque") {
                image.size = NSSize(width: 16, height: 16)
                image.isTemplate = true
                button.image = image
            } else {
                button.image = NSImage(systemSymbolName: "moon.zzz.fill", accessibilityDescription: "Sajda Pro")
                button.image?.isTemplate = true
            }
        } else {
            button.image = nil
        }
    }

    /// Builds a non-template, red-tinted copy of the mosque glyph so only the
    /// icon turns red when prayer is imminent. The title already carries its
    /// own red attributed-string color — `contentTintColor` is deliberately
    /// avoided because it kills menu-bar vibrancy (→ black text).
    private func tintedMenuBarIcon() -> NSImage? {
        let base: NSImage?
        if let mosque = NSImage(named: "MenuBarMosque") {
            base = mosque
        } else {
            base = NSImage(systemSymbolName: "moon.zzz.fill", accessibilityDescription: "Sajda Pro")
        }
        guard let base else { return nil }
        let size = NSSize(width: 16, height: 16)
        let tinted = NSImage(size: size)
        tinted.lockFocus()
        NSColor.systemRed.set()
        let rect = NSRect(origin: .zero, size: size)
        rect.fill()
        base.draw(in: rect, from: NSRect(origin: .zero, size: base.size), operation: .destinationIn, fraction: 1.0)
        tinted.unlockFocus()
        tinted.isTemplate = false
        return tinted
    }
}	
