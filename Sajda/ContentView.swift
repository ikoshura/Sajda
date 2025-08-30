// MARK: - GANTI FILE: Sajda/ContentView.swift
// Salin dan tempel SELURUH kode ini ke dalam file ContentView.swift

import SwiftUI
import CoreLocation
import Combine

indirect enum ActivePage: Equatable {
    case main
    case settings
    case about
    case correction
    case manualLocation(returnPage: ActivePage)
}

struct ContentView: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    @State private var activePage: ActivePage = .main

    var body: some View {
        ZStack {
            Color.clear

            VStack {
                switch activePage {
                case .main:
                    MainView(activePage: $activePage)
                        .transition(.opacity)
                
                case .settings:
                    SettingsView(activePage: $activePage)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .trailing)
                        ))
                
                // --- PERBAIKAN: Animasi keluar diubah menjadi menghilang (fade-out) ---
                case .correction:
                    PrayerTimeCorrectionView(activePage: $activePage)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top),
                            removal: .opacity
                        ))
                // --- AKHIR PERBAIKAN ---
                
                case .about:
                    AboutView(activePage: $activePage)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom),
                            removal: .offset(y: 400)
                        ))
                        
                case .manualLocation(let returnPage):
                    ManualLocationView(activePage: $activePage, returnPage: returnPage)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top),
                            removal: .offset(y: 400)
                        ))
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: activePage)
        .onAppear(perform: setInitialPage)
        .onReceive(NotificationCenter.default.publisher(for: .popoverDidClose)) { _ in
            activePage = .main
        }
        .onReceive(vm.$authorizationStatus) { newStatus in
            if newStatus == .denied && !vm.isUsingManualLocation {
                activePage = .main
            }
            setInitialPage()
        }
    }
    
    private func setInitialPage() {
        if !vm.isPrayerDataAvailable && activePage != .manualLocation(returnPage: .main) {
            activePage = .main
        }
    }
}
