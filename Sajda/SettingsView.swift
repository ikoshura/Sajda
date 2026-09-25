// MARK: - GANTI SELURUH FILE: SettingsView.swift

import SwiftUI
import NavigationStack

struct SettingsView: View {
    static let id = "SettingsNavigationStack"

    @EnvironmentObject var vm: PrayerTimeViewModel
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var navigationModel: NavigationModel
    
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage(UpdateChecker.autoCheckKey) private var autoCheckForUpdates = false
    @State private var isHeaderHovering = false
    @State private var isCalcHovering = false
    @State private var isAdhanHovering = false
    @State private var isAccessibilityHovering = false
    @State private var isSyncingLaunchAtLogin = false

    private var viewWidth: CGFloat {
        return vm.panelWidth(base: vm.useCompactLayout ? 220 : 260)
    }

    var body: some View {
        NavigationStackView(Self.id) {
            VStack(alignment: .leading, spacing: 6) {
                Button(action: {
                    navigationModel.hideView(ContentView.id, animation: vm.backwardAnimation())
                }) {
                    HStack {
                        Image(systemName: vm.backChevron).scaledFont(.body, weight: .semibold)
                        Text("Settings").scaledFont(.body, weight: .bold)
                        Spacer()
                    }
                    .padding(.vertical, 5).padding(.horizontal, 8)
                    .liquidHover(isHeaderHovering)
                }.buttonStyle(.plain).padding(.horizontal, 5).padding(.top, 2).onHover { hovering in isHeaderHovering = hovering }
                
                Rectangle()
                    .fill(Color("DividerColor"))
                    .frame(height: 0.5)
                    .padding(.horizontal, 12)

                VStack(alignment: .leading, spacing: 12) {
                    Text("System").scaledFont(.caption).foregroundColor(Color("SecondaryTextColor"))
                    StyledToggle(label: "Run at Login", isOn: $launchAtLogin)
                    StyledToggle(label: "Check for Updates Automatically", isOn: $autoCheckForUpdates)
                        .onChange(of: autoCheckForUpdates) { enabled in
                            if enabled { UpdateChecker.shared.checkIfDue() }
                        }

                    HStack {
                        Text("Animation Style").scaledFont(.subheadline)
                        Spacer()
                        ScaledMenuPicker(selection: $vm.animationType, options: AnimationType.allCases) { NSLocalizedString($0.rawValue, comment: "") }
                    }

                    Text("Display").scaledFont(.caption).foregroundColor(Color("SecondaryTextColor"))
                    HStack { Text("Language").scaledFont(.subheadline); Spacer(); ScaledMenuPicker(selection: $languageManager.language, options: ["en", "ar", "id", "es", "fr", "de", "ja", "zh-Hans", "ko"]) { code in ["en": "English", "ar": "العربية", "id": "Indonesia", "es": "Español", "fr": "Français", "de": "Deutsch", "ja": "日本語", "zh-Hans": "简体中文", "ko": "한국어"][code] ?? code } }
                    HStack { Text("Menu Bar Style").scaledFont(.subheadline); Spacer(); ScaledMenuPicker(selection: $vm.menuBarTextMode, options: MenuBarTextMode.allCases) { NSLocalizedString($0.rawValue, comment: "") } }
                    StyledToggle(label: "Compact View", isOn: $vm.useCompactLayout)
                    StyledToggle(label: "24-Hour Time", isOn: $vm.use24HourFormat)
                    StyledToggle(label: "Minimal Menu Bar", isOn: $vm.useMinimalMenuBarText).disabled(vm.menuBarTextMode == .hidden)
                    StyledToggle(label: "Accent Color", isOn: $vm.useAccentColor)
                    StyledToggle(label: "Glass Highlight", isOn: $vm.useGlassPrayerHighlight)
                    StyledToggle(label: "Show Sunnah Prayers", isOn: $vm.showSunnahPrayers)
                }
                .controlSize(.small)
                .padding(.horizontal, 16).padding(.top, 8)

                Spacer(minLength: 0)

                Rectangle().fill(Color("DividerColor")).frame(height: 1).padding(.horizontal, 12)

                VStack(alignment: .leading, spacing: 0) {
                    Button(action: { navigationModel.showView(Self.id, animation: vm.forwardAnimation()) { LocationAndCalcSettingsView() } }) {
                        HStack { Text("Calculation & Location").scaledFont(.subheadline); Spacer(); Image(systemName: vm.forwardChevron).scaledFont(.caption, weight: .bold).foregroundColor(.secondary) }
                        .padding(.vertical, 5).padding(.horizontal, 8).liquidHover(isCalcHovering)
                    }.buttonStyle(.plain).padding(.horizontal, 5).onHover { hovering in isCalcHovering = hovering }

                    Button(action: { navigationModel.showView(Self.id, animation: vm.forwardAnimation()) { SystemAndNotificationsSettingsView() } }) {
                        HStack { Text("Adhan Sound").scaledFont(.subheadline); Spacer(); Image(systemName: vm.forwardChevron).scaledFont(.caption, weight: .bold).foregroundColor(.secondary) }
                        .padding(.vertical, 5).padding(.horizontal, 8).liquidHover(isAdhanHovering)
                    }.buttonStyle(.plain).padding(.horizontal, 5).onHover { hovering in isAdhanHovering = hovering }

                    Button(action: { navigationModel.showView(Self.id, animation: vm.forwardAnimation()) { AccessibilitySettingsView() } }) {
                        HStack { Text("Accessibility").scaledFont(.subheadline); Spacer(); Image(systemName: vm.forwardChevron).scaledFont(.caption, weight: .bold).foregroundColor(.secondary) }
                        .padding(.vertical, 5).padding(.horizontal, 8).liquidHover(isAccessibilityHovering)
                    }.buttonStyle(.plain).padding(.horizontal, 5).onHover { hovering in isAccessibilityHovering = hovering }
                }
            }
            .padding(.vertical, 8)
            .frame(width: viewWidth)
            .onAppear(perform: syncLaunchAtLoginState)
            .onChange(of: launchAtLogin) { newValue in
                guard !isSyncingLaunchAtLogin else { return }
                StartupManager.toggleLaunchAtLogin(isEnabled: newValue)
            }
        }
    }

    private func syncLaunchAtLoginState() {
        let currentSystemState = StartupManager.isLaunchAtLoginEnabled
        guard launchAtLogin != currentSystemState else { return }

        isSyncingLaunchAtLogin = true
        launchAtLogin = currentSystemState
        DispatchQueue.main.async {
            isSyncingLaunchAtLogin = false
        }
    }
}
