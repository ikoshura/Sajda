// MARK: - GANTI SELURUH FILE: Sajda/ContentView.swift

import SwiftUI
import NavigationStack

struct ContentView: View {
    static let id = "RootNavigationStack"
    
    @EnvironmentObject var vm: PrayerTimeViewModel
    @EnvironmentObject var navigationModel: NavigationModel
    @Environment(\.colorScheme) private var colorScheme

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
        // Accent Panel theme: flip the panel's colour scheme so primary/
        // secondary text, dividers, hovers and native controls re-derive
        // from their dark/light variants and stay balanced against the tint.
        // (The tint itself is painted at the window root — see
        // `AccentPanelTintOverlay` in FluidMenuBarExtraWindow — outside the
        // content's fixedSize, so it tracks the panel's animated resize
        // frame-by-frame instead of lagging a layout pass behind.) While the
        // theme is off the system scheme passes through unchanged.
        .environment(\.colorScheme, vm.accentPanelTheme ? vm.accentPanelColorScheme : colorScheme)
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
