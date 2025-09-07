// MARK: - GANTI SELURUH FILE: Sajda/AboutView.swift

import SwiftUI
import NavigationStack

struct AboutView: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    @EnvironmentObject var navigationModel: NavigationModel
    
    @AppStorage("showOnboardingAtLaunch") private var showOnboardingAtLaunch = true
    @State private var isHeaderHovering = false
    // State isDoneHovering sudah dihapus karena tidak lagi diperlukan.
    
    private var viewWidth: CGFloat {
        return vm.useCompactLayout ? 220 : 260
    }

    var body: some View {
        ZStack {
            VisualEffectView(material: .popover).ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 6) {
                Button(action: handleBackButton) {
                    HStack {
                        Image(systemName: "chevron.left").font(.body.weight(.semibold))
                        Text("About Sajda Pro").font(.body).fontWeight(.bold)
                        Spacer()
                    }
                    .padding(.vertical, 5).padding(.horizontal, 8)
                    .background(isHeaderHovering ? Color("HoverColor") : .clear)
                    .cornerRadius(5)
                }.buttonStyle(.plain).padding(.horizontal, 5).onHover { hovering in isHeaderHovering = hovering }
                
                Rectangle()
                    .fill(Color("DividerColor"))
                    .frame(height: 0.5)
                    .padding(.horizontal, 12)
                
                VStack(spacing: 12) {
                    VStack(spacing: 12) {
                        Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                            .resizable().scaledToFit().frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        VStack(spacing: 2) {
                            Text("Sajda Pro").font(.title2).fontWeight(.bold)
                            Text("Version 3.1.1").font(.caption).foregroundColor(Color("SecondaryTextColor"))
                            Text("by Abrar Zha").font(.caption).foregroundColor(Color("SecondaryTextColor"))
                        }
                        Text("A simple and beautiful prayer times app for your menu bar.").font(.subheadline)
                            .multilineTextAlignment(.center).padding(.horizontal)
                    }
                    // --- PERUBAHAN DI SINI ---
                    // Mengganti tombol kustom dengan tombol native macOS.
                    Rectangle()
                        .fill(Color("DividerColor"))
                        .frame(height: 1)
                        .padding(.horizontal, 12)
                    VStack(spacing: 16) {
                        Toggle("Show Welcome Guide on Launch", isOn: $showOnboardingAtLaunch)
                            .toggleStyle(.checkbox)
                            .controlSize(.small)

                        Button(action: handleBackButton) {
                            Text("Done")
                                .frame(maxWidth: 100) // Memberikan lebar yang cukup
                        }
                        .buttonStyle(.borderedProminent) // Gaya native yang menonjol
                        .controlSize(.regular) // Ukuran tombol standar
                        .keyboardShortcut(.defaultAction) // Menjadikannya aksi default (Enter)
                    }
                    .padding(.bottom, 12)
                    
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }.padding(.vertical, 8)
            .frame(width: viewWidth)
        }
    }

    private func handleBackButton() {
        navigationModel.hideView(ContentView.id, animation: vm.backwardAnimation())
    }
}
