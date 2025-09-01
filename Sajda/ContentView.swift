// MARK: - GANTI SELURUH FILE: Sajda/ContentView.swift (HAPUS BLUR REDUNDAN)

import SwiftUI
import NavigationStack

struct ContentView: View {
    static let id = "RootNavigationStack"
    
    @EnvironmentObject var navigationModel: NavigationModel
    
    var body: some View {
        // HAPUS ZStack dan VisualEffectView dari sini.
        // Biarkan background blur ditangani oleh FluidMenuBarExtraWindow.
        NavigationStackView(Self.id) {
            MainView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .popoverDidClose)) { _ in
            if navigationModel.hasAlternativeViewShowing {
                navigationModel.hideView(Self.id, animation: nil)
            }
        }
    }
}
