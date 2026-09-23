// MARK: - GANTI SELURUH FILE: Sajda/ContentView.swift

import SwiftUI
import NavigationStack

struct ContentView: View {
    static let id = "RootNavigationStack"
    
    @EnvironmentObject var vm: PrayerTimeViewModel
    @EnvironmentObject var navigationModel: NavigationModel
    
    var body: some View {
        NavigationStackView(Self.id) {
            MainView()
        }
        // Menskalakan seluruh teks di dalam panel sesuai preset ukuran teks.
        // macOS tidak mendukung Dynamic Type, jadi skala diterapkan manual:
        // faktor skala dibaca modifier `scaledFont`, sementara .font root
        // menangani teks tanpa gaya eksplisit (toggle, tombol, dsb).
        .environment(\.panelFontScale, vm.panelTextSize.fontScale)
        .environment(\.panelBoldText, vm.accessibilityBoldText)
        .font(.system(size: PanelTextSize.baseBodyPointSize * vm.panelTextSize.fontScale, weight: vm.accessibilityBoldText ? .semibold : .regular))
        // --- PERBAIKAN DI SINI ---
        // Menggunakan properti animationType yang baru, bukan disableAnimations yang sudah dihapus.
        .transaction { transaction in
            if vm.animationType == .none {
                transaction.disablesAnimations = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .popoverDidClose)) { _ in
            if navigationModel.hasAlternativeViewShowing {
                navigationModel.hideView(Self.id, animation: nil)
            }
        }
    }
}
