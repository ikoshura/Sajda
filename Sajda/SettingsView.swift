// Salin dan tempel SELURUH kode ini ke dalam file SettingsView.swift

import SwiftUI
import Adhan

struct SettingsView: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    @Binding var activePage: ActivePage
    
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @State private var isHeaderHovering = false

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
            }.buttonStyle(.plain).padding(.horizontal, 5).padding(.top, 2).onHover { hovering in isHeaderHovering = hovering }
            
            Divider().padding(.horizontal, 12)

            ScrollView {
                Form {
                    Section(header: Text("Display").font(.caption2)) {
                        Picker("Menu Bar Style", selection: $vm.menuBarStyle) { ForEach(MenuBarStyle.allCases) { style in Text(style.rawValue).tag(style) } }
                        Picker("Time Format", selection: $vm.timeFormat) { ForEach(TimeFormat.allCases) { format in Text(format.rawValue).tag(format) } }.pickerStyle(SegmentedPickerStyle())
                        Toggle("Monochrome Highlight", isOn: $vm.isMonochrome)
                        
                        // PERBAIKAN: Toggle baru untuk sholat sunnah
                        Toggle("Show Sunnah Prayers", isOn: $vm.showSunnahPrayers)
                        Text("Shows Tahajud and Dhuha times.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Section(header: Text("Calculation").font(.caption2)) {
                        Picker("Method", selection: $vm.method) { ForEach(CalculationMethod.allCases, id: \.self) { Text("\($0.rawValue.capitalized)") } }
                        Picker("Madhhab", selection: $vm.madhhab) { ForEach(Madhab.allCases, id: \.self) { Text("\($0 == .hanafi ? "Hanafi" : "Shafi / Others")") } }.pickerStyle(SegmentedPickerStyle())
                    }
                    
                    Section(header: Text("Location").font(.caption2)) {
                        HStack {
                            Image(systemName: vm.isUsingManualLocation ? "pencil.circle.fill" : "location.circle.fill").foregroundColor(.secondary)
                            Text(vm.isUsingManualLocation ? "Manual: \(vm.locationStatusText)" : "Automatic: \(vm.locationStatusText)")
                        }
                        Button("Change Manual Location") { activePage = .manualLocation(returnPage: .settings) }
                        if vm.isUsingManualLocation {
                            Button("Use Automatic Location") { vm.switchToAutomaticLocation() }
                        }
                    }
                    
                    Section(header: Text("System").font(.caption2)) {
                        Toggle("Run at login", isOn: $launchAtLogin).onChange(of: launchAtLogin) { newValue in StartupManager.toggleLaunchAtLogin(isEnabled: newValue) }
                        Toggle("Prayer Notifications", isOn: $vm.isNotificationsEnabled)
                    }
                }
                .controlSize(.small).padding(.horizontal, 8)
            }
            .focusable(false)
        }
        .padding(.vertical, 8)
        .padding(.bottom, 4)
    }
}
