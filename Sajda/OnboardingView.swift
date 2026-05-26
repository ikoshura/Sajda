// MARK: - GANTI SELURUH FILE: OnboardingView.swift (DENGAN EFEK HOVER UNDERLINE)

import SwiftUI
import CoreLocation

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

    private var hasLocationAuthorization: Bool {
        vm.authorizationStatus == .authorized ||
        vm.authorizationStatus == .authorizedAlways
    }

    private var automaticLocationInfoText: String {
        if vm.locationStatusText == "Current Location" {
            return NSLocalizedString("Resolving city...", comment: "")
        }

        if vm.isPrayerDataAvailable {
            return String(format: NSLocalizedString("Current location: %@", comment: ""), vm.locationStatusText)
        }

        return vm.locationStatusText
    }

    private var automaticLocationTitle: String {
        if vm.isRequestingLocation && vm.isPrayerDataAvailable {
            return NSLocalizedString("Refreshing location...", comment: "")
        }

        if vm.isRequestingLocation {
            return NSLocalizedString("Finding your location...", comment: "")
        }

        if vm.isPrayerDataAvailable {
            return NSLocalizedString("Location access is enabled.", comment: "")
        }

        return NSLocalizedString("Location needs attention", comment: "")
    }

    private var automaticLocationStatusColor: Color {
        if vm.isRequestingLocation {
            return .accentColor
        }

        return vm.isPrayerDataAvailable ? .green : .orange
    }

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
                    if vm.isUsingManualLocation {
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
                    } else if hasLocationAuthorization {
                        automaticLocationStatusView
                    } else if vm.isRequestingLocation {
                        ProgressView().controlSize(.small)
                        Text(vm.authorizationStatus == .notDetermined ? "Requesting Permission..." : vm.locationStatusText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)

                        Button("Or, Set Location Manually", action: { showingManualLocationSheet = true })
                            .underline(isHoveringSetManually)
                            .onHover { hovering in isHoveringSetManually = hovering }
                            .padding(.top, 20)

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
                .transaction { transaction in
                    transaction.animation = nil
                }

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

    private var automaticLocationStatusView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: vm.isPrayerDataAvailable ? "checkmark.circle.fill" : (vm.isRequestingLocation ? "location.circle.fill" : "exclamationmark.triangle.fill"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(automaticLocationStatusColor)
                    .frame(width: 18, height: 18)

                VStack(alignment: .leading, spacing: 3) {
                    Text(automaticLocationTitle)
                        .font(.callout.weight(.semibold))
                        .foregroundColor(automaticLocationStatusColor)
                        .lineLimit(1)

                    Text(automaticLocationInfoText)
                        .font(.caption)
                        .foregroundColor(Color("SecondaryTextColor"))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                LocationRefreshButton(
                    action: vm.refetchAutomaticLocation,
                    isDisabled: vm.isRequestingLocation,
                    isRefreshing: vm.isRequestingLocation
                )
            }

            Button("Or, Set Location Manually", action: { showingManualLocationSheet = true })
                .buttonStyle(.link)
                .underline(isHoveringSetManually)
                .frame(maxWidth: .infinity, alignment: .center)
                .onHover { hovering in isHoveringSetManually = hovering }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color("HoverColor").opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color("DividerColor"), lineWidth: 0.5)
        )
    }
}

struct LocationRefreshButton: View {
    let action: () -> Void
    var isDisabled = false
    var isRefreshing = false

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .semibold))
                    .opacity(isRefreshing ? 0 : 1)

                if isRefreshing {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.55)
                }
            }
            .frame(width: 18, height: 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isRefreshing)
        .focusable(false)
        .background(isHovering ? Color("HoverColor") : .clear)
        .cornerRadius(4)
        .opacity(isDisabled && !isRefreshing ? 0.45 : 1)
        .help(Text("Refresh Location"))
        .accessibilityLabel(Text("Refresh Location"))
        .onHover { hovering in
            isHovering = hovering
        }
        .transaction { transaction in
            transaction.animation = nil
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
