// Salin dan tempel seluruh kode ini ke dalam file SettingsView.swift

import SwiftUI
import Adhan
import MapKit

struct SettingsView: View {
    @ObservedObject var vm: PrayerTimeViewModel
    @Binding var activePage: ActivePage
    
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    
    @State private var isHeaderHovering = false
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

            Form {
                Section(header: Text("DISPLAY").font(.caption).fontWeight(.semibold)) {
                    Picker("Menu Bar Style", selection: $vm.menuBarStyle) { ForEach(MenuBarStyle.allCases) { style in Text(style.rawValue).tag(style) } }
                    Picker("Time Format", selection: $vm.timeFormat) { ForEach(TimeFormat.allCases) { format in Text(format.rawValue).tag(format) } }.pickerStyle(SegmentedPickerStyle())
                    Toggle("Use monochrome highlight", isOn: $vm.isMonochrome)
                }
                Section(header: Text("CALCULATION").font(.caption).fontWeight(.semibold)) {
                    Picker("Method", selection: $vm.method) { ForEach(CalculationMethod.allCases, id: \.self) { Text("\($0.rawValue.capitalized)") } }.onChange(of: vm.method) { _ in vm.updatePrayerTimes() }
                    Picker("Madhhab", selection: $vm.madhhab) { ForEach(Madhab.allCases, id: \.self) { Text("\($0 == .hanafi ? "Hanafi" : "Shafi")") } }.pickerStyle(SegmentedPickerStyle()).onChange(of: vm.madhhab) { _ in vm.updatePrayerTimes() }
                }
                Section(header: Text("SYSTEM").font(.caption).fontWeight(.semibold)) {
                    Toggle("Run when computer starts", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { newValue in StartupManager.toggleLaunchAtLogin(isEnabled: newValue) }
                    Toggle("Enable prayer notifications", isOn: $vm.isNotificationsEnabled)
                }
            }.padding(.horizontal, 4)

            Divider().padding(.horizontal, 12)
            
            Button(action: { vm.requestLocationUpdate() }) {
                HStack { Text("Refresh Location"); Spacer() }
                .padding(.vertical, 5).padding(.horizontal, 8)
                .background(Color.secondary.opacity(isRefreshHovering ? 0.25 : 0)).cornerRadius(5)
            }.buttonStyle(.plain).padding(.horizontal, 5).onHover { hovering in isRefreshHovering = hovering }
        }
        .padding(.vertical, 8).frame(width: 300, height: 420)
    }
}
