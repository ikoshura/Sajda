// MARK: - GANTI SELURUH FILE: SettingsView.swift

import SwiftUI
import NavigationStack

struct SettingsView: View {
    static let id = "SettingsNavigationStack"

    @EnvironmentObject var vm: PrayerTimeViewModel
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var navigationModel: NavigationModel
    
    @State private var isHeaderHovering = false
    @State private var isCalcHovering = false
    @State private var isNotifHovering = false

    private var viewWidth: CGFloat {
        return vm.useCompactLayout ? 220 : 260
    }

    var body: some View {
        NavigationStackView(Self.id) {
            VStack(alignment: .leading, spacing: 6) {
                Button(action: {
                    navigationModel.hideView(ContentView.id, animation: vm.backwardAnimation())
                }) {
                    HStack {
                        Image(systemName: "chevron.left").font(.body.weight(.semibold))
                        Text("Settings").font(.body).fontWeight(.bold)
                        Spacer()
                    }
                    .padding(.vertical, 5).padding(.horizontal, 8)
                    .background(isHeaderHovering ? Color("HoverColor") : .clear).cornerRadius(5)
                }.buttonStyle(.plain).padding(.horizontal, 5).padding(.top, 2).onHover { hovering in isHeaderHovering = hovering }
                
                Rectangle()
                    .fill(Color("DividerColor"))
                    .frame(height: 0.5)
                    .padding(.horizontal, 12)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Display").font(.caption).foregroundColor(Color("SecondaryTextColor"))
                    HStack { Text("Language").font(.subheadline); Spacer(); Picker("", selection: $languageManager.language) { Text("English").tag("en"); Text("العربية").tag("ar"); Text("Indonesia").tag("id") }.fixedSize() }
                    HStack { Text("Menu Bar Style").font(.subheadline); Spacer(); Picker("", selection: $vm.menuBarTextMode) { ForEach(MenuBarTextMode.allCases) { mode in Text(mode.localized).tag(mode) } }.fixedSize() }
                    StyledToggle(label: "Compact View", isOn: $vm.useCompactLayout)
                    StyledToggle(label: "24-Hour Time", isOn: $vm.use24HourFormat)
                    StyledToggle(label: "Minimal Menu Bar", isOn: $vm.useMinimalMenuBarText).disabled(vm.menuBarTextMode == .hidden)
                    StyledToggle(label: "Accent Color", isOn: $vm.useAccentColor)
                    StyledToggle(label: "Show Sunnah Prayers", isOn: $vm.showSunnahPrayers)
                }
                .controlSize(.small)
                .padding(.horizontal, 16).padding(.top, 8)
                
                Spacer(minLength: 0)

                Rectangle().fill(Color("DividerColor")).frame(height: 1).padding(.horizontal, 12)
                
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: { navigationModel.showView(Self.id, animation: vm.forwardAnimation()) { LocationAndCalcSettingsView() } }) {
                        HStack { Text("Calculation & Location").font(.subheadline); Spacer(); Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundColor(.secondary) }
                        .padding(.vertical, 5).padding(.horizontal, 8).background(isCalcHovering ? Color("HoverColor") : .clear).cornerRadius(5)
                    }.buttonStyle(.plain).padding(.horizontal, 5).onHover { hovering in isCalcHovering = hovering }
                    
                    Button(action: { navigationModel.showView(Self.id, animation: vm.forwardAnimation()) { SystemAndNotificationsSettingsView() } }) {
                        HStack { Text("System & Notifications").font(.subheadline); Spacer(); Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundColor(.secondary) }
                        .padding(.vertical, 5).padding(.horizontal, 8).background(isNotifHovering ? Color("HoverColor") : .clear).cornerRadius(5)
                    }.buttonStyle(.plain).padding(.horizontal, 5).onHover { hovering in isNotifHovering = hovering }
                }
            }
            .padding(.vertical, 8)
            .frame(width: viewWidth)
        }
    }
}
