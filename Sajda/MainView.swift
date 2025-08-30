// MARK: - GANTI FILE: Sajda/MainView.swift
// Salin dan tempel SELURUH kode ini. Perubahan warna ada di baris ke-21.

import SwiftUI
import Adhan

struct MainView: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    @Binding var activePage: ActivePage

    @State private var isSettingsHovering = false
    @State private var isAboutHovering = false
    @State private var isQuitHovering = false

    private var viewWidth: CGFloat {
        return vm.useCompactLayout ? 220 : 260
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Sajda").font(.body).fontWeight(.bold)
                Spacer()
                if vm.isPrayerDataAvailable {
                    // --- PERBAIKAN WARNA DI SINI ---
                    Text("\(vm.nextPrayerName) in \(vm.countdown)")
                        .font(.body)
                        .foregroundColor(Color("SecondaryTextColor")) // Menggunakan dark grey kustom
                }
            }.padding(.horizontal, 12).padding(.top, 4)
            
            Divider().padding(.horizontal, 12)
            
            if vm.isPrayerDataAvailable {
                PrayerListView()
            } else {
                Spacer()
                PermissionRequestView(activePage: $activePage)
                Spacer()
            }
            
            Divider().padding(.horizontal, 12)
            VStack(alignment: .leading, spacing: 0) {
                Button(action: { activePage = .settings }) {
                    HStack {
                        Text("Settings"); Spacer()
                        Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundColor(.secondary)
                    }
                    .padding(.vertical, 5).padding(.horizontal, 8)
                    .background(Color.secondary.opacity(isSettingsHovering ? 0.25 : 0)).cornerRadius(5)
                }.buttonStyle(.plain).padding(.horizontal, 5).onHover { hovering in isSettingsHovering = hovering }
                
                Button(action: { activePage = .about }) {
                    HStack { Text("About"); Spacer() }
                    .padding(.vertical, 5).padding(.horizontal, 8)
                    .background(Color.secondary.opacity(isAboutHovering ? 0.25 : 0)).cornerRadius(5)
                }.buttonStyle(.plain).padding(.horizontal, 5).onHover { hovering in isAboutHovering = hovering }
                
                Divider().padding(.horizontal, 12)
                
                Button(action: { NSApp.terminate(nil) }) {
                    HStack { Text("Quit"); Spacer() }
                    .padding(.vertical, 5).padding(.horizontal, 8)
                    .background(Color.secondary.opacity(isQuitHovering ? 0.25 : 0)).cornerRadius(5)
                }.buttonStyle(.plain).padding(.horizontal, 5).onHover { hovering in isQuitHovering = hovering }
            }
        }
        .padding(.vertical, 8)
        .frame(width: viewWidth)
    }
}

struct PrayerListView: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    
    private var prayerOrder: [String] {
        if vm.showSunnahPrayers {
            let sortedTimes = vm.todayTimes.sorted { $0.value < $1.value }
            return sortedTimes.map { $0.key }.filter { ["Tahajud", "Fajr", "Dhuha", "Dhuhr", "Asr", "Maghrib", "Isha"].contains($0) }
        } else {
            return ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "location.fill")
                Text(vm.locationStatusText)
                Spacer()
            }
            .font(.caption)
            .foregroundColor(Color("SecondaryTextColor")) // Warna ini juga sudah benar
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
            
            VStack(spacing: 0) {
                ForEach(prayerOrder, id: \.self) { prayerName in
                    if let prayerTime = vm.todayTimes[prayerName] {
                        let isNextPrayer = prayerName == vm.nextPrayerName
                        let highlightColor = vm.useAccentColor ? Color.accentColor : Color.secondary.opacity(0.25)
                        let textColor = isNextPrayer ? (vm.useAccentColor ? Color.white : Color.primary) : Color.primary
                        HStack {
                            Text(prayerName)
                            Spacer()
                            if prayerName == "Tahajud" || prayerName == "Dhuha" {
                                Text("Around")
                                    .font(.caption)
                                    .foregroundColor(isNextPrayer ? textColor.opacity(0.8) : .secondary)
                            }
                            Text(vm.dateFormatter.string(from: prayerTime)).font(.system(.body, design: .monospaced))
                        }
                        .foregroundColor(textColor).fontWeight(isNextPrayer ? .bold : .regular)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(isNextPrayer ? highlightColor : Color.clear))
                    }
                }
            }.padding(.horizontal, 5)
        }
    }
}

struct PermissionRequestView: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    @Binding var activePage: ActivePage
    @State private var isManualHovering = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "location.slash.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            
            Text("Location Required")
                .font(.headline)
            
            Text(vm.locationStatusText)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                if vm.authorizationStatus == .denied {
                    Button("Open System Settings", action: vm.openLocationSettings)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                } else {
                    Button("Allow Location Access", action: vm.requestLocationPermission)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                }
                
                Button(action: { activePage = .manualLocation(returnPage: .main) }) {
                    Text("Or, set location manually")
                        .padding(.vertical, 3).padding(.horizontal, 8)
                        .background(Color.secondary.opacity(isManualHovering ? 0.25 : 0))
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isManualHovering = hovering
                }
            }
            .padding(.top, 4)
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
    }
}
