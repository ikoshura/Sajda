// Salin dan tempel SELURUH kode ini ke dalam file AppDelegate.swift

import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let vm = PrayerTimeViewModel()
    private var menuBarExtra: FluidMenuBarExtra?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // KODE BARU: Atur visibilitas Dock SEBELUM hal lain
        let showInDock = UserDefaults.standard.bool(forKey: "showInDock")
        if !showInDock {
            // Sembunyikan dari Dock (perilaku default)
            NSApp.setActivationPolicy(.accessory)
        } else {
            // Tampilkan di Dock
            NSApp.setActivationPolicy(.regular)
        }
        
        setupMenuBar()
        
        vm.$menuTitle
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] newTitle in
                self?.menuBarExtra?.updateTitle(to: newTitle)
            }
            .store(in: &cancellables)
            
        vm.$menuBarStyle
            .dropFirst()
            .sink { [weak self] _ in
                self?.setupMenuBar()
            }
            .store(in: &cancellables)
    }
    
    private func setupMenuBar() {
        if vm.menuBarStyle.showsIcon {
            self.menuBarExtra = FluidMenuBarExtra(title: vm.menuTitle, systemImage: "moon.zzz") {
                ContentView().environmentObject(self.vm)
            }
        } else {
            self.menuBarExtra = FluidMenuBarExtra(title: vm.menuTitle) {
                ContentView().environmentObject(self.vm)
            }
        }
    }
}
