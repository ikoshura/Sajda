// Ganti seluruh kode di SajdaApp.swift dengan ini

import SwiftUI
import Adhan
import CoreLocation

@main
struct SajdaApp: App {
    @StateObject private var vm = PrayerTimeViewModel()

    var body: some Scene {
        MenuBarExtra {
            ContentView(vm: vm)
        } label: {
            // FIX: Logika tampilan yang lebih bersih dan kuat
            HStack(spacing: 4) {
                // Tampilkan teks HANYA jika bukan mode "Icon Only"
                if vm.menuBarStyle != .iconOnly {
                    Text(vm.menuTitle)
                }
                
                // Tampilkan ikon HANYA jika gaya yang dipilih memerlukannya
                if vm.menuBarStyle.showsIcon {
                    Image(systemName: "moon.zzz")
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
