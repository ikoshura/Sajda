// MARK: - Sajda/SajdaControlCenterMenu.swift
//
// Control Center revamp root for the SwiftUI `MenuBarExtra` scene.
//
// `MacControlCenterMenu` mimics the look, feel, and resize animations of
// macOS Control Center menus. The existing Sajda pages (MainView, Settings,
// About, sub-pages — all NavigationStack-based) are hosted verbatim inside it
// via `NavigationStackView(ContentView.id)`, so every push/pop keeps working
// unchanged and the menu's height-resize animation carries the transitions.
// A small footer section adds Stop Adhan (while playing) as a first-class
// menu command — MainView's own one-line footer already covers Quit /
// About / Settings.

import SwiftUI
import NavigationStack
import MacControlCenterUI

struct SajdaControlCenterMenu: View {
    @Binding var isMenuPresented: Bool

    @EnvironmentObject var vm: PrayerTimeViewModel
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var navigationModel: NavigationModel
    @EnvironmentObject var appDelegate: AppDelegate

    var body: some View {
        LanguageManagerView(manager: languageManager) {
            MacControlCenterMenu(isPresented: $isMenuPresented, width: .custom(vm.panelWidth(base: vm.useCompactLayout ? 220 : 260))) {
                SajdaMenuContainer {
                    NavigationStackView(ContentView.id) {
                        MainView()
                    }
                }
                // MainView's footer already covers About / Settings / Quit
                // (single one-line row). This only adds Stop Adhan while
                // playing, which otherwise has no in-panel home.
                if vm.isAdhanPlaying {
                    MenuSection(divider: true) {
                        MenuCommand(dismissesMenu: false) { appDelegate.stopAdhanFromMenu() } label: {
                            HStack { Image(systemName: "stop.circle"); Text("Stop Adhan"); Spacer() }
                        }
                    }
                }
            }
            .environmentObject(vm)
            .environmentObject(navigationModel)
            .environment(\.panelFontScale, vm.panelTextSize.fontScale)
            .environment(\.panelBoldText, vm.accessibilityBoldText)
            .font(.system(size: PanelTextSize.baseBodyPointSize * vm.panelTextSize.fontScale, weight: vm.accessibilityBoldText ? .semibold : .regular))
            .accentPanelScheme(vm)
            .background { AccentPanelTintOverlay().ignoresSafeArea() }
            .transaction { transaction in
                if vm.animationType == .none { transaction.disablesAnimations = true }
            }
        }
        .onAppear {
            // This content view is torn down while the panel is closed, so the
            // close handler cannot be relied upon to reset navigation — every
            // fresh open starts from MainView instead of reviving the page
            // that was showing when the panel went away.
            resetNavigationIfNeeded()
        }
        .onChange(of: isMenuPresented) { presented in
            resetNavigationIfNeeded()
            if !presented {
                NotificationCenter.default.post(name: .popoverDidClose, object: nil)
            } else {
                NotificationCenter.default.post(name: .popoverDidOpen, object: nil)
            }
        }
    }

    /// Pops every pushed page (Settings, About, their sub-pages) back to
    /// MainView. Safe to call when nothing is pushed: the model's node list is
    /// dropped on the next push, so the stale identifiers can't collide.
    private func resetNavigationIfNeeded() {
        guard navigationModel.hasAlternativeViewShowing else { return }
        navigationModel.hideView(ContentView.id, animation: nil)
        // Panel closed/torn down: no exit animation to protect, so the next
        // open enters Settings on Display.
        vm.settingsSelectedTab = "display"
    }
}

// MARK: - Accent panel scheme helper

private struct AccentPanelSchemeModifier: ViewModifier {
    @ObservedObject var vm: PrayerTimeViewModel
    // The system scheme underneath, so the modifier's view identity stays
    // stable whether the theme is on or off. (A conditional
    // `if vm.accentPanelTheme { content.environment(...) } else { content }`
    // swaps view types on toggle, which recreates SettingsView and wipes its
    // @State — that's what used to collapse the open accordion whenever the
    // Accent Panel switch was flipped.)
    @Environment(\.colorScheme) private var systemScheme

    func body(content: Content) -> some View {
        content.environment(\.colorScheme, vm.accentPanelTheme ? vm.accentPanelColorScheme : systemScheme)
    }
}

extension View {
    fileprivate func accentPanelScheme(_ vm: PrayerTimeViewModel) -> some View {
        modifier(AccentPanelSchemeModifier(vm: vm))
    }
}

// MARK: - Sajda menu container

/// Pass-through `MacControlCenterMenuItem` so the panel content is hosted
/// without `PaddedMenuItem`'s 14pt horizontal + 4pt vertical padding and
/// without the section's divider/label chrome. Sajda pages already draw
/// their own 12pt gutters, so this removes the double margin on every side
/// and lets the compact width actually read as compact.
private struct SajdaMenuContainer<Content: View>: View, MacControlCenterMenuItem {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View { content }
}
