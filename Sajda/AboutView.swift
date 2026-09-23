// MARK: - GANTI SELURUH FILE: Sajda/AboutView.swift

import SwiftUI
import NavigationStack

struct AboutView: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    @EnvironmentObject var navigationModel: NavigationModel

    @AppStorage("showOnboardingAtLaunch") private var showOnboardingAtLaunch = true
    @State private var isHeaderHovering = false
    @State private var isUpdateHovering = false
    // State isDoneHovering sudah dihapus karena tidak lagi diperlukan.

    private var viewWidth: CGFloat {
        return vm.useCompactLayout ? 220 : 260
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "3.5.0"
        return "Version \(version)"
    }

    var body: some View {
        ZStack {
            PanelInteriorBackground(material: .popover)

            VStack(alignment: .leading, spacing: 6) {
            Button(action: handleBackButton) {
                HStack {
                    Image(systemName: vm.backChevron).font(.body.weight(.semibold))
                    Text("About Sajda Pro").font(.body).fontWeight(.bold)
                    Spacer()
                }
                .padding(.vertical, 5).padding(.horizontal, 8)
                .liquidHover(isHeaderHovering)
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
                            Text(verbatim: appVersionText).font(.caption).foregroundColor(Color("SecondaryTextColor"))
                            Text("by Abrar Zha").font(.caption).foregroundColor(Color("SecondaryTextColor"))
                        }
                        Text("A simple and beautiful prayer times app for your menu bar.").font(.subheadline)
                            .multilineTextAlignment(.center).padding(.horizontal)
                    }
                    updateSection
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
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func handleBackButton() {
        navigationModel.hideView(ContentView.id, animation: vm.backwardAnimation())
    }

    // MARK: - In-app update check (GitHub Releases API)

    @ObservedObject private var updater = UpdateChecker.shared

    private var updateSection: some View {
        VStack(spacing: 8) {
            switch updater.state {
            case .updateAvailable(let version, _):
                Button(action: { updater.openReleasePage() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text(String(format: NSLocalizedString("Update available: %@", comment: ""), version))
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: vm.forwardChevron)
                            .font(.caption.weight(.bold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 5).padding(.horizontal, 8)
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.12)))
                .help(NSLocalizedString("Open the release page to download", comment: ""))
            case .checking:
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Checking for updates...").font(.caption)
                        .foregroundColor(Color("SecondaryTextColor"))
                }
            case .upToDate:
                VStack(spacing: 4) {
                    Text("You're up to date.").font(.caption)
                        .foregroundColor(Color("SecondaryTextColor"))
                    Button("Check for Updates") { updater.checkManually() }
                        .buttonStyle(.link).font(.caption)
                }
            case .failed:
                VStack(spacing: 4) {
                    Text("Couldn't check for updates.").font(.caption)
                        .foregroundColor(Color("SecondaryTextColor"))
                    Button("Try Again") { updater.checkManually() }
                        .buttonStyle(.link).font(.caption)
                }
            case .idle:
                Button(action: { updater.checkManually() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Check for Updates").font(.subheadline)
                    }
                    .padding(.vertical, 5).padding(.horizontal, 8)
                }
                .buttonStyle(.plain)
                .liquidHover(isUpdateHovering)
                .onHover { hovering in isUpdateHovering = hovering }
            }
        }
        .padding(.horizontal, 12)
    }
}
