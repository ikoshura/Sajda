// MARK: - GANTI SELURUH FILE: MainView.swift

import SwiftUI
import Adhan
import NavigationStack

struct MainView: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    @EnvironmentObject var navigationModel: NavigationModel
    @State private var isSettingsHovering = false
    @State private var isAboutHovering = false
    @State private var isQuitHovering = false
    @State private var isLocationHovering = false
    /// Location row. A push to the Favorites page (same NavigationStack
    /// mechanism as Settings/About): tapping opens FavoritesView, and the
    /// accordion state lives on that page's @State — so it is born shut on
    /// every open and every return, with no reset logic anywhere. Outer 4pt
    /// + inner 8pt = 12pt, the same gutter PrayerListView's rows use.
    @ViewBuilder
    private var locationFavoritesBlock: some View {
        Button(action: {
            navigationModel.showView(ContentView.id, animation: vm.forwardAnimation()) { FavoritesView() }
        }) {
            HStack(spacing: 4) {
                Text(vm.panelLocationCaption)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                Image(systemName: vm.forwardChevron)
                    .scaledFont(.caption, weight: .bold)
                    .foregroundColor(.secondary)
            }
            .scaledFont(.caption).foregroundColor(Color("SecondaryTextColor"))
            .padding(.vertical, 5).padding(.horizontal, 8)
            .liquidHover(isLocationHovering)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .onHover { hovering in isLocationHovering = hovering }
        .help(Text(NSLocalizedString("Location", comment: "")))
        .accessibilityLabel(Text(NSLocalizedString("Location", comment: "")))
        .accessibilityHint(Text(NSLocalizedString("Opens the location list", comment: "")))
        .accessibilityAddTraits(.isButton)
    }

    private var viewWidth: CGFloat { return vm.panelWidth(base: vm.useCompactLayout ? 220 : 260) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // Left edge lines up with the location caption and prayer rows
                // below (the panel's 12pt gutter); no arrow here — the main
                // page has nothing to go back to.
                Text("Sajda").scaledFont(.body, weight: .bold)
                Spacer()
                if vm.isPrayerDataAvailable && vm.menuBarTextMode == .hidden {
                    Text(vm.headerCountdownText).scaledFont(.body).lineLimit(1).minimumScaleFactor(0.7).foregroundColor(vm.isPrayerImminent ? .red : Color("SecondaryTextColor")).transition(.opacity.animation(.easeInOut))
                }
                // Hijri date (Umm al-Qura), flush to the panel's trailing
                // edge. It yields space first (low layout priority) so the
                // optional countdown still fits in the compact layout.
                Text(vm.hijriDateText)
                    .scaledFont(.caption)
                    .foregroundColor(Color("SecondaryTextColor"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .layoutPriority(-1)
            }
            // Same vertical row metrics as the pushed pages' headers (5pt inner
            // vertical padding) so the title sits at the same height as the
            // Settings / Adhan Sound / Accessibility titles.
            .padding(.vertical, 2)
            .padding(.horizontal, 12)
            .padding(.top, 1)

            Rectangle()
                .fill(Color("DividerColor"))
                .frame(height: 0.5)
                .padding(.horizontal, 12)

            // Countdown card (when on) keeps the top slot under the divider.
            // Location block moves around it: above the prayer list when the
            // card is off, below the list when the card is on.
            let showCountdownCard = vm.isPrayerDataAvailable && vm.showCountdownHeader && vm.nextPrayerOccurrenceDate != nil
            if showCountdownCard {
                NextPrayerCountdownHeader()
            }

            if vm.isPrayerDataAvailable && !showCountdownCard {
                locationFavoritesBlock
            }

            // Keep the prayer list snug under whatever sits above it —
            // compact 4pt rhythm through PrayerListView's rows.
            if vm.isPrayerDataAvailable {
                PrayerListView()
            } else {
                Spacer()
                PermissionRequestView()
                Spacer()
            }

            if vm.isPrayerDataAvailable && showCountdownCard {
                // Separator between the prayer list and the location row
                // (countdown-active layout only — otherwise the row sits
                // directly under the top divider).
                Rectangle()
                    .fill(Color("DividerColor"))
                    .frame(height: 0.5)
                    .padding(.horizontal, 12)
                locationFavoritesBlock
            }

            // One separator after the prayer times, then a single compact
            // line of SF Symbols: Quit on the leading edge, About and
            // Settings trailing. The text labels move to hover tooltips and
            // VoiceOver since the icons stand alone.
            VStack(alignment: .leading, spacing: 0) {
                Rectangle()
                    .fill(Color("DividerColor"))
                    .frame(height: 1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 2)

                HStack(spacing: 2) {
                    Button(action: { NSApp.terminate(nil) }) {
                        Image(systemName: "power")
                            .scaledFont(.body)
                            .padding(.vertical, 5).padding(.horizontal, 8)
                            .liquidHover(isQuitHovering)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in isQuitHovering = hovering }
                    // --- PERBAIKAN DI SINI ---
                    .focusable(false)
                    .help(Text(NSLocalizedString("Quit", comment: "")))
                    .accessibilityLabel(Text(NSLocalizedString("Quit", comment: "")))

                    Spacer(minLength: 0)

                    Button(action: {
                        navigationModel.showView(ContentView.id, animation: vm.forwardAnimation()) { AboutView() }
                    }) {
                        Image(systemName: "info.circle")
                            .scaledFont(.body)
                            .padding(.vertical, 5).padding(.horizontal, 8)
                            .liquidHover(isAboutHovering)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in isAboutHovering = hovering }
                    // --- PERBAIKAN DI SINI ---
                    .focusable(false)
                    .help(Text(NSLocalizedString("About", comment: "")))
                    .accessibilityLabel(Text(NSLocalizedString("About", comment: "")))

                    Button(action: {
                        // Unlocked always enters on Display; locked keeps the
                        // last-used tab. The tab persists in
                        // vm.settingsSelectedTab so the exit fade can't flash.
                        if !vm.settingsTabLocked {
                            vm.settingsSelectedTab = "display"
                        }
                        navigationModel.showView(ContentView.id, animation: vm.forwardAnimation()) { SettingsView() }
                    }) {
                        Image(systemName: "gearshape")
                            .scaledFont(.body)
                            .padding(.vertical, 5).padding(.horizontal, 8)
                            .liquidHover(isSettingsHovering)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in isSettingsHovering = hovering }
                    // --- PERBAIKAN DI SINI ---
                    .focusable(false)
                    .help(Text(NSLocalizedString("Settings", comment: "")))
                    .accessibilityLabel(Text(NSLocalizedString("Settings", comment: "")))
                }
                .padding(.horizontal, 5)
            }
        }
        // Trimmed from 8pt: the library's ~6pt menu chrome already provides
        // the panel's edge inset, so the extra pad read as dead air above the
        // header and below the footer row.
        .padding(.top, 2)
        .padding(.bottom, 2)
        .frame(width: viewWidth)

    }
}

