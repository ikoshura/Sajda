// Ganti seluruh kode di PermissionView.swift dengan ini

import SwiftUI
import CoreLocation

struct PermissionView: View {
    @ObservedObject var vm: PrayerTimeViewModel
    
    @State private var isAllowHovering = false
    @State private var isSettingsHovering = false
    @State private var isQuitHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            
            HStack {
                Text("Sajda").font(.body).fontWeight(.bold)
                Spacer()
            }.padding(.horizontal, 12).padding(.top, 4)

            Divider().padding(.horizontal, 12)
            
            VStack(spacing: 15) {
                Image(systemName: "location.circle.fill").font(.system(size: 40)).foregroundColor(.secondary).padding(.top)
                Text("Location Access Required").font(.headline)
                Text("Sajda needs your location to accurately calculate prayer times.")
                    .font(.subheadline).multilineTextAlignment(.center).foregroundColor(.secondary).padding(.horizontal)
            }
            
            Spacer(minLength: 0)

            Divider().padding(.horizontal, 12)
            
            VStack(alignment: .leading, spacing: 0) {
                if vm.authorizationStatus == .notDetermined {
                    Button(action: { vm.requestLocationPermission() }) {
                        HStack { Text("Allow Location Access"); Spacer() }
                        .padding(.vertical, 5).padding(.horizontal, 8)
                        .background(Color.secondary.opacity(isAllowHovering ? 0.25 : 0)).cornerRadius(5)
                    }.buttonStyle(.plain).padding(.horizontal, 5).onHover { hovering in isAllowHovering = hovering }
                } else if vm.authorizationStatus == .denied {
                    Button(action: {
                        if let url = URL(string: "x-apple-systempreferences:com.apple.preference.security?Privacy_LocationServices") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack { Text("Open System Settings"); Spacer() }
                        .padding(.vertical, 5).padding(.horizontal, 8)
                        .background(Color.secondary.opacity(isSettingsHovering ? 0.25 : 0)).cornerRadius(5)
                    }.buttonStyle(.plain).padding(.horizontal, 5).onHover { hovering in isSettingsHovering = hovering }
                }
                
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
