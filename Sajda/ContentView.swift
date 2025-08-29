
// Salin dan tempel seluruh kode ini ke dalam file ContentView.swift

import SwiftUI
import CoreLocation

enum ActivePage {
    case main
    case settings
    case about
}

struct ContentView: View {
    @ObservedObject var vm: PrayerTimeViewModel
    @State private var activePage: ActivePage = .main

    var body: some View {
        Group {
            switch vm.authorizationStatus {
            case .authorized:
                switch activePage {
                case .main:
                    MainView(vm: vm, activePage: $activePage)
                        .transition(.opacity)
                case .settings:
                    SettingsView(vm: vm, activePage: $activePage)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                case .about:
                    AboutView(activePage: $activePage)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            case .notDetermined, .denied, .restricted:
                PermissionView(vm: vm)
                    .transition(.opacity)
            @unknown default:
                Text("An unexpected error occurred.")
            }
        }
        .animation(.easeInOut(duration: 0.2), value: activePage)
    }
}