struct PrayerListView: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    @Environment(\.colorScheme) private var colorScheme
    private var prayerOrder: [String] {
        let defaultOrder = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
        let sunnahOrder = ["Tahajud", "Fajr", "Dhuha", "Dhuhr", "Asr", "Maghrib", "Isha"]
        let baseOrder = vm.showSunnahPrayers ? sunnahOrder : defaultOrder
        return baseOrder.filter { vm.todayTimes.keys.contains($0) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(spacing: 0) {
                ForEach(prayerOrder, id: \.self) { prayerName in
                    if let prayerTime = vm.todayTimes[prayerName] {
                        let isNextPrayer = prayerName == vm.nextPrayerName
                        // After Isha the highlighted Fajr is tomorrow's occurrence;
                        // format the same Date the menu bar uses so the panel and
                        // menu bar can never show different minutes.
                        let displayTime = prayerName == "Fajr" ? (vm.displayedFajrTime ?? prayerTime) : prayerTime
                        let (highlightColor, textColor): (Color, Color) = {
                            guard isNextPrayer else { return (.clear, .primary) }
                            return vm.nextPrayerHighlight()
                        }()
                        HStack {
                            Text(vm.prayerDisplayName(prayerName)); Spacer()
                            if vm.isAdhanPlaying && prayerName == vm.activeAdhanPrayerName {
                                Button(action: { vm.stopAdhan() }) {
                                    Image(systemName: "speaker.slash.fill")
                                        .scaledFont(.caption)
                                        .foregroundColor(textColor)
                                }
                                .buttonStyle(.plain)
                                .help("Stop Adhan")
                            }
                            if prayerName == "Tahajud" || prayerName == "Dhuha" { Text("Around").scaledFont(.caption).foregroundColor(isNextPrayer ? textColor.opacity(0.8) : Color("SecondaryTextColor")) }
                            Text(vm.dateFormatter.string(from: displayTime)).scaledFont(.body, weight: isNextPrayer ? .bold : nil)
                        }
                        .foregroundColor(textColor).fontWeight((isNextPrayer || vm.accessibilityBoldText) ? .bold : .regular).padding(.horizontal, 12).padding(.vertical, 5).background {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6).fill(highlightColor)
                                if isNextPrayer, vm.useGlassPrayerHighlight {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color.clear)
                                        .glassCard(cornerRadius: 6, interactive: true)
                                        // Glass gelap hanya untuk highlight aksen (teks
                                        // putih): glass terang di atas aksen di mode terang
                                        // terlalu memutih. Non-ikut skema aslinya.
                                        .environment(\.colorScheme, (vm.useAccentColor || vm.customHighlightColor != nil) ? .dark : colorScheme)
                                }
                            }
                        }
                    }
                }
            }.padding(.horizontal, 5).padding(.top, 4)
        }
    }
}

