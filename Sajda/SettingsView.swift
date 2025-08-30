// MARK: - GANTI FILE: Sajda/SettingsView.swift (VERSI FINAL & DIPERBAIKI)

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
                VStack(alignment: .leading, spacing: 12) {
                    Group {
                        Text("Display").font(.caption).foregroundColor(.secondary)
                        HStack {
                            Text("Menu Bar Style")
                            Spacer()
                            Picker("", selection: $vm.menuBarTextMode) {
                                ForEach(MenuBarTextMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
                            }.fixedSize()
                        }
                        StyledToggle(label: "Compact Main View", isOn: $vm.useCompactLayout)
                        StyledToggle(label: "24-Hour Time", isOn: $vm.use24HourFormat)
                        StyledToggle(label: "Use System Accent Color", isOn: $vm.useAccentColor)
                        StyledToggle(label: "Show Sunnah Prayers", isOn: $vm.showSunnahPrayers)
                    }

                    Divider()
                    
                    Group {
                        Text("Calculation").font(.caption).foregroundColor(.secondary)
                        HStack {
                            Text("Method")
                            Spacer()
                            // --- PERBAIKAN: Picker sekarang menggunakan SajdaCalculationMethod ---
                            Picker("", selection: $vm.method) {
                                ForEach(SajdaCalculationMethod.allCases) { method in
                                    Text(method.name).tag(method)
                                }
                            }.fixedSize()
                        }
                        HStack {
                            Text("Time Correction")
                            Spacer()
                            Button("Adjust") { activePage = .correction }
                        }
                        StyledToggle(label: "Hanafi Madhhab (for Asr)", isOn: $vm.useHanafiMadhhab)
                    }

                    Divider()
                    
                    Group {
                        Text("Location").font(.caption).foregroundColor(.secondary)
                        HStack {
                            Image(systemName: vm.isUsingManualLocation ? "pencil.circle.fill" : "location.circle.fill").foregroundColor(.secondary)
                            Text(vm.isUsingManualLocation ? "Manual: \(vm.locationStatusText)" : "Automatic: \(vm.locationStatusText)")
                        }.lineLimit(1).truncationMode(.tail)
                        HStack {
                            Button("Change Manual Location") { activePage = .manualLocation(returnPage: .settings) }
                            Spacer()
                            if vm.isUsingManualLocation {
                                Button("Use Automatic") { vm.switchToAutomaticLocation() }
                            }
                        }
                    }

                    Divider()
                    
                    Group {
                        Text("System & Notifications").font(.caption).foregroundColor(.secondary)
                        StyledToggle(label: "Run at Login", isOn: $launchAtLogin)
                        StyledToggle(label: "Prayer Notifications", isOn: $vm.isNotificationsEnabled)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Notification Sound")
                                Spacer()
                                Picker("", selection: $vm.adhanSound) {
                                    ForEach(AdhanSound.allCases) { sound in
                                        Text(sound.rawValue).tag(sound)
                                    }
                                }.fixedSize()
                            }
                            if vm.adhanSound == .custom {
                                HStack {
                                    Text("Custom File")
                                    Spacer()
                                    Button("Browse...") { vm.selectCustomAdhanSound() }
                                }
                                Text(URL(string: vm.customAdhanSoundPath)?.lastPathComponent ?? "No file selected")
                                    .font(.caption).foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }.disabled(!vm.isNotificationsEnabled)
                    }
                }
                .controlSize(.small).padding(.horizontal, 16).padding(.vertical, 8)
            }
        }
        .padding(.vertical, 8)
    }
}
