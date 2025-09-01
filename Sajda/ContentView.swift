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
