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
    /// Update availability, observed directly: the footer badge below reflects
    /// it live, and AboutView binds the same shared checker.
    @ObservedObject private var updater = UpdateChecker.shared
    @State private var isUpdateHovering = false

    /// Amber, not the accent colour: the badge is a message, not a selection.
    /// The accent is already load-bearing elsewhere in the panel (the next-prayer
    /// highlight), so reusing it made the badge read as "this is the current
    /// state" rather than "there is something to read". Warm amber keeps it
    /// legible on both appearances and is the conventional attention colour, so
    /// it survives greyscale and the common colour-vision deficiencies where a
    /// red/green pair would not.
    private static let updateBadgeTint = Color(red: 0.98, green: 0.68, blue: 0.13)

    /// Version the footer badge advertises, or nil when no update is pending
    /// (badge hidden).
    private var updateBadgeVersion: String? {
        if case .updateAvailable(let version, _) = updater.state { return version }
        return nil
    }
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
            // Location block moves around it: it heads the prayer list when the
            // card is off, and sits under the list (behind its own separator)
            // when the card is on.
            let showCountdownCard = vm.isPrayerDataAvailable && vm.showCountdownHeader && vm.nextPrayerOccurrenceDate != nil
            if showCountdownCard {
                NextPrayerCountdownHeader()
            }

            // Keep the prayer list snug under whatever sits above it — compact
            // rhythm through PrayerListView's rows. With the card off there is a
            // *row* above it rather than a card, so the two stack with no gap of
            // their own: the list's 4 pt top inset is then the whole space
            // between the location row and the first prayer row — a slight
            // breath, rather than the extra 6 pt a stack gap on top of it made.
            if vm.isPrayerDataAvailable {
                if showCountdownCard {
                    PrayerListView()
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        locationFavoritesBlock
                        PrayerListView()
                    }
                }
            } else {
                Spacer()
                PermissionRequestView()
                Spacer()
            }

            if vm.isPrayerDataAvailable && showCountdownCard {
                // Separator between the prayer list and the location row
                // (countdown-active layout only — otherwise the row heads the
                // list, directly under the top divider).
                Rectangle()
                    .fill(Color("DividerColor"))
                    .frame(height: 0.5)
                    .padding(.horizontal, 12)
                locationFavoritesBlock
            }

            // One separator after the prayer times, then a single compact
            // line: Quit on the leading edge, then the update badge, About and
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

                    // Update badge, leading the trailing icon group so it sits
                    // immediately beside About. Only rendered while a newer
                    // release is known; tapping it opens the release page.
                    if let version = updateBadgeVersion {
                        Button(action: { updater.openReleasePage() }) {
                            Image(systemName: "arrow.down.circle.fill")
                                .scaledFont(.body)
                                .foregroundColor(Self.updateBadgeTint)
                                .padding(.vertical, 5).padding(.horizontal, 8)
                                .liquidHover(isUpdateHovering)
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in isUpdateHovering = hovering }
                        .focusable(false)
                        .help(Text(String(format: NSLocalizedString("Update available: %@", comment: ""), version)))
                        .accessibilityLabel(Text(String(format: NSLocalizedString("Update available: %@", comment: ""), version)))
                    }

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
        VStack(alignment: .leading, spacing: 0) {
            ForEach(prayerOrder, id: \.self) { prayerName in
                PrayerRow(prayerName: prayerName, timeColumnWidth: Self.timeColumnWidth)
                // Friday sessions get their own rows right under Dhuhr (Dhuhr
                // itself stays put): one row per gathering, each with its own
                // clock and its own mute ring. Shown on Fridays, or every day
                // while "Always Show Jumu'ah" is on so travellers can plan ahead.
                if prayerName == "Dhuhr", (vm.isFriday || vm.alwaysShowJumuah) {
                    ForEach(Array(vm.jumuahSessionDates.enumerated()), id: \.offset) { index, date in
                        JumuahSessionRow(index: index,
                                         date: date,
                                         total: displayedJumuahSessionCount,
                                         timeColumnWidth: Self.timeColumnWidth)
                    }
                }
            }
        }
        .padding(.top, 2)
    }

    /// How many Jumu'ah rows the list is about to draw — 0 when the row stays
    /// hidden. Only drives the numbering ("Jumu'ah" vs "Jumu'ah 1").
    private var displayedJumuahSessionCount: Int {
        guard vm.isFriday || vm.alwaysShowJumuah else { return 0 }
        return vm.jumuahSessionDates.count
    }

    /// Horizontal inset for every schedule row (prayers and Jumu'ah alike).
    /// The panel's standard text gutter: the title, the dividers and the
    /// location row all sit at 12 pt, so the prayer names have to match it or
    /// they read as indented. Not the countdown card's 5 pt — the card is a
    /// self-contained block, the rows are panel content.
    static let rowHorizontalInset: CGFloat = 12

    /// Gap between the highlight capsule and the panel edge. Applied *inside*
    /// the background closure, not as row padding: a full-width row padded on
    /// the outside grows past the panel instead of insetting, which is what
    /// made the highlight bleed edge to edge. Matches the countdown card.
    static let highlightInset: CGFloat = 5

    /// Fixed width for the time column: the widest string the panel's date
    /// formatter can emit ("88:88"), measured in the row font — so every
    /// row's time starts at the same x no matter its value, weight, or the
    /// prayer name's length.
    static var timeColumnWidth: CGFloat {
        ("88:88" as NSString).size(
            withAttributes: [.font: NSFont.systemFont(ofSize: NSFont.systemFontSize)]).width + 4
    }
}

