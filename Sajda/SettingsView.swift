// Ganti seluruh kode di SettingsView.swift dengan ini

import SwiftUI
import Adhan
import MapKit

struct SettingsView: View {
    @ObservedObject var vm: PrayerTimeViewModel
    @Binding var activePage: ActivePage
    
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    
    @State private var isHeaderHovering = false
    @State private var isCalcHovering = false
    @State private var isRefreshHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            
            Button(action: { activePage = .main }) {
                HStack {
                    Image(systemName: "chevron.left").font(.body.weight(.semibold))
                    Text("Settings").font(.body).fontWeight(.bold)
                    Spacer()
                }
                .padding(.vertical, 5).padding(.horizontal, 8)
                .background(Color.secondary.opacity(isHeaderHovering ? 0.25 : 0)).cornerRadius(5)
            }.buttonStyle(.plain).padding(.horizontal, 5).onHover { hovering in isHeaderHovering = hovering }
            
            Divider().padding(.horizontal, 12)

            VStack(alignment: .leading, spacing: 10) {
                Text("DISPLAY").font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
                Picker("Menu Bar Style", selection: $vm.menuBarStyle) { ForEach(MenuBarStyle.allCases) { style in Text(style.rawValue).tag(style) } }
                Picker("Time Format", selection: $vm.timeFormat) { ForEach(TimeFormat.allCases) { format in Text(format.rawValue).tag(format) } }.pickerStyle(SegmentedPickerStyle())
                Toggle("Use monochrome highlight", isOn: $vm.isMonochrome)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)

            Divider().padding(.horizontal, 12)
            
            Button(action: { activePage = .calculationSettings }) {
                HStack {
                    Text("Calculation"); Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundColor(.secondary)
                }
                .padding(.vertical, 5).padding(.horizontal, 8)
                .background(Color.secondary.opacity(isCalcHovering ? 0.25 : 0)).cornerRadius(5)
            }.buttonStyle(.plain).padding(.horizontal, 5).onHover { hovering in isCalcHovering = hovering }

            Divider().padding(.horizontal, 12)

            VStack(alignment: .leading, spacing: 10) {
                Text("SYSTEM").font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
                Toggle("Run when computer starts", isOn: $launchAtLogin).onChange(of: launchAtLogin) { newValue in StartupManager.toggleLaunchAtLogin(isEnabled: newValue) }
                Toggle("Enable prayer notifications", isOn: $vm.isNotificationsEnabled)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)

            Spacer(minLength: 0)

            Divider().padding(.horizontal, 12)
            
            Button(action: { vm.requestLocationUpdate() }) {
                HStack { Text("Refresh Location"); Spacer() }
                .padding(.vertical, 5).padding(.horizontal, 8)
                .background(Color.secondary.opacity(isRefreshHovering ? 0.25 : 0)).cornerRadius(5)
            }.buttonStyle(.plain).padding(.horizontal, 5).onHover { hovering in isRefreshHovering = hovering }
        }
        .padding(.vertical, 8)
    }
}
