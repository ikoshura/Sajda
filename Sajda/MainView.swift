// MARK: - GANTI SELURUH FILE: MainView.swift

import SwiftUI
import Adhan
import NavigationStack

struct MainView: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    @EnvironmentObject var navigationModel: NavigationModel
    @State private var isSettingsHovering = false
    @State private var isAboutHovering = false
    @State private var isQuitHovering = false
    private var viewWidth: CGFloat { return vm.useCompactLayout ? 220 : 260 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Sajda").font(.body).fontWeight(.bold)
                Spacer()
                if vm.isPrayerDataAvailable && vm.menuBarTextMode == .hidden {
                    let format = NSLocalizedString("prayer_in_countdown", comment: "")
                    let localizedPrayerName = NSLocalizedString(vm.nextPrayerName, comment: "")
                    Text(String(format: format, localizedPrayerName, vm.countdown)).font(.body).foregroundColor(vm.isPrayerImminent ? .red : Color("SecondaryTextColor")).transition(.opacity.animation(.easeInOut))
                }
            }
            .padding(.horizontal, 12).padding(.top, 4)
            
            Rectangle()
                .fill(Color("DividerColor"))
                .frame(height: 0.5)
                .padding(.horizontal, 12)

            if vm.isPrayerDataAvailable {
                PrayerListView()
            } else {
                Spacer()
                PermissionRequestView()
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 0) {
                Rectangle()
                    .fill(Color("DividerColor"))
                    .frame(height: 1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 2)

                Button(action: {
                    navigationModel.showView(ContentView.id, animation: vm.forwardAnimation()) { SettingsView() }
                }) {
                    HStack { Text("Settings"); Spacer(); Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundColor(.secondary) }
                        .padding(.vertical, 5).padding(.horizontal, 8)
                        .background(isSettingsHovering ? Color("HoverColor") : .clear)
                        .cornerRadius(5)
                }.buttonStyle(.plain).padding(.horizontal, 5).onHover { hovering in isSettingsHovering = hovering }
                
                Button(action: {
                    navigationModel.showView(ContentView.id, animation: vm.forwardAnimation()) { AboutView() }
                }) {
                    // --- PERUBAHAN DI SINI ---
                    // Menambahkan chevron arrow agar konsisten dengan tombol Settings.
                    HStack { Text("About"); Spacer(); Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundColor(.secondary) }
                        .padding(.vertical, 5).padding(.horizontal, 8)
                        .background(isAboutHovering ? Color("HoverColor") : .clear)
                        .cornerRadius(5)
                }.buttonStyle(.plain).padding(.horizontal, 5).onHover { hovering in isAboutHovering = hovering }

                Rectangle()
                    .fill(Color("DividerColor"))
                    .frame(height: 1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 2)

                Button(action: { NSApp.terminate(nil) }) {
                    HStack { Text("Quit"); Spacer() }
                        .padding(.vertical, 5).padding(.horizontal, 8)
                        .background(isQuitHovering ? Color("HoverColor") : .clear)
                        .cornerRadius(5)
                }.buttonStyle(.plain).padding(.horizontal, 5).onHover { hovering in isQuitHovering = hovering }
            }
        }.padding(.vertical, 8).frame(width: viewWidth)
    }
}

struct PrayerListView: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    private var prayerOrder: [String] {
        let defaultOrder = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
        let sunnahOrder = ["Tahajud", "Fajr", "Dhuha", "Dhuhr", "Asr", "Maghrib", "Isha"]
        let baseOrder = vm.showSunnahPrayers ? sunnahOrder : defaultOrder
        return baseOrder.filter { vm.todayTimes.keys.contains($0) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack { Image(systemName: "location.fill"); Text(vm.locationStatusText); Spacer() }
                .font(.caption).foregroundColor(Color("SecondaryTextColor")).padding(.horizontal, 12)
            if vm.isUsingManualLocation && !vm.locationInfoText.isEmpty {
                Text(vm.locationInfoText).font(.caption2).foregroundColor(Color("SecondaryTextColor")).padding(.horizontal, 12).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 0) {
                ForEach(prayerOrder, id: \.self) { prayerName in
                    if let prayerTime = vm.todayTimes[prayerName] {
                        let isNextPrayer = prayerName == vm.nextPrayerName
                        let (highlightColor, textColor): (Color, Color) = {
                            if isNextPrayer && vm.isPrayerImminent {
                                if vm.useAccentColor {
                                    return (Color.red, Color.white)
                                } else {
                                    return (Color("HighlightColor"), .red)
                                }
                            }
                            else if isNextPrayer {
                                if vm.useAccentColor {
                                    return (Color.accentColor, Color.white)
                                } else {
                                    return (Color("HoverColor"), .primary)
                                }
                            }
                            else { return (.clear, .primary) }
                        }()
                        HStack {
                            Text(LocalizedStringKey(prayerName)); Spacer()
                            if prayerName == "Tahajud" || prayerName == "Dhuha" { Text("Around").font(.caption).foregroundColor(isNextPrayer ? textColor.opacity(0.8) : Color("SecondaryTextColor")) }
                            Text(vm.dateFormatter.string(from: prayerTime)).font(.system(.body, design: .monospaced))
                        }
                        .foregroundColor(textColor).fontWeight(isNextPrayer ? .bold : .regular).padding(.horizontal, 12).padding(.vertical, 5).background(RoundedRectangle(cornerRadius: 6).fill(highlightColor))
                    }
                }
            }.padding(.horizontal, 5).padding(.top, 4)
        }
    }
}

struct PermissionRequestView: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    @EnvironmentObject var navigationModel: NavigationModel
    @State private var isManualHovering = false
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "location.slash.circle.fill").font(.system(size: 28)).foregroundColor(.secondary)
            Text("Location Required").font(.headline)
            Text("To provide accurate prayer times, Sajda Pro needs to know your location.").font(.caption).multilineTextAlignment(.center).foregroundColor(Color("SecondaryTextColor")).padding(.horizontal)
            VStack(spacing: 8) {
                if vm.isRequestingLocation {
                    ProgressView().padding(.vertical, 4)
                    Text("Requesting Permission...").font(.caption).foregroundColor(.secondary)
                } else if vm.authorizationStatus == .denied {
                    Button("Open System Settings", action: vm.openLocationSettings).buttonStyle(.borderedProminent).controlSize(.regular)
                } else {
                    Button("Allow Location Access", action: vm.requestLocationPermission).buttonStyle(.borderedProminent).controlSize(.regular)
                }
                Button(action: {
                    navigationModel.showView(ContentView.id, animation: vm.forwardAnimation()) { ManualLocationView(isModal: true) }
                }) {
                    Text("Or, set location manually")
                        .padding(.vertical, 3).padding(.horizontal, 8)
                        .background(isManualHovering ? Color("HoverColor") : .clear)
                        .cornerRadius(5)
                }.buttonStyle(.plain).onHover { hovering in isManualHovering = hovering }
            }.padding(.top, 4).padding(.horizontal).animation(.easeInOut, value: vm.isRequestingLocation)
        }.frame(maxWidth: .infinity)
    }
}