/// One prayer row: name … mute ring | time. The ring sits immediately left of
/// the time so both trailing elements are right-anchored and the name keeps the
/// leading edge — the name needs no fixed width, the `Spacer` takes the slack.
/// The highlight is one capsule behind the whole row, inset from the panel
/// edges (see `highlightInset` for why the inset lives in the background).
private struct PrayerRow: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    @Environment(\.colorScheme) private var colorScheme
    let prayerName: String
    let timeColumnWidth: CGFloat

    var body: some View {
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
            HStack(spacing: 6) {
                Text(vm.prayerDisplayName(prayerName))
                    .padding(.leading, PrayerListView.rowHorizontalInset)
                if prayerName == "Tahajud" || prayerName == "Dhuha" {
                    Text("Around").scaledFont(.caption).foregroundColor(isNextPrayer ? textColor.opacity(0.8) : Color("SecondaryTextColor"))
                }
                Spacer(minLength: 4)
                toggleCell(isNextPrayer: isNextPrayer, textColor: textColor)
                Text(vm.dateFormatter.string(from: displayTime)).scaledFont(.body, weight: isNextPrayer ? .bold : nil)
                    // Right-anchored, one shared width: every time's leading
                    // edge starts at the same x.
                    .frame(width: timeColumnWidth, alignment: .trailing)
                    .padding(.trailing, PrayerListView.rowHorizontalInset)
            }
            // The row is full-width (it holds a Spacer), so its own padding
            // would push the row *outward* past the panel edges rather than
            // inset it — the text insets but the highlight bleeds. Hence the
            // insets live on the content above, and the capsule below is
            // inset inside the background closure.
            .foregroundColor(textColor).fontWeight((isNextPrayer || vm.accessibilityBoldText) ? .bold : .regular).padding(.vertical, 4).background {
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
                // Gives the capsule a real gap on both sides, matching the
                // countdown card's own 5 pt inset.
                .padding(.horizontal, PrayerListView.highlightInset)
            }
        }
    }

    @ViewBuilder
    private func toggleCell(isNextPrayer: Bool, textColor: Color) -> some View {
        if vm.isAdhanPlaying && prayerName == vm.activeAdhanPrayerName {
            Button(action: { vm.stopAdhan() }) {
                Image(systemName: "speaker.slash.fill")
                    .scaledFont(.caption)
                    .foregroundColor(textColor)
                    // Same 25pt hit box as the toggle below: the slot is
                    // always reserved, so the time column can't shift when
                    // adhan starts playing.
                    .frame(width: 13, height: 13)
                    .padding(6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Stop Adhan")
        } else {
            // Per-prayer adhan on/off, right on the panel: muting flips
            // `PrayerSoundConfig.muted` (never the sound picked in Settings).
            let muted = vm.isAdhanMuted(prayerName)
            Button(action: { vm.setAdhanMuted(!muted, for: prayerName) }) {
                // Highlighted row: white ring + white dot for contrast (white
                // even with accent mode off, where the row text itself is
                // `.primary`). Other rows: the selected highlight colour
                // (custom pick, or the system accent).
                AdhanMuteIcon(muted: muted, activeColor: isNextPrayer ? (vm.useAccentColor ? textColor : .white) : vm.selectedHighlightColor, size: 13)
                    // The whole 25pt box is the hit target: generous invisible
                    // padding + rectangular content shape so there is no
                    // exact-pixel hunting.
                    .padding(6)
                    .frame(width: 25, height: 25, alignment: .center)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help(muted ? "Unmute Adhan" : "Mute Adhan")
            .accessibilityLabel(muted ? Text("Unmute Adhan") : Text("Mute Adhan"))
        }
    }
}

/// One Jumu'ah session row: label | mute ring | time. Each session is its own
/// row with its own toggle, so several gatherings never collapse into one
/// unreadable line. A single session keeps the bare "Jumu'ah" label; two or
/// more are numbered ("Jumu'ah 1", "Jumu'ah 2", …) so the ring a user taps is
/// unambiguous.
private struct JumuahSessionRow: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    let index: Int
    let date: Date
    let total: Int
    let timeColumnWidth: CGFloat

    var body: some View {
        HStack(spacing: 6) {
            Text(vm.jumuahSessionLabel(index, total: total))
                .padding(.leading, PrayerListView.rowHorizontalInset)
            Spacer(minLength: 4)
            // Same 25pt slot, on the same side, as the prayer rows.
            muteCell
            Text(vm.dateFormatter.string(from: date))
                .scaledFont(.body)
                .frame(width: timeColumnWidth, alignment: .trailing)
                .padding(.trailing, PrayerListView.rowHorizontalInset)
        }
        .foregroundColor(.primary)
        .fontWeight(vm.accessibilityBoldText ? .bold : .regular)
        .padding(.vertical, 4)
    }

    private var muteCell: some View {
        let key = vm.jumuahSessionSoundKey(index)
        let muted = vm.isAdhanMuted(key)
        return Button(action: { vm.setAdhanMuted(!muted, for: key) }) {
            AdhanMuteIcon(muted: muted, activeColor: vm.selectedHighlightColor, size: 13)
                .padding(6)
                .frame(width: 25, height: 25, alignment: .center)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(muted ? "Unmute Adhan" : "Mute Adhan")
        .accessibilityLabel(muted ? Text("Unmute Adhan") : Text("Mute Adhan"))
    }
}
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
            // so theirs reads "Around 05:10". The iqama is always that prayer's
            // estimate after the adhan — one source for auto/manual location
            // and mosque timetables alike (see `nextPrayerIqamaDate`).
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
        // The card keeps its own 5 pt inset: it is a self-contained block, not
        // panel text, so it deliberately does not share the schedule rows' 12 pt
        // gutter. The rows line up with the title and the location row instead.
        .padding(.horizontal, 5)
        .padding(.top, 2)
        .accessibilityLabel(Text(accessibilityText))
    }

    /// Adhan and iqama on one line, separated by the middle dot used across the
    /// panel. Parts that don't exist yet are dropped — a sunnah prayer has no
    /// congregation, so its line stops at the "Around 05:10" adhan estimate.
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
