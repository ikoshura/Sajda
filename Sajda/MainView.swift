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
    private var viewWidth: CGFloat { return vm.panelWidth(base: vm.useCompactLayout ? 220 : 260) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Sajda").scaledFont(.body, weight: .bold)
                Spacer()
                if vm.isPrayerDataAvailable && vm.menuBarTextMode == .hidden {
                    Text(vm.headerCountdownText).scaledFont(.body).foregroundColor(vm.isPrayerImminent ? .red : Color("SecondaryTextColor")).transition(.opacity.animation(.easeInOut))
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
                    HStack { Text("Settings"); Spacer(); Image(systemName: vm.forwardChevron).scaledFont(.caption, weight: .bold).foregroundColor(.secondary) }
                        .padding(.vertical, 5).padding(.horizontal, 8)
                        .liquidHover(isSettingsHovering)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 5)
                .onHover { hovering in isSettingsHovering = hovering }
                // --- PERBAIKAN DI SINI ---
                .focusable(false)
                
                Button(action: {
                    navigationModel.showView(ContentView.id, animation: vm.forwardAnimation()) { AboutView() }
                }) {
                    HStack { Text("About"); Spacer(); Image(systemName: vm.forwardChevron).scaledFont(.caption, weight: .bold).foregroundColor(.secondary) }
                        .padding(.vertical, 5).padding(.horizontal, 8)
                        .liquidHover(isAboutHovering)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 5)
                .onHover { hovering in isAboutHovering = hovering }
                // --- PERBAIKAN DI SINI ---
                .focusable(false)

                Rectangle()
                    .fill(Color("DividerColor"))
                    .frame(height: 1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 2)

                Button(action: { NSApp.terminate(nil) }) {
                    HStack { Text("Quit"); Spacer() }
                        .padding(.vertical, 5).padding(.horizontal, 8)
                        .liquidHover(isQuitHovering)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 5)
                .onHover { hovering in isQuitHovering = hovering }
                // --- PERBAIKAN DI SINI ---
                .focusable(false)
            }
        }.padding(.vertical, 8).frame(width: viewWidth)
    }
}

struct PrayerListView: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    @Environment(\.colorScheme) private var colorScheme
    private var prayerOrder: [String] {
        let defaultOrder = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
        let sunnahOrder = ["Tahajud", "Fajr", "Dhuha", "Dhuhr", "Asr", "Maghrib", "Isha"]
        let baseOrder = vm.showSunnahPrayers ? sunnahOrder : defaultOrder
        return baseOrder.filter { vm.todayTimes.keys.contains($0) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack { Image(systemName: "location.fill"); Text(vm.locationStatusText); Spacer() }
                .scaledFont(.caption).foregroundColor(Color("SecondaryTextColor")).padding(.horizontal, 12)
            VStack(spacing: 0) {
                ForEach(prayerOrder, id: \.self) { prayerName in
                    if let prayerTime = vm.todayTimes[prayerName] {
                        let isNextPrayer = prayerName == vm.nextPrayerName
                        let (highlightColor, textColor): (Color, Color) = {
                            if isNextPrayer && vm.isPrayerImminent {
                                if vm.useAccentColor {
                                    return (Color(red: 1.0, green: 0x42 / 255.0, blue: 0x46 / 255.0), Color.white)
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
                            Text(vm.prayerDisplayName(prayerName)); Spacer()
                            if vm.isAdhanPlaying && prayerName == vm.activeAdhanPrayerName {
                                Button(action: { vm.stopAdhan() }) {
                                    Image(systemName: "speaker.slash.fill")
                                        .scaledFont(.caption)
                                        .foregroundColor(textColor)
                                }
                                .buttonStyle(.plain)
                                .help("Stop Adhan")
                            }
                            if prayerName == "Tahajud" || prayerName == "Dhuha" { Text("Around").scaledFont(.caption).foregroundColor(isNextPrayer ? textColor.opacity(0.8) : Color("SecondaryTextColor")) }
                            Text(vm.dateFormatter.string(from: prayerTime)).scaledFont(.body, weight: isNextPrayer ? .bold : nil)
                        }
                        .foregroundColor(textColor).fontWeight((isNextPrayer || vm.accessibilityBoldText) ? .bold : .regular).padding(.horizontal, 12).padding(.vertical, 5).background {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6).fill(highlightColor)
                                if isNextPrayer, vm.useGlassPrayerHighlight {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color.clear)
                                        .glassCard(cornerRadius: 6, interactive: true)
                                        // Glass gelap hanya untuk highlight aksen (teks
                                        // putih): glass terang di atas aksen di mode terang
                                        // terlalu memutih. Non-ikut skema aslinya.
                                        .environment(\.colorScheme, vm.useAccentColor ? .dark : colorScheme)
                                }
                            }
                        }
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
            Text("Location Required").scaledFont(.headline)
            Text("To provide accurate prayer times, Sajda Pro needs to know your location.").scaledFont(.caption).multilineTextAlignment(.center).foregroundColor(Color("SecondaryTextColor")).padding(.horizontal)
            VStack(spacing: 8) {
                if vm.isRequestingLocation {
                    ProgressView().padding(.vertical, 4)
                    Text("Requesting Permission...").scaledFont(.caption).foregroundColor(.secondary)
                } else if vm.authorizationStatus == .denied {
                    Button("Open System Settings", action: vm.openLocationSettings).buttonStyle(.borderedProminent).controlSize(.regular)
                } else if vm.authorizationStatus == .authorized {
                    Button("Retry Location", action: vm.refetchAutomaticLocation).buttonStyle(.borderedProminent).controlSize(.regular)
                } else {
                    Button("Allow Location Access", action: vm.requestLocationPermission).buttonStyle(.borderedProminent).controlSize(.regular)
                }
                Button(action: {
                    navigationModel.showView(ContentView.id, animation: vm.forwardAnimation()) { ManualLocationView(isModal: true) }
                }) {
                    Text("Or, set location manually")
                        .padding(.vertical, 3).padding(.horizontal, 8)
                        .liquidHover(isManualHovering)
                }.buttonStyle(.plain).onHover { hovering in isManualHovering = hovering }
            }.padding(.top, 4).padding(.horizontal).animation(.easeInOut, value: vm.isRequestingLocation)
        }.frame(maxWidth: .infinity)
    }
}
