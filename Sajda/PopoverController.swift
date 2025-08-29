// Salin dan tempel seluruh kode ini ke dalam file PopoverController.swift

import SwiftUI

class PopoverController {
    static let shared = PopoverController()
    private var popover: NSPopover?
    private var statusBarItem: NSStatusItem?

    func setupStatusItem() {
        guard statusBarItem == nil else { return }
        
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusBarItem?.button {
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        // Buat popover
        let popover = NSPopover()
        popover.behavior = .transient // Akan menutup saat klik di luar
        popover.animates = true // Mengaktifkan animasi
        
        // Atur konten popover dengan SwiftUI View kita
        // Instance ViewModel dibuat sekali di sini dan diteruskan ke ContentView
        let vm = PrayerTimeViewModel()
        popover.contentViewController = NSHostingController(rootView: ContentView(vm: vm))
        self.popover = popover
    }

    @objc func togglePopover() {
        guard let popover = self.popover, let button = statusBarItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    // Fungsi ini sekarang bisa menampilkan teks, ikon, atau keduanya
    func updateStatusItemTitle(with text: String, showIcon: Bool) {
        if let button = statusBarItem?.button {
            button.title = text
            if showIcon {
                button.image = NSImage(systemSymbolName: "moon.zzz", accessibilityDescription: "Sajda")
                button.imagePosition = .imageLeading // Ikon di sebelah kiri teks
            } else {
                button.image = nil
            }
        }
    }
}
