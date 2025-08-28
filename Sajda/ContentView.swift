// Ganti seluruh kode di ContentView.swift dengan ini

import SwiftUI
import CoreLocation

enum ActivePage {
    case main
    case settings
    case calculationSettings
    case about
}

struct ContentView: View {
    @ObservedObject var vm: PrayerTimeViewModel
    @State private var activePage: ActivePage = .main
    
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch vm.authorizationStatus {
            case .authorized:
                ZStack {
                    // FIX: Logika transisi baru yang mengikuti hirarki
                    
                    // MainView selalu terlihat jika tidak ada halaman lain di atasnya
                    if activePage == .main {
                        MainView(vm: vm, activePage: $activePage)
                            .transition(.opacity.animation(.easeInOut(duration: 0.1))) // Fade in/out halus
                    }
                    
                    // SettingsView muncul di atas MainView
                    if activePage == .settings || activePage == .calculationSettings {
                        SettingsView(vm: vm, activePage: $activePage)
                            .transition(.move(edge: .trailing)) // Masuk dari kanan
                    }
                    
                    // CalculationSettingsView muncul di atas SettingsView
                    if activePage == .calculationSettings {
                        CalculationSettingsView(vm: vm, activePage: $activePage)
                            .transition(.move(edge: .trailing)) // Masuk dari kanan
                    }
                    
                    // AboutView muncul di atas MainView
                    if activePage == .about {
                        AboutView(activePage: $activePage)
                            .transition(.move(edge: .trailing)) // Masuk dari kanan
                    }
                }
                
            case .notDetermined, .denied, .restricted:
                PermissionView(vm: vm)
                    .transition(.move(edge: .trailing))
                    
            @unknown default:
                Text("An unexpected error occurred.")
            }
        }
        .frame(width: 260)
        .background(.ultraThinMaterial)
        .animation(.easeInOut(duration: 0.2), value: activePage)
        .animation(.easeInOut(duration: 0.2), value: vm.authorizationStatus)
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                activePage = .main
            }
        }
    }
}
