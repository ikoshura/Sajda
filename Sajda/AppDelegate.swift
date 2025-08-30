// MARK: - GANTI FILE: Sajda/AppDelegate.swift
// Salin dan tempel SELURUH kode ini untuk memastikan logikanya benar.

import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let vm = PrayerTimeViewModel()
    private var menuBarExtra: FluidMenuBarExtra?
    private var cancellables = Set<AnyCancellable>()
    
    // 1. Mengambil nilai toggle dari penyimpanan permanen. Defaultnya adalah `true`.
    @AppStorage("showOnboardingAtLaunch") private var showOnboardingAtLaunch = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        let showInDock = UserDefaults.standard.bool(forKey: "showInDock")
        if !showInDock {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
        }
        
        setupMenuBar()
        
        vm.$menuTitle
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] newTitle in
                self?.menuBarExtra?.updateTitle(to: newTitle)
            }
            .store(in: &cancellables)
            
        vm.$menuBarTextMode
            .dropFirst()
            .sink { [weak self] newMode in
                self?.updateIconForMode(newMode)
            }
            .store(in: &cancellables)
            
        // 2. Setiap kali aplikasi launch, kode ini akan memeriksa nilai `showOnboardingAtLaunch`.
        // Jika `true`, jendela akan ditampilkan. Jika pengguna mematikannya, nilai ini akan `false`
        // pada saat launch berikutnya, dan jendela tidak akan muncul.
        DispatchQueue.main.async {
            if self.showOnboardingAtLaunch {
                self.showOnboardingWindow()
            }
        }
    }
    
    private func setupMenuBar() {
        self.menuBarExtra = FluidMenuBarExtra(title: vm.menuTitle, systemImage: "moon.zzz.fill") {
            ContentView().environmentObject(self.vm)
        }
        updateIconForMode(vm.menuBarTextMode)
        
        setupContextMenu()
    }
    
    private func setupContextMenu() {
        guard let button = menuBarExtra?.statusItem.button else { return }
        
        let menu = NSMenu()
        
        let welcomeItem = NSMenuItem(title: "Show Welcome Window", action: #selector(showOnboardingWindow), keyEquivalent: "")
        welcomeItem.target = self
        menu.addItem(welcomeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit Sajda", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        button.menu = menu
    }

    @objc func showOnboardingWindow() {
        if #available(macOS 13, *) {
             NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
             NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func updateIconForMode(_ mode: MenuBarTextMode) {
        let isVisible = (mode == .hidden)
        
        if isVisible {
            menuBarExtra?.statusItem.button?.image = NSImage(systemSymbolName: "moon.zzz.fill", accessibilityDescription: "Sajda")
        } else {
            menuBarExtra?.statusItem.button?.image = nil
        }
    }
}
