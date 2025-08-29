// Salin dan tempel SELURUH kode ini ke dalam file MainView.swift

import SwiftUI
import Adhan

// =================================================================
// MAIN VIEW UTAMA (SEKARANG HANYA SEBAGAI "CONTAINER")
// =================================================================
struct MainView: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    @Binding var activePage: ActivePage

    @State private var isSettingsHovering = false
    @State private var isAboutHovering = false
    @State private var isQuitHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                Text("Sajda").font(.body).fontWeight(.bold)
                Spacer()
                if vm.isPrayerDataAvailable {
                    Text("\(vm.nextPrayerName) in \(vm.countdown)").font(.body).foregroundColor(.secondary)
                }
            }.padding(.horizontal, 12).padding(.top, 4)
            
            Divider().padding(.horizontal, 12)
            
            // Konten Dinamis
            if vm.isPrayerDataAvailable {
                PrayerListView()
            } else {
                Spacer()
                PermissionRequestView(activePage: $activePage)
                Spacer()
            }
            
            // Footer
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
    }
}


// =================================================================
// HELPER STRUCT 1: TAMPILAN JADWAL SHOLAT
// =================================================================
struct PrayerListView: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    
    private var prayerOrder: [String] {
        if vm.showSunnahPrayers {
            return ["Tahajud", "Fajr", "Dhuha", "Dhuhr", "Asr", "Maghrib", "Isha"]
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
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
            
            VStack(spacing: 0) {
                ForEach(prayerOrder, id: \.self) { prayerName in
                    if let prayerTime = vm.todayTimes[prayerName] {
                        let isNextPrayer = prayerName == vm.nextPrayerName
                        let highlightColor = vm.isMonochrome ? Color.secondary.opacity(0.25) : Color.accentColor
                        let textColor = isNextPrayer ? (vm.isMonochrome ? Color.primary : Color.white) : Color.primary
                        HStack {
                            Text(prayerName)
                            Spacer()
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


// =================================================================
// HELPER STRUCT 2: TAMPILAN PERMINTAAN IZIN (DENGAN SINTAKS YANG BENAR)
// =================================================================
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
                    // PERBAIKAN FINAL: Menggunakan sintaks Button("Judul", action: vm.fungsi)
                    Button("Open System Settings", action: vm.openLocationSettings)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                    
                    Text("Enable location for Sajda in System Settings to proceed.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    // PERBAIKAN FINAL: Menggunakan sintaks Button("Judul", action: vm.fungsi)
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
