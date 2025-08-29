// Salin dan tempel SELURUH kode ini ke dalam file ContentView.swift

import SwiftUI
import CoreLocation
import Combine

indirect enum ActivePage: Equatable {
    case main
    case settings
    case about
    case manualLocation(returnPage: ActivePage)
}

struct ContentView: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    @State private var activePage: ActivePage = .main

    var body: some View {
        // PERBAIKAN FINAL ANTI-GLITCH:
        // Kita bungkus semuanya dalam ZStack dengan Color.clear di lapisan paling bawah.
        // Ini adalah cara yang paling aman untuk membunuh glitch tanpa merusak
        // animasi atau efek blur.
        ZStack {
            Color.clear // Lapisan dasar yang selalu transparan

            VStack {
                // ANIMASI PILIHAN ANDA:
                // Logika transisi per-view yang Anda sukai ditempatkan di sini
                // dan akan berfungsi dengan sempurna.
                switch activePage {
                case .main:
                    MainView(activePage: $activePage)
                        .transition(.opacity)
                case .settings:
                    SettingsView(activePage: $activePage)
                        .transition(.move(edge: .trailing))
                case .about:
                    AboutView(activePage: $activePage)
                        .transition(.move(edge: .trailing))
                case .manualLocation(let returnPage):
                    ManualLocationView(activePage: $activePage, returnPage: returnPage)
                        .transition(.move(edge: .top))
                }
            }
        }
        .frame(width: 260)
        .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.8), value: activePage)
        .onAppear(perform: setInitialPage)
        .onReceive(NotificationCenter.default.publisher(for: .popoverDidClose)) { _ in
            activePage = .main
        }
        .onReceive(vm.$authorizationStatus) { _ in
            setInitialPage()
        }
    }
    
    private func setInitialPage() {
        if !vm.isPrayerDataAvailable && activePage != .manualLocation(returnPage: .main) {
            activePage = .main
        }
    }
}
