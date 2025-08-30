import SwiftUI
import Adhan

struct SettingsView: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    @Binding var activePage: ActivePage
    
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @State private var isHeaderHovering = false

    @AppStorage("isPrayerTimerEnabled") private var isPrayerTimerEnabled: Bool = false
    @AppStorage("prayerTimerDuration") private var prayerTimerDuration: Int = 5

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
                        Text("Display")
                            .font(.caption)
                            .foregroundColor(Color("SecondaryTextColor"))
                        HStack {
                            Text("Menu Bar Style")
                            Spacer()
                            Picker("", selection: $vm.menuBarTextMode) {
                                ForEach(MenuBarTextMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        VStack(spacing: 10) {
                            StyledToggle(label: "Compact Main View", isOn: $vm.useCompactLayout)
                            StyledToggle(label: "24-Hour Time", isOn: $vm.use24HourFormat)
                            StyledToggle(label: "Use Accent Color", isOn: $vm.useAccentColor)
                            StyledToggle(label: "Show Sunnah Prayers", isOn: $vm.showSunnahPrayers)
                        }
                    }
                    
                    Divider()
                    Group {
                        Text("Inter-Prayer Timer (Optional)")
                            .font(.caption)
                            .foregroundColor(Color("SecondaryTextColor"))
                        
                        StyledToggle(label: "Enable Timer", isOn: $isPrayerTimerEnabled)

                        if isPrayerTimerEnabled {
                            Stepper(value: $prayerTimerDuration, in: 1...60, step: 1) {
                                // Corrected Stepper
                                HStack(spacing: 4) {
                                    Text("Start timer")
                                    Text("\(prayerTimerDuration)").bold()
                                    Text("minutes after prayer")
                                }
                            }
                            .controlSize(.small)
                            .padding(.top, 5)
                        }
                        
                        Text("When enabled, a visual prompt will appear after your set duration, reminding you to begin your next activity.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Divider()
                    Text("Calculation")
                        .font(.caption)
                        .foregroundColor(Color("SecondaryTextColor"))
                    
                    VStack(spacing: 10) {
                        HStack {
                            Text("Method")
                            Spacer()
                            Picker("", selection: $vm.method) {
                                ForEach(CalculationMethod.allCases, id: \.self) { method in Text("\(method.rawValue.capitalized)").tag(method) }
                            }
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        HStack {
                            Text("Time Correction")
                            Spacer()
                            Button("Adjust") { activePage = .correction }
                        }
                        .padding(.top, 2)
                        StyledToggle(label: "Hanafi Madhhab", isOn: $vm.useHanafiMadhhab)
                    }

                    Divider()
                    Text("Location").font(.caption).foregroundColor(Color("SecondaryTextColor"))

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: vm.isUsingManualLocation ? "pencil.circle.fill" : "location.circle.fill").foregroundColor(.secondary)
                            Text(vm.isUsingManualLocation ? "Manual: \(vm.locationStatusText)" : "Automatic: \(vm.locationStatusText)")
                        }
                        .lineLimit(1).truncationMode(.tail)
                        
                        HStack {
                            Button("Change Manual Location") { activePage = .manualLocation(returnPage: .settings) }
                            Spacer()
                            if vm.isUsingManualLocation {
                                Button("Use Automatic") { vm.switchToAutomaticLocation() }
                            }
                        }
                        
                        if vm.authorizationStatus == .denied && !vm.isUsingManualLocation {
                            Button("Open System Settings", action: vm.openLocationSettings)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()
                    Text("System").font(.caption).foregroundColor(Color("SecondaryTextColor"))

                    VStack(spacing: 10) {
                        StyledToggle(label: "Run at Login", isOn: $launchAtLogin)
                            .onChange(of: launchAtLogin) { newValue in StartupManager.toggleLaunchAtLogin(isEnabled: newValue) }
                        StyledToggle(label: "Prayer Notifications", isOn: $vm.isNotificationsEnabled)
                    }
                }
                .controlSize(.small)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .focusable(false)
        }
        .padding(.vertical, 8)
        .padding(.bottom, 4)
    }
}
