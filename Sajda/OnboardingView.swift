// MARK: - GANTI FILE: Sajda/OnboardingView.swift
// Salin dan tempel SELURUH kode ini. Error 'NSViewRepresentable' sudah diperbaiki.

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    @AppStorage("showOnboardingAtLaunch") private var showOnboardingAtLaunch = true

    @State private var showingManualLocationSheet = false
    @State private var isSkipHovering = false

    var body: some View {
        ZStack {
            VisualEffectView()

            VStack(spacing: 20) {
                Spacer()
                
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable().scaledToFit().frame(width: 90, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(spacing: 5) {
                    Text("Welcome to Sajda").font(.system(size: 32, weight: .bold))
                    Text("A beautiful prayer times app for your menu bar.").font(.headline)
                        .foregroundColor(Color("SecondaryTextColor"))
                }
                .multilineTextAlignment(.center)
                
                Divider().padding(.horizontal, 10)
                
                VStack(spacing: 15) {
                    Image(systemName: "location.circle.fill").font(.system(size: 40)).foregroundColor(.accentColor)
                    Text("Location Required").font(.title).fontWeight(.semibold)
                    
                    Text("To provide accurate prayer times, Sajda needs to know your location.")
                        .font(.body).multilineTextAlignment(.center)
                        .foregroundColor(Color("SecondaryTextColor"))
                        .fixedSize(horizontal: false, vertical: true)
                    
                    VStack(spacing: 12) {
                        if vm.isUsingManualLocation {
                            Text("You are using a manual location: **\(vm.locationStatusText)**")
                                .font(.footnote).multilineTextAlignment(.center)
                            Button("Switch to Automatic Location", action: vm.switchToAutomaticLocation)
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                        } else if vm.authorizationStatus == .authorized {
                             Button("Allow Location Access", action: {})
                                .buttonStyle(.borderedProminent).controlSize(.large)
                                .disabled(true)
                             Text("Location access is already enabled.")
                                .font(.footnote).foregroundColor(Color("SecondaryTextColor"))
                             Button("Or, Set Location Manually", action: { showingManualLocationSheet = true })
                        } else {
                            Button("Allow Location Access", action: vm.requestLocationPermission)
                                .buttonStyle(.borderedProminent).controlSize(.large)
                                .disabled(vm.authorizationStatus == .denied)
                            
                            if vm.authorizationStatus == .denied {
                                Text("Please grant location access in System Settings.")
                                    .font(.footnote).foregroundColor(.red)
                            }
                            Button("Or, Set Location Manually", action: { showingManualLocationSheet = true })
                        }
                    }
                    .padding(.top, 10)
                }
                
                Spacer()

                VStack(spacing: 8) {
                    Button(action: { NSApp.keyWindow?.close() }) {
                        Text("Done").font(.headline).frame(maxWidth: 200)
                    }
                    .controlSize(.large).buttonStyle(.borderedProminent).tint(.accentColor)
                    .disabled(!vm.isPrayerDataAvailable)
                    
                    if !vm.isPrayerDataAvailable {
                        Button("Skip for now", action: { NSApp.keyWindow?.close() })
                            .buttonStyle(.plain)
                            .padding(.vertical, 4).padding(.horizontal, 10)
                            .background(isSkipHovering ? Color.secondary.opacity(0.2) : .clear)
                            .cornerRadius(8)
                            .onHover { hovering in isSkipHovering = hovering }
                    }
                }
                
                Toggle("Show this window on launch", isOn: $showOnboardingAtLaunch)
                    .toggleStyle(.checkbox).padding(.top, 15)
                    .foregroundColor(Color("SecondaryTextColor"))
            }
            .padding(.horizontal, 40)
            .padding(.top, 40)
            .padding(.bottom, 60)
        }
        .frame(width: 520, height: 620)
        .sheet(isPresented: $showingManualLocationSheet) {
            ManualLocationSheetView().environmentObject(vm)
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .sidebar
        return view
    }
    
    // --- PERBAIKAN PENTING DI SINI ---
    // Tipe parameter pertama harus `NSVisualEffectView`, sesuai dengan `makeNSView`.
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
