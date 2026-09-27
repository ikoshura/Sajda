// MARK: - GANTI SELURUH FILE: MainView.swift

import SwiftUI
import Adhan
import NavigationStack

struct MainView: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    @EnvironmentObject var navigationModel: NavigationModel
    @State private var isSettingsHovering = false
    @State private var isAboutHovering = false
    @State private var isMosqueRefreshHovering = false
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

    /// Glyph box the footer's refresh button draws into, so swapping the arrow
    /// for a spinner can't change the button's size and shift the icons beside
    /// it. Sized off `.body`, matching the About and Settings glyphs it sits
    /// between.
    private static let footerIconWidth: CGFloat = 16
    private static let footerIconHeight: CGFloat = 16

    /// Gap between the location row and the prayer list in the "Below Divider"
    /// position. Added to `PrayerListView`'s own 2pt top padding it matches the
    /// 6pt the outer VStack leaves above the row, so the row is centred in the
    /// space instead of clinging to the first prayer.
    private static let locationRowGap: CGFloat = 4

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
    ///
    /// No refresh button here: an overlaid control needs a `Color.clear`
    /// spacer to reserve its slot, and that spacer is greedy — it stretches
    /// the row to the leftover panel height. Re-fetching a stale mosque
    /// timetable is done from the Refresh button in Settings > Calculation &
    /// Location instead.
    private var locationFavoritesBlock: some View {
        Button(action: {
            navigationModel.showView(ContentView.id, animation: vm.forwardAnimation()) { FavoritesView() }
        }) {
            HStack(spacing: 4) {
                Text(vm.panelLocationCaption)
                    // `.callout` sits just under the "Sajda" title above, so the
                    // location reads as a caption for the times below rather
                    // than as another label competing with the title.
                    .scaledFont(.callout, weight: .regular)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                Image(systemName: vm.forwardChevron)
                    .scaledFont(.callout, weight: .semibold)
                    .foregroundColor(.secondary)
            }
            // The text carries its own size and weight above, so the row only
            // sets the colour: a font modifier on the HStack would resolve the
            // font itself and flatten the chevron's semibold back to regular.
            // `.secondary` is the same grey the Settings tab labels
            // ("Visual", "System", …) use. The text's regular weight is pinned
            // so the location never picks up the bold the prayer rows carry;
            // it still follows "Bold Text".
            .foregroundColor(.secondary)
            .padding(.vertical, 5).padding(.horizontal, 8)
            .contentShape(Rectangle())
            .liquidHover(isLocationHovering)
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
                // `.semibold`, bukan `.bold`. "Sajda" adalah kata yang paling
                // sering tampil di panel ini, dan bobot penuh terasa lebih
                // kasar dari yang perlu untuk sebuah judul. Perhatikan juga
                // bahwa mode aksesibilitas "Bold Text" menaikkan satu tingkat:
                // di situ `.semibold` menjadi `.bold` — masih terbaca sebagai
                // judul, sementara `.bold` akan menjadi `.heavy`.
                Text("Sajda").scaledFont(.body, weight: .semibold)
                Spacer()
                if vm.isPrayerDataAvailable && vm.menuBarTextMode == .hidden {
                    Text(vm.headerCountdownText).scaledFont(.body).lineLimit(1).minimumScaleFactor(0.7).foregroundColor(vm.isPrayerImminent ? .red : Color("SecondaryTextColor")).transition(.opacity.animation(.easeInOut))
                }
                // Hijri date (Umm al-Qura), flush to the panel's trailing
                // edge. It yields space first (low layout priority) so the
                // optional countdown still fits in the compact layout.
                Text(vm.hijriDateText)
                    // `.body` to match the "Sajda" title on the same row — the
                    // two are now read as one header line rather than a title
                    // with a small date tucked under it. `.secondary` matches
                    // the location line below and the Settings tab labels.
                    .scaledFont(.body)
                    .foregroundColor(.secondary)
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

            // Letak baris lokasi diatur lewat Settings > Prayer >
            // "Location Row". `.top` dirender DI SINI — di atas
            // garis pemisah, tepat di bawah judul. Dulu blok ini berada
            // setelah `Rectangle`, sehingga `.top` menghasilkan tata letak yang
            // sama persis dengan `.middle` (keduanya persis di bawah garis)
            // dan pilihannya tidak terlihat berbeda sama sekali.
            if vm.isPrayerDataAvailable && vm.locationRowPosition == .top {
                locationFavoritesBlock
            }

            Rectangle()
                .fill(Color("DividerColor"))
                .frame(height: 0.5)
                .padding(.horizontal, 12)

            // Countdown card (when on) keeps the top slot under the divider.
            let showCountdownCard = vm.isPrayerDataAvailable && vm.showCountdownHeader && vm.nextPrayerOccurrenceDate != nil
            if showCountdownCard {
                NextPrayerCountdownHeader()
            }

            if vm.isPrayerDataAvailable {
                // Posisi `.middle`: baris lokasi tepat di atas daftar shalat.
                // Dipakai stack bersarang (bukan sekadar `PrayerListView()`)
                // karena kedua elemen ini harus tetap menempel — baris itu
                // menjelaskan waktu-waktu di bawahnya.
                //
                // `locationRowGap` exist solely to balance this row. The gap
                // above it is the outer VStack's 6pt spacing; below it, this
                // stack's 4pt plus `PrayerListView`'s own 2pt top padding. 6
                // and 4 + 2 is what makes the two sides match — previously
                // they were 6 against 2, so the row looked glued to the first
                // prayer. Don't try to fix this with a negative padding on the
                // countdown card: its 12pt is *inside* the blue, so the space
                // below it is only the 6pt spacing, and pulling 10pt back just
                // overlapped the row with the card.
                if vm.locationRowPosition == .middle {
                    VStack(alignment: .leading, spacing: Self.locationRowGap) {
                        locationFavoritesBlock
                        PrayerListView()
                    }
                } else {
                    PrayerListView()
                }
            } else {
                Spacer()
                PermissionRequestView()
                Spacer()
            }

            // Posisi `.bottom`: baris lokasi menutup daftar shalat, jadi ia
            // mendapat pemisah sendiri — tanpa itu baris ini menempel pada
            // waktu shalat terakhir dan terbaca sebagai baris jadwal tambahan,
            // bukan sebagai keterangan tempat. Pemisah dan baris digabung dalam
            // satu stack agar keduanya tidak terpisah oleh jarak VStack luar.
            // Baris footer di bawahnya tetap memakai pemisahnya sendiri, jadi
            // di posisi ini memang ada dua garis: satu sebelum lokasi, satu
            // sebelum footer.
            if vm.isPrayerDataAvailable && vm.locationRowPosition == .bottom {
                VStack(alignment: .leading, spacing: 0) {
                    Rectangle()
                        .fill(Color("DividerColor"))
                        .frame(height: 0.5)
                        .padding(.horizontal, 12)
                        // Jarak di bawah garis dibuat lebih besar dari jarak di
                        // atasnya (2pt vs 6pt). Baris lokasi punya 5pt padding
                        // vertikal sendiri, sehingga sebelumnya jaraknya hanya 5pt
                        // di bawah garis — teksnya nempel — sementara di sisi lain
                        // ada 6pt spacing VStack luar + 2pt padding footer,
                        // jadi jaraknya 13pt. Hasilnya satu sisi terlihat absen
                        // dan sisi lain terlalu longgar.
                        .padding(.top, 2)
                        .padding(.bottom, 6)
                    locationFavoritesBlock
                        // Menarik kembali sebagian jarak di bawah baris. Padding
                        // 5pt bawaannya ditumpuk dengan 6pt spacing VStack luar
                        // dan 2pt padding footer, jadi tanpa ini baris ini
                        // bergeser 13pt dari footer — hampir dua kali jarak di
                        // atas garis pemisah. Padding negatif ini disengaja dan
                        // hanya berlaku untuk posisi `.bottom`.
                        .padding(.bottom, -5)
                }
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

                    // Re-fetch the active mosque's timetable, sitting just
                    // before About. Mawaqit edits a mosque's Jumu'ah and iqama
                    // entries during the year, so a schedule picked up months
                    // ago goes stale and this is the one-tap way to pull the
                    // new one (which also brings the mosque's own iqama gaps).
                    //
                    // It lives in the footer rather than on the location row
                    // on purpose: here it is just another sibling in this
                    // HStack, so it needs no reserved slot and no overlay. The
                    // location row's caption is the one thing that must stay
                    // exactly one line tall, and an overlaid control there
                    // stretched the whole row. Only shown in mosque mode,
                    // where it has something to refresh.
                    if vm.useMawaqitSchedule && vm.mawaqitMosque != nil {
                        Button {
                            Task { await vm.refreshActiveMosqueSchedule() }
                        } label: {
                            // A spinner in place of the glyph while the
                            // download runs, so a tap with no visible response
                            // (the times usually land identical) still reads
                            // as "it worked". The padding sits in the label
                            // and both branches are measured the same, so the
                            // pill doesn't jump or resize mid-refresh.
                            Group {
                                if vm.isRefreshingMosqueSchedule {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .scaledFont(.body)
                                }
                            }
                            .frame(width: Self.footerIconWidth, height: Self.footerIconHeight)
                            .padding(.vertical, 5).padding(.horizontal, 8)
                            // Padding, hit shape and pill all inside the label:
                            // applied to the Button instead, the hover fill is
                            // drawn past the label's frame but only the glyph
                            // itself is hit-testable, so you have to click the
                            // exact pixels of the icon.
                            .contentShape(Rectangle())
                            .liquidHover(isMosqueRefreshHovering)
                        }
                        .buttonStyle(.plain)
                        .disabled(vm.isRefreshingMosqueSchedule)
                        .onHover { hovering in isMosqueRefreshHovering = hovering }
                        .focusable(false)
                        .help(Text(NSLocalizedString("Refresh the mosque's schedule", comment: "")))
                        .accessibilityLabel(Text(NSLocalizedString("Refresh the mosque's schedule", comment: "")))
                    }

                    Button(action: {
                        navigationModel.showView(ContentView.id, animation: vm.forwardAnimation()) { AboutView() }
                    }) {
                        Image(systemName: "info.circle")
                            .scaledFont(.body)
                            .padding(.vertical, 5).padding(.horizontal, 8)
                            .contentShape(Rectangle())
                            .liquidHover(isAboutHovering)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in isAboutHovering = hovering }
                    // --- PERBAIKAN DI SINI --
                    .focusable(false)
                    .help(Text(NSLocalizedString("About", comment: "")))
                    .accessibilityLabel(Text(NSLocalizedString("About", comment: "")))
                    Button(action: {
                        // Unlocked always enters on Display; locked keeps the
                        // last-used tab. The reset is non-animated so it can't
                        // resize the panel as Settings is being pushed — see
                        // `resetSettingsTabToDisplay`.
                        vm.resetSettingsTabToDisplay()
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
    // Drives both the row height and the time-column width, so the time always
    // fits on one line and the rows always grow with the text.
    @Environment(\.panelFontScale) private var fontScale
    private var prayerOrder: [String] {
        let defaultOrder = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
        let sunnahOrder = ["Tahajud", "Fajr", "Dhuha", "Dhuhr", "Asr", "Maghrib", "Isha"]
        let baseOrder = vm.showSunnahPrayers ? sunnahOrder : defaultOrder
        return baseOrder.filter { vm.todayTimes.keys.contains($0) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(prayerOrder, id: \.self) { prayerName in
                PrayerRow(prayerName: prayerName, timeColumnWidth: Self.timeColumnWidth(fontScale: fontScale))
            }
            // Jumu'ah is not one of the five daily prayers — it replaces Dhuhr
            // only on a Friday, and a busy mosque can run up to three khutbah
            // sessions. It gets one discreet centred line under a rule after
            // Isha, so the daily list stays exactly five names long and the
            // Friday times are unmistakably a separate thing. Shown on Fridays,
            // or every day while "Always Show Jumu'ah" is on so travellers can
            // plan ahead.
            if !vm.jumuahSessionDates.isEmpty, vm.isFriday || vm.alwaysShowJumuah {
                JumuahFootnote()
            }
        }
        .padding(.top, 2)
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

    /// Row content height, measured from the text the row actually draws. The
    /// mute toggle used to be a fixed 25pt box, which made every row 33pt tall
    /// once the 4pt row padding was added — 2.5× a 13pt caption — so the
    /// highlight capsule, which fills the row, came out a thick slab and the
    /// rows read as too far apart. The toggle is now this tall instead: the
    /// body line height at the panel's current text scale, plus a little
    /// breathing room. Because the capsule still fills the row with no height
    /// of its own, it now follows the text down, and it keeps following it when
    /// the text is enlarged in Settings > Text Size.
    static func rowContentHeight(fontScale: CGFloat) -> CGFloat {
        let line = PanelTextSize.baseBodyPointSize * fontScale
        return max(16, (line * 1.5).rounded())
    }

    /// Fixed width for the time column: the widest string the panel's date
    /// formatter can emit ("88:88"), measured in the row font — so every
    /// row's time starts at the same x no matter its value, weight, or the
    /// prayer name's length.
    ///
    /// Measured with the *scaled* body font (and with the bold weight, the
    /// widest case, since the next-prayer row draws its time bold). Measuring
    /// with the unscaled system font is what let the time wrap onto two lines
    /// ("12:1 / 7") at Extra Large and XXL, which then blew the row height out
    /// and pushed the time into the panel edge.
    static func timeColumnWidth(fontScale: CGFloat, bold: Bool) -> CGFloat {
        let size = PanelTextSize.baseBodyPointSize * fontScale
        let font = NSFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
        return ("88:88" as NSString).size(withAttributes: [.font: font]).width + 4
    }

    /// Fixed width for the iqama gap column ("+8") that sits between the mute
    /// toggle and the time, drawn only when `displayedIqamaDelay(for:)` returns
    /// a number. Measured from the widest string the gap can be — "+88" — in the
    /// scaled caption font, and reserved on *every* row whether or not this
    /// prayer shows a gap, so the times don't shift as the highlight moves or
    /// when one prayer's gap differs from another's.
    static func iqamaColumnWidth(fontScale: CGFloat) -> CGFloat {
        // Same font the row draws the gap in: `scaledFont(.caption)` resolves to
        // the caption style's preferred font at the panel scale (see
        // `ScaledFontModifier`), so measuring anything else would clip it.
        // `.caption` maps to `NSFont.TextStyle.caption1` here, matching
        // `ScaledFontModifier.nsTextStyle`, which is the font the row draws the
        // gap in — measuring a different one would clip the widest case.
        let size = NSFont.preferredFont(forTextStyle: .caption1).pointSize * fontScale
        let font = NSFont.systemFont(ofSize: size)
        return ("+88" as NSString).size(withAttributes: [.font: font]).width + 4
    }

    /// Convenience for the common case: measure with the bold weight so every
    /// row reserves the same, widest slot and the column can never jitter as
    /// the highlight moves between prayers.
    static func timeColumnWidth(fontScale: CGFloat) -> CGFloat {
        timeColumnWidth(fontScale: fontScale, bold: true)
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
    // The toggle is sized from this, so the capsule follows the text when the
    // panel text size is changed in Settings.
    @Environment(\.panelFontScale) private var fontScale
    let prayerName: String
    let timeColumnWidth: CGFloat

    /// Row content height: the body line at the current text scale. The toggle
    /// is the tallest element by design, so this is what sets the highlight
    /// capsule's height too.
    private var contentHeight: CGFloat { PrayerListView.rowContentHeight(fontScale: fontScale) }

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
                    // At large text sizes a long prayer name (or the
                    // localised "Around" that follows it) can out-run the space
                    // the fixed time column leaves. Let it wrap onto a second
                    // line — the row is already text-led, so the highlight
                    // capsule grows with it — instead of truncating.
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .padding(.leading, PrayerListView.rowHorizontalInset)
                if prayerName == "Tahajud" || prayerName == "Dhuha" {
                    Text("Around").scaledFont(.caption).foregroundColor(isNextPrayer ? textColor.opacity(0.8) : Color("SecondaryTextColor"))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                toggleCell(isNextPrayer: isNextPrayer, textColor: textColor)
                // Between the mute toggle and the time, not after it: this is
                // the column layout the panel has always used, and keeping the
                // time hard against the trailing gutter is what lets it keep
                // its fixed right-aligned column. Putting "+8" last pushed the
                // time in from the edge and left the number floating on its
                // own at the far right.
                iqamaCell(isNextPrayer: isNextPrayer, textColor: textColor)
                Text(vm.dateFormatter.string(from: displayTime)).scaledFont(.body, weight: isNextPrayer ? .bold : nil)
                    // Right-anchored, one shared width: every time's leading
                    // edge starts at the same x. The width is measured in the
                    // scaled bold body font, so the time never wraps.
                    .lineLimit(1)
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
                // No height of its own: the capsule fills the row, so it is
                // exactly as tall as the tallest thing in it. That is the point
                // — the toggle is sized off the text (see `rowContentHeight`),
                // so the fill tracks the caption instead of a fixed box.
                // Gives the capsule a real gap on both sides, matching the
                // countdown card's own 5 pt inset.
                .padding(.horizontal, PrayerListView.highlightInset)
            }
        }
    }

    /// The iqama gap ("+8") in the slot between the mute toggle and the time.
    /// Renders nothing — and reserves no width — when there is no gap to show,
    /// so the times keep their old positions for Sunnah prayers and for any row
    /// the mosque publishes no gap for. The *width* is reserved even when the
    /// gap is hidden but the setting is on, because otherwise the times would
    /// jump sideways between prayers that do and don't have one.
    @ViewBuilder
    private func iqamaCell(isNextPrayer: Bool, textColor: Color) -> some View {
        if let minutes = vm.displayedIqamaDelay(for: prayerName) {
            Text(String(format: "+%d", minutes))
                .scaledFont(.caption)
                // Dimmer than the time, like the "Around" caption: it is a
                // qualifier on the time, not another time. On the highlighted
                // row it takes the row's own colour so it stays readable on
                // both light and dark highlights.
                .foregroundColor(isNextPrayer ? textColor.opacity(0.8) : Color("SecondaryTextColor"))
                .monospacedDigit()
                .lineLimit(1)
                .frame(width: PrayerListView.iqamaColumnWidth(fontScale: fontScale), alignment: .trailing)
                .help(String(format: NSLocalizedString("iqama_delay_minutes", comment: ""), minutes))
        } else if vm.showIqamaDelay {
            Color.clear.frame(width: PrayerListView.iqamaColumnWidth(fontScale: fontScale), height: 1)
        }
    }

    @ViewBuilder
    private func toggleCell(isNextPrayer: Bool, textColor: Color) -> some View {
        if vm.isAdhanPlaying && prayerName == vm.activeAdhanPrayerName {
            Button(action: { vm.stopAdhan() }) {
                Image(systemName: "speaker.slash.fill")
                    .scaledFont(.caption)
                    .foregroundColor(textColor)
                    // Same 25pt-wide, text-tall cell as the toggle below: the slot
                    // is always reserved at the same size, so the time column
                    // can't shift when adhan starts playing.
                    .frame(width: 13, height: 13)
                    .padding(6)
                    .frame(width: 25, height: contentHeight)
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
                    // The 6pt padding is the invisible slack around the 13pt
                    // ring; the frame then pins the cell to the row's text-led
                    // height, so the hit target and the capsule shrink together
                    // instead of the ring floating in a 25pt box.
                    .padding(6)
                    .frame(width: 25, height: contentHeight, alignment: .center)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help(muted ? "Unmute Adhan" : "Mute Adhan")
            .accessibilityLabel(muted ? Text("Unmute Adhan") : Text("Mute Adhan"))
        }
    }
}

/// The Friday khutbah times, as one discreet centred footnote under the daily
/// prayers. Placed after Isha by `PrayerListView` rather than inline under
/// Dhuhr — see the comment there for why.
///
/// Deliberately *not* laid out like a prayer row (own name column, own clock
/// column, own mute ring, heading of its own, rule above it). Jumu'ah is
/// complementary detail, not a sixth daily prayer, and lining it up with the
/// five made it read as one — while quietly implying Dhuhr still happens. One
/// quiet centred line with the sessions side by side ("Jumu'ah 13:30 | 14:30")
/// says "extra" at a glance, and a three-khutbah mosque still fits without
/// growing the panel.
private struct JumuahFootnote: View {
    @EnvironmentObject var vm: PrayerTimeViewModel

    var body: some View {
        // Centred, and with no shared columns, which is the whole point:
        // nothing about this line lines up with the prayer rows above it.
        // `prayerDisplayName` keeps the name in the active language like
        // every other prayer name.
        //
        // The weight goes through `scaledFont` rather than `.fontWeight`:
        // that modifier resolves the font itself and would overwrite a
        // `.fontWeight` set inside. `.body` at regular weight — the same size the
        // prayer rows and the location caption use, so the line is legible
        // without reading as a sixth prayer row (no columns, no mute ring, no
        // divider, centred), and `.secondary` (the system colour) rather than
        // the panel's own secondary text colour, so it sits under the prayer
        // rows instead of joining them. It still follows the panel's text-size
        // preset and the accessibility "Bold Text" setting the way every other
        // piece of panel text does.
        HStack(spacing: 4) {
            Text(vm.prayerDisplayName("Jumu'ah"))
                .scaledFont(.body, weight: .regular)
            Text(sessionTimes)
                .scaledFont(.body, weight: .regular)
                .monospacedDigit()
        }
        .foregroundColor(.secondary)
        .lineLimit(1)
        // Long localisations and three sessions can still outgrow a narrow
        // panel; shrink rather than truncate, so no time is ever lost.
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, PrayerListView.rowHorizontalInset)
        .padding(.top, 6)
    }

    /// Every session's clock on one line, separated by a bar: "13:30 | 14:30".
    /// `jumuahSessionDates` is already sorted, so no re-sorting is needed here.
    private var sessionTimes: String {
        vm.jumuahSessionDates
            .map { vm.dateFormatter.string(from: $0) }
            .joined(separator: " | ")
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
                    prominentButton("Open System Settings", action: vm.openLocationSettings)
                } else if vm.authorizationStatus == .authorized {
                    prominentButton("Retry Location", action: vm.refetchAutomaticLocation)
                } else {
                    prominentButton("Allow Location Access", action: vm.requestLocationPermission)
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

    /// The three actions above, drawn like the About page's Done button:
    /// `.borderedProminent` + `.tint` (the selected highlight colour, not
    /// the system accent) + `.clipShape(Capsule())`. Without the clip the
    /// prominent style renders its squarer macOS bezel in this non-activating
    /// menu-bar panel, and without the tint it ignored the user's colour
    /// pick — both of which the About page has had right all along.
    private func prominentButton(_ titleKey: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(NSLocalizedString(titleKey, comment: ""))
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.regular)
        .clipShape(Capsule())
        .tint(vm.selectedHighlightColor)
    }
}
