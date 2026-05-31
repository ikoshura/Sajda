// MARK: - GANTI SELURUH FILE: OnboardingView.swift (DENGAN EFEK HOVER UNDERLINE)

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    @EnvironmentObject var languageManager: LanguageManager
    
    @AppStorage("showOnboardingAtLaunch") private var showOnboardingAtLaunch = true
    @State private var showingManualLocationSheet = false
    
    // State untuk efek hover
    @State private var isSkipHovering = false
    @State private var isHoveringChangeManual = false
    @State private var isHoveringSwitchToAuto = false
    @State private var isHoveringSetManually = false

    var body: some View {
        ZStack {
            VisualEffectView(material: .underWindowBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 20)

                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable().scaledToFit().frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                Text("Welcome to Sajda Pro")
                    .font(.system(size: 24, weight: .bold))
                    .padding(.top, 15)
                
                Text("To get started, please provide your location for accurate prayer times.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 4)

                Spacer(minLength: 25)

                VStack {
                    if vm.isRequestingLocation {
                        ProgressView().controlSize(.small)
                        Text("Requesting Permission...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                        
                        Button("Or, Set Location Manually", action: { showingManualLocationSheet = true })
                            .underline(isHoveringSetManually)
                            .onHover { hovering in isHoveringSetManually = hovering }
                            .padding(.top, 20)

                    } else if vm.isUsingManualLocation {
                        InfoStatusView(
                            text: LocalizedStringKey("Using manual location: **\(vm.locationStatusText)**"),
                            icon: "pencil.circle.fill",
                            color: .secondary
                        )
                        Button("Change Manual Location", action: { showingManualLocationSheet = true })
                            .onHover { hovering in isHoveringChangeManual = hovering }
                        Button("Switch to Automatic Location", action: vm.switchToAutomaticLocation)
                            .buttonStyle(.link)
                            .underline(isHoveringSwitchToAuto)
                            .onHover { hovering in isHoveringSwitchToAuto = hovering }
                    } else if vm.authorizationStatus == .authorized {
                        InfoStatusView(
                            text: "Location access is enabled.",
                            icon: "checkmark.circle.fill",
                            color: .green
                        )
                        if !vm.isPrayerDataAvailable {
                            Text("Fetching Location...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 2)
                        }
                        Button("Or, Set Location Manually", action: { showingManualLocationSheet = true })
                            .buttonStyle(.link)
                            .underline(isHoveringSetManually)
                            .onHover { hovering in isHoveringSetManually = hovering }
                    } else {
                        Button("Allow Location Access", action: vm.requestLocationPermission)
                            .controlSize(.large)
                            .tint(.accentColor)
                            .disabled(vm.authorizationStatus == .denied)
                        
                        if vm.authorizationStatus == .denied {
                            Text("Please grant access in System Settings.")
                                .font(.caption).foregroundColor(.red).padding(.top, 5)
                        }
                        
                        Button("Or, Set Location Manually", action: { showingManualLocationSheet = true })
                            .underline(isHoveringSetManually)
                            .onHover { hovering in isHoveringSetManually = hovering }
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 40)
                .frame(minHeight: 120)
                .animation(.easeInOut, value: vm.isRequestingLocation)
                .animation(.easeInOut, value: vm.authorizationStatus)

                Spacer(minLength: 25)
                
                VStack(spacing: 12) {
                    Toggle("Show this window on launch", isOn: $showOnboardingAtLaunch)
                        .toggleStyle(.checkbox)
                    
                    Button(action: { NSApp.keyWindow?.close() }) {
                        Text("Done").frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
                    .disabled(!vm.isPrayerDataAvailable)
                    .keyboardShortcut(.defaultAction)

                    Button(action: {
                        NSApp.keyWindow?.close()
                    }) {
                        Text("Skip for now")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .underline(isSkipHovering)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        isSkipHovering = hovering
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 30)
            }
        }
        .frame(width: 380, height: 490)
        .sheet(isPresented: $showingManualLocationSheet) {
            LanguageManagerView(manager: languageManager) {
                ManualLocationSheetView().environmentObject(vm)
            }
        }
    }
}

struct InfoStatusView: View {
    let text: LocalizedStringKey
    let icon: String
    let color: Color

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: icon)
        }
        .font(.callout)
        .foregroundColor(color)
        .multilineTextAlignment(.center)
        .padding(.vertical, 5)
    }
}
