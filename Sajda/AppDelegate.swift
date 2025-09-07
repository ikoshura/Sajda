// MARK: - GANTI SELURUH FILE: AppDelegate.swift (VERSI FINAL DENGAN KONTROL PENUH)

import SwiftUI
import Combine
import NavigationStack

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject, NSWindowDelegate {
    let vm = PrayerTimeViewModel()
    let languageManager = LanguageManager()
    
    var menuBarExtra: FluidMenuBarExtra?
    private var cancellables = Set<AnyCancellable>()
    @AppStorage("showOnboardingAtLaunch") private var showOnboardingAtLaunch = true
    
    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Bundle.setLanguage(languageManager.language)
        
        setupMenuBar()
        vm.startLocationProcess()

        vm.$menuTitle.debounce(for: .milliseconds(100), scheduler: RunLoop.main).sink { [weak self] newTitle in self?.menuBarExtra?.updateTitle(to: newTitle) }.store(in: &cancellables)
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification).debounce(for: .milliseconds(50), scheduler: RunLoop.main).sink { [weak self] _ in self?.updateIconForMode(self?.vm.menuBarTextMode ?? .countdown) }.store(in: &cancellables)
    
        if self.showOnboardingAtLaunch {
            self.showOnboardingWindow()
        }
        
        // --- PERBAIKAN UNTUK BUG WAKE-FROM-SLEEP ---
        // Menambahkan observer untuk mendeteksi saat Mac bangun dari mode sleep.
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(systemDidWake), name: NSWorkspace.didWakeNotification, object: nil)
        
        NSApp.run()
    }
    
    // --- FUNGSI BARU UNTUK MENANGANI WAKE-FROM-SLEEP ---
    // Fungsi ini dipanggil saat Mac bangun, memaksa pembaruan waktu shalat.
    @objc private func systemDidWake() {
        // Tunggu sebentar untuk memastikan koneksi jaringan sudah siap jika diperlukan
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.vm.updatePrayerTimes()
        }
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
        setupContextMenu()
    }
    
    private func setupContextMenu() {
        guard let button = menuBarExtra?.statusItem.button else { return }
        let menu = NSMenu()
        let welcomeItem = NSMenuItem(title: NSLocalizedString("Show Welcome Window", comment: ""), action: #selector(showOnboardingWindow), keyEquivalent: "")
        welcomeItem.target = self
        menu.addItem(welcomeItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: NSLocalizedString("Quit Sajda Pro", comment: ""), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        button.menu = menu
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
        sender.close()
        return false
    }
    
    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) == self.onboardingWindow {
            self.onboardingWindow = nil
        }
    }
    
    private func updateIconForMode(_ mode: MenuBarTextMode) {
        let isIconOnly = (mode == .hidden)
        if vm.useMinimalMenuBarText {
            menuBarExtra?.statusItem.button?.image = nil
        }
        else {
            menuBarExtra?.statusItem.button?.image = isIconOnly ? NSImage(systemSymbolName: "moon.zzz.fill", accessibilityDescription: "Sajda Pro") : nil
        }
    }
}	
