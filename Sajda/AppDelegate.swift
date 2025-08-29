// Salin dan tempel SELURUH kode ini ke dalam file AppDelegate.swift

import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let vm = PrayerTimeViewModel()
    private var menuBarExtra: FluidMenuBarExtra?
    private var cancellables = Set<AnyCancellable>()

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
            
        // PERUBAHAN: Publisher sekarang mendengarkan perubahan mode teks
        vm.$menuBarTextMode
            .dropFirst()
            .sink { [weak self] newMode in
                self?.updateIconForMode(newMode)
            }
            .store(in: &cancellables)
    }
    
    private func setupMenuBar() {
        self.menuBarExtra = FluidMenuBarExtra(title: vm.menuTitle, systemImage: "moon.zzz.fill") {
            ContentView().environmentObject(self.vm)
        }
        // Atur visibilitas ikon awal berdasarkan mode yang tersimpan
        updateIconForMode(vm.menuBarTextMode)
    }
    
    // PERUBAHAN: Fungsi ini sekarang menentukan visibilitas ikon berdasarkan mode
    private func updateIconForMode(_ mode: MenuBarTextMode) {
        // Ikon hanya terlihat jika mode adalah .hidden (yaitu, "Icon Only")
        let isVisible = (mode == .hidden)
        
        if isVisible {
            menuBarExtra?.statusItem.button?.image = NSImage(systemSymbolName: "moon.zzz.fill", accessibilityDescription: "Sajda")
        } else {
            menuBarExtra?.statusItem.button?.image = nil
        }
    }
}
