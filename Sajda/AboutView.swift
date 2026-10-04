// MARK: - GANTI SELURUH FILE: Sajda/AboutView.swift

import SwiftUI
import NavigationStack
import MacControlCenterUI

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
    ///
    /// `currentControlTint`, so the page also follows the red alert while a
    /// prayer is imminent — it owns no view model here either, and reads the
    /// same `prayerImminentForTint` mirror as the switches.
    private var aboutAccentColor: Color {
        PrayerTimeViewModel.currentControlTint
    }

    var body: some View {
        ZStack {
            PanelInteriorBackground(material: .popover)

            VStack(alignment: .leading, spacing: 6) {
            Button(action: handleBackButton) {
                HStack {
                    Image(systemName: vm.backChevron).scaledFont(.body, weight: .semibold)
                    Text("About Sajda Pro").scaledFont(.body, weight: .semibold)
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
                            Text("Sajda Pro").scaledFont(.title2, weight: .semibold)
                            Text(verbatim: appVersionText).scaledFont(.caption).foregroundColor(Color("SecondaryTextColor"))
                            Text("by Abrar Zha").scaledFont(.caption).foregroundColor(Color("SecondaryTextColor"))
                        }
                        Text("A simple and beautiful prayer times app for your menu bar.").scaledFont(.subheadline)
                            .multilineTextAlignment(.center).padding(.horizontal)
                    }
                    updateSection
                    supportSection
                    acknowledgementsSection
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
                            .tint(PrayerTimeViewModel.currentControlTint)

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
            }
            // Trimmed from 8pt: the menu container already supplies the
            // panel's edge inset, so the extra pad doubled the dead air.
            .padding(.top, 2)
            .padding(.bottom, 2)
            .frame(width: viewWidth)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .onAppear { updater.revalidateAgainstCurrentVersion() }
        }
    }

    private func handleBackButton() {
        navigationModel.hideView(ContentView.id, animation: vm.backwardAnimation())
    }

    // MARK: - In-app update check (GitHub Releases API)

    @ObservedObject private var updater = UpdateChecker.shared

    /// Library + data credits from the README, collapsible via the shared
    /// settings accordion (starts collapsed so the About page keeps its
    /// compact default height). Descriptions are English source strings —
    /// no per-language entries yet — while the header reuses the global
    /// "Acknowledgements" key.
    @State private var acknowledgementsExpanded = false

    private struct Acknowledgement: Identifiable {
        let id: String
        let url: URL
        let blurb: String
    }

    private var acknowledgements: [Acknowledgement] {
        [
            Acknowledgement(
                id: "Adhan",
                url: URL(string: "https://github.com/batoulapps/Adhan")!,
                blurb: "Prayer time calculation library (MIT)"
            ),
            Acknowledgement(
                id: "ColorSelector",
                url: URL(string: "https://github.com/jaywcjlove/ColorSelector")!,
                blurb: "Colour picker for the highlight colour (MIT)"
            ),
            Acknowledgement(
                id: "FluidMenuBarExtra",
                url: URL(string: "https://github.com/lfroms/fluid-menu-bar-extra")!,
                blurb: "Dynamically resizing menu bar window (MIT, vendored)"
            ),
            Acknowledgement(
                id: "MacControlCenterUI",
                url: URL(string: "https://github.com/orchetect/MacControlCenterUI")!,
                blurb: "Menu builder and controls that mimic macOS Control Center (MIT, vendored)"
            ),
            Acknowledgement(
                id: "MenuBarExtraAccess",
                url: URL(string: "https://github.com/orchetect/MenuBarExtraAccess")!,
                blurb: "Status-item access behind MacControlCenterUI (MIT, transitive)"
            ),
            Acknowledgement(
                id: "NavigationStack",
                url: URL(string: "https://github.com/indieSoftware/NavigationStack")!,
                blurb: "View navigation system (MIT)"
            ),
            Acknowledgement(
                id: "Sparkle",
                url: URL(string: "https://sparkle-project.org")!,
                blurb: "In-app updates, signed and verified (MIT)"
            ),
            Acknowledgement(
                id: "Adhan recordings",
                url: URL(string: "https://archive.org/details/adhan.notifications")!,
                blurb: "Bundled adhan audio, Public Domain Mark 1.0 (archive.org)"
            ),
            Acknowledgement(
                id: "Doha adhan recordings",
                url: URL(string: "https://archive.org/details/adhan.recordings.from.doha.qatar")!,
                blurb: "Bundled Fajr adhan audio, Public Domain Mark 1.0 (archive.org)"
            ),
            Acknowledgement(
                id: "OpenStreetMap Nominatim",
                url: URL(string: "https://wiki.openstreetmap.org/wiki/Nominatim")!,
                blurb: "City search; results © OpenStreetMap contributors (ODbL)"
            ),
            Acknowledgement(
                id: "App artwork",
                url: URL(string: "https://thenounproject.com/icon/mosque-3364513/")!,
                blurb: "Menu-bar mosque glyph and app icon: Mosque by Nawicon from Noun Project (CC BY 3.0)"
            ),
        ]
    }

    private var acknowledgementsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsAccordion(
                titleKey: "Acknowledgements",
                isExpanded: acknowledgementsExpanded,
                collapsedChevron: vm.forwardChevron,
                onToggle: { acknowledgementsExpanded.toggle() }
            ) {
                ForEach(acknowledgements) { item in
                    Button(action: { NSWorkspace.shared.open(item.url) }) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(verbatim: item.id)
                                .scaledFont(.subheadline, weight: .medium)
                                .foregroundColor(.primary)
                            Text(verbatim: item.blurb)
                                .scaledFont(.caption2)
                                .foregroundColor(Color("SecondaryTextColor"))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 8)
                        .liquidHover(isAcknowledgementHover(id: item.id))
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        if hovering {
                            hoveringAcknowledgementID = item.id
                        } else if hoveringAcknowledgementID == item.id {
                            hoveringAcknowledgementID = nil
                        }
                    }
                }
            }
            .padding(.horizontal, 5)
        }
    }

    @State private var hoveringAcknowledgementID: String? = nil

    private func isAcknowledgementHover(id: String) -> Bool {
        hoveringAcknowledgementID == id
    }

    private var updateSection: some View {
        VStack(spacing: 8) {
            switch updater.state {
            case .updateAvailable(let version, _):
                // Hands over to Sparkle, which downloads, verifies the EdDSA
                // signature and installs the new build.
                Button(action: { updater.checkManually() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text(String(format: NSLocalizedString("Update available: %@", comment: ""), version))
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: vm.forwardChevron)
                            .scaledFont(.caption, weight: .semibold)
                    }
                    .padding(.vertical, 5).padding(.horizontal, 8)
                }
                .buttonStyle(.plain)
                // Text AND icon tone follow the pick's legibility, not a fixed
                // white: a pale highlight (pastel yellow, light mint, …) with
                // white text was unreadable until clicked (#24). The fill
                // keeps the user's colour; the content flips to black on pale
                // picks via the same WCAG test the highlight rows use.
                //
                // Judged against `effectiveHighlightHex`, not the raw pick: the
                // fill below follows the red alert while a prayer is imminent,
                // and a tone chosen for the calm pick would be unreadable on it.
                .foregroundColor(PrayerTimeViewModel.onFillColorForHighlight(vm.effectiveHighlightHex))
                .background(RoundedRectangle(cornerRadius: 6).fill(aboutAccentColor))
                .help(NSLocalizedString("Download and install the update", comment: ""))
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
                    updateTextButton("Check for Updates")
                }
            case .failed:
                VStack(spacing: 4) {
                    Text("Couldn't check for updates.").scaledFont(.caption)
                        .foregroundColor(Color("SecondaryTextColor"))
                    // Same as above: plain + colour instead of `.link`.
                    updateTextButton("Try Again")
                }
            case .idle:
                Button(action: { updater.checkManually() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Check for Updates").scaledFont(.subheadline)
                    }
                    .padding(.vertical, 5).padding(.horizontal, 8)
                    // Padding, hover pill and hit shape all *inside* the label,
                    // so the whole visible pill is the click target.
                    .contentShape(Rectangle())
                    .liquidHover(isUpdateHovering, cornerRadius: 6)
                }
                .buttonStyle(.plain)
                .foregroundColor(aboutAccentColor)
                .onHover { hovering in isUpdateHovering = hovering }
            }
        }
        .padding(.horizontal, 12)
    }

    /// One-tap way to back the project: Ko-fi (matches FUNDING.yml) plus the
    /// GitHub Sponsors profile for anyone who prefers it. Kept as two
    /// caption rows — same visual weight as the acknowledgements below —
    /// so the page stays compact and donation never reads as a banner.
    /// Requested in #24 ("no Sponsor button or donation link").
    private var supportSection: some View {
        VStack(spacing: 4) {
            supportRow(
                icon: "heart.circle",
                titleKey: "Support Sajda",
                url: URL(string: "https://ko-fi.com/ikoshura"),
                helpKey: "Support Sajda on Ko-fi"
            )
            supportRow(
                icon: "gift.circle",
                titleKey: "Sponsor on GitHub",
                url: URL(string: "https://github.com/sponsors/ikoshura"),
                helpKey: "Sponsor ikoshura on GitHub"
            )
        }
        .padding(.horizontal, 12)
    }

    @State private var hoveringSupportID: String? = nil

    private func supportRow(icon: String, titleKey: String, url: URL?, helpKey: String) -> some View {
        Button(action: { if let url { NSWorkspace.shared.open(url) } }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(NSLocalizedString(titleKey, comment: "")).scaledFont(.subheadline)
                Spacer()
                Image(systemName: vm.forwardChevron)
                    .scaledFont(.caption, weight: .semibold)
            }
            .padding(.vertical, 5).padding(.horizontal, 8)
            .contentShape(Rectangle())
            .liquidHover(hoveringSupportID == titleKey, cornerRadius: 6)
        }
        .buttonStyle(.plain)
        .foregroundColor(aboutAccentColor)
        .onHover { hovering in hoveringSupportID = hovering ? titleKey : nil }
        .help(Text(NSLocalizedString(helpKey, comment: "")))
    }

    /// The small caption-sized "Check for Updates" / "Try Again" links.
    ///
    /// They used to be bare `Button(title).buttonStyle(.plain)`, where only
    /// the glyph pixels themselves are hit-testable — you had to land exactly
    /// on the text. Padding, hover pill and content shape now live in the
    /// label, so the whole padded pill is clickable and the hover is visible
    /// instead of floating invisibly around the text.
    private func updateTextButton(_ titleKey: String) -> some View {
        Button(action: { updater.checkManually() }) {
            Text(NSLocalizedString(titleKey, comment: ""))
                .scaledFont(.caption)
                .padding(.vertical, 4).padding(.horizontal, 8)
                .contentShape(Rectangle())
                .liquidHover(isUpdateHovering, cornerRadius: 6)
        }
        .buttonStyle(.plain)
        .foregroundColor(aboutAccentColor)
        .onHover { hovering in isUpdateHovering = hovering }
        // Same affordance as the idle pill, so the action is discoverable
        // wherever the checker happens to be in its cycle.
        .help(NSLocalizedString("Check for the latest version", comment: ""))
    }
}
