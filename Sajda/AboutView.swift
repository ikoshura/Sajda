// MARK: - GANTI SELURUH FILE: Sajda/AboutView.swift

import SwiftUI
import NavigationStack

struct AboutView: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    @EnvironmentObject var navigationModel: NavigationModel

    @AppStorage("showOnboardingAtLaunch") private var showOnboardingAtLaunch = true
    /// Selected highlight colour, so the checkbox uses the same colour as the
    /// settings switches (nil/system accent when no colour is selected).
    @AppStorage("customHighlightColorHex") private var customHighlightColorHex = ""
    @State private var isHeaderHovering = false
    @State private var isUpdateHovering = false
    // State isDoneHovering sudah dihapus karena tidak lagi diperlukan.

    private var viewWidth: CGFloat {
        return vm.panelWidth(base: vm.useCompactLayout ? 220 : 260)
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "3.5.0"
        return "Version \(version)"
    }

    /// Selected highlight colour (system accent when none is picked): the
    /// About icon's monochrome tint, the Done button's fill, and the update
    /// pill below all use it, so the whole page follows one colour.
    private var aboutAccentColor: Color {
        PrayerTimeViewModel.controlTint(fromHighlightHex: customHighlightColorHex) ?? .accentColor
    }

    var body: some View {
        ZStack {
            PanelInteriorBackground(material: .popover)

            VStack(alignment: .leading, spacing: 6) {
            Button(action: handleBackButton) {
                HStack {
                    Image(systemName: vm.backChevron).scaledFont(.body, weight: .semibold)
                    Text("About Sajda Pro").scaledFont(.body, weight: .bold)
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
                        // Monochrome in the selected highlight colour: the
                        // tint supplies hue and saturation while the artwork
                        // supplies the luminosity, so the icon reads as one
                        // colour and fuses with the rest of the panel.
                        Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                            .resizable().scaledToFit().frame(width: 64, height: 64)
                            .overlay {
                                aboutAccentColor.blendMode(.color)
                            }
                            // The artwork's own alpha gates the tint: the .icns
                            // square carries transparent padding, so without the
                            // mask the colour would bleed past the icon's edge.
                            .mask {
                                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                                    .resizable().scaledToFit().frame(width: 64, height: 64)
                            }
                        VStack(spacing: 2) {
                            Text("Sajda Pro").scaledFont(.title2, weight: .bold)
                            Text(verbatim: appVersionText).scaledFont(.caption).foregroundColor(Color("SecondaryTextColor"))
                            Text("by Abrar Zha").scaledFont(.caption).foregroundColor(Color("SecondaryTextColor"))
                        }
                        Text("A simple and beautiful prayer times app for your menu bar.").scaledFont(.subheadline)
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
                            .tint(PrayerTimeViewModel.controlTint(fromHighlightHex: customHighlightColorHex))

                        Button(action: handleBackButton) {
                            Text("Done")
                                .frame(maxWidth: 100) // Memberikan lebar yang cukup
                        }
                        .buttonStyle(.borderedProminent) // Gaya native yang menonjol
                        .controlSize(.regular) // Ukuran tombol standar
                        // Pill: clip the native prominent background to a
                        // capsule so both ends are fully rounded.
                        .clipShape(Capsule())
                        // Fill follows the selected highlight colour.
                        .tint(aboutAccentColor)
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
                            .scaledFont(.caption, weight: .bold)
                    }
                    .padding(.vertical, 5).padding(.horizontal, 8)
                }
                .buttonStyle(.plain)
                // The pill follows the selected highlight colour — same text
                // and background balance as the Done button — instead of a
                // tinted system-accent look.
                .foregroundColor(.white)
                .background(RoundedRectangle(cornerRadius: 6).fill(aboutAccentColor))
                .help(NSLocalizedString("Open the release page to download", comment: ""))
            case .checking:
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Checking for updates...").scaledFont(.caption)
                        .foregroundColor(Color("SecondaryTextColor"))
                }
            case .upToDate:
                VStack(spacing: 4) {
                    Text("You're up to date.").scaledFont(.caption)
                        .foregroundColor(Color("SecondaryTextColor"))
                    // Follows the selected highlight colour like the rest of
                    // the page — `.link` here would hard-code the system
                    // accent regardless of the pick.
                    Button("Check for Updates") { updater.checkManually() }
                        .buttonStyle(.plain)
                        .foregroundColor(aboutAccentColor)
                        .scaledFont(.caption)
                }
            case .failed:
                VStack(spacing: 4) {
                    Text("Couldn't check for updates.").scaledFont(.caption)
                        .foregroundColor(Color("SecondaryTextColor"))
                    // Same as above: plain + colour instead of `.link`.
                    Button("Try Again") { updater.checkManually() }
                        .buttonStyle(.plain)
                        .foregroundColor(aboutAccentColor)
                        .scaledFont(.caption)
                }
            case .idle:
                Button(action: { updater.checkManually() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Check for Updates").scaledFont(.subheadline)
                    }
                    .padding(.vertical, 5).padding(.horizontal, 8)
                }
                .buttonStyle(.plain)
                .foregroundColor(aboutAccentColor)
                .liquidHover(isUpdateHovering)
                .onHover { hovering in isUpdateHovering = hovering }
            }
        }
        .padding(.horizontal, 12)
    }
}