/// Big "ASR IN 00:13:01" card above the schedule, mirroring the Mawaqit-style
/// header. Shares the row highlight logic via `nextPrayerHighlight()` so the
/// custom color/accent/imminent states always match the highlighted row, and
/// shares the glass treatment via `useGlassPrayerHighlight`.
struct NextPrayerCountdownHeader: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = vm.nextPrayerHighlight()
        let timesLine = adhanAndIqamaLine
        VStack(spacing: 4) {
            Text(String(format: NSLocalizedString("prayer_countdown_in", comment: ""), vm.prayerDisplayName(vm.nextPrayerName)))
                .scaledFont(.caption, weight: .semibold)
                .textCase(.uppercase)
            Text(vm.detailedCountdown)
                // Plain San Francisco like the rest of the panel (the rounded
                // variant was the only font that didn't match).
                .font(.system(size: 38, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            // Adhan and iqama share one line, separated by the panel's middle dot
            // ("Adhan at 06:10 • Iqama at 06:30"). Sunnah prayers have no adhan,
            // so theirs reads "Around 05:10". Iqama only exists in mosque mode;
            // the mosque's published time or the usual local gap after the
            // adhan (see `nextPrayerIqamaDate`).
            if !timesLine.isEmpty {
                Text(timesLine)
                    .scaledFont(.caption)
                    .opacity(0.85)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .foregroundColor(colors.text)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(colors.fill)
                if vm.useGlassPrayerHighlight {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.clear)
                        .glassCard(cornerRadius: 10, interactive: true)
                        // Same reasoning as the schedule row: light glass over an
                        // accent fill washes out in light mode, so accent mode
                        // always renders the darker variant.
                        .environment(\.colorScheme, (vm.useAccentColor || vm.customHighlightColor != nil) ? .dark : colorScheme)
                }
            }
        }
        // The same 5 pt inset the schedule rows use, so the card's left and right
        // edges line up exactly with the highlighted prayer row beneath it.
        .padding(.horizontal, 5)
        .padding(.top, 2)
        .accessibilityLabel(Text(accessibilityText))
    }

    /// Adhan and iqama on one line, separated by the middle dot used across the
    /// panel. Parts that don't exist yet are dropped, so on calculated times the
    /// line degrades to the adhan alone.
    private var adhanAndIqamaLine: String { adhanAndIqamaParts.joined(separator: " • ") }

    private var adhanAndIqamaParts: [String] {
        var parts: [String] = []
        if let occurrence = vm.nextPrayerOccurrenceDate {
            // Sunnah prayers (Tahajud, Dhuha) are estimated times with no
            // adhan, so the header reads "Around 05:10" — the same word the
            // schedule row uses — instead of "Adhan at 05:10".
            let key = AdhanType.sunnahPrayers.contains(vm.nextPrayerName)
                ? "around_at_time" : "adhan_at_time"
            parts.append(String(format: NSLocalizedString(key, comment: ""),
                                vm.dateFormatter.string(from: occurrence)))
        }
        if let iqama = vm.nextPrayerIqamaDate {
            parts.append(String(format: NSLocalizedString("iqama_at_time", comment: ""),
                                vm.dateFormatter.string(from: iqama)))
        }
        return parts
    }

    /// Spoken description: countdown plus the adhan/iqama times when known, read
    /// with commas instead of the decorative middle dot.
    private var accessibilityText: String {
        var text = String(format: NSLocalizedString("prayer_in_countdown", comment: ""),
                          vm.prayerDisplayName(vm.nextPrayerName), vm.countdown)
        let times = adhanAndIqamaParts.joined(separator: ", ")
        if !times.isEmpty { text += ", " + times }
        return text
    }
}

struct PermissionRequestView: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    @EnvironmentObject var navigationModel: NavigationModel
    @State private var isManualHovering = false
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "location.slash.circle.fill").font(.system(size: 28)).foregroundColor(.secondary)
            Text("Location Required").scaledFont(.headline)
            Text("To provide accurate prayer times, Sajda Pro needs to know your location.").scaledFont(.caption).multilineTextAlignment(.center).foregroundColor(Color("SecondaryTextColor")).padding(.horizontal)
            VStack(spacing: 8) {
                if vm.isRequestingLocation {
                    ProgressView().padding(.vertical, 4)
                    Text("Requesting Permission...").scaledFont(.caption).foregroundColor(.secondary)
                } else if vm.authorizationStatus == .denied {
                    Button("Open System Settings", action: vm.openLocationSettings).buttonStyle(.borderedProminent).controlSize(.regular)
                } else if vm.authorizationStatus == .authorized {
                    Button("Retry Location", action: vm.refetchAutomaticLocation).buttonStyle(.borderedProminent).controlSize(.regular)
                } else {
                    Button("Allow Location Access", action: vm.requestLocationPermission).buttonStyle(.borderedProminent).controlSize(.regular)
                }
                Button(action: {
                    navigationModel.showView(ContentView.id, animation: vm.forwardAnimation()) { ManualLocationView(isModal: true) }
                }) {
                    Text("Or, set location manually")
                        .padding(.vertical, 3).padding(.horizontal, 8)
                        .liquidHover(isManualHovering)
                }.buttonStyle(.plain).onHover { hovering in isManualHovering = hovering }
            }.padding(.top, 4).padding(.horizontal).animation(.easeInOut, value: vm.isRequestingLocation)
        }.frame(maxWidth: .infinity)
    }
}
