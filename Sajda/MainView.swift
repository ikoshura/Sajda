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
    /// Location accordion, expanded or shut.
    ///
    /// This state survives everything unless something collapses it, and that
    /// is now *measured*, not assumed: with `MenuBarExtra(.window)` the panel's
    /// content view is not rebuilt when the window closes — the list was still
    /// expanded on the next open — and the two SwiftUI-side signals did not
    /// reach this view on a dismissal either (`.popoverDidClose`, posted from
    /// `SajdaControlCenterMenu`'s `isMenuPresented`, which its own `onAppear`
    /// comment admits cannot be relied upon for a close; and `scenePhase`,
    /// which only moves in the vendored `RootViewModifier` that this app does
    /// not install — it uses the native `MenuBarExtra`). So the resets hang
    /// off AppKit's window notifications at the bottom of `body`. The third
    /// case needs no handler at all:
    ///
    /// *Switching to another page* — structural: `ContentView` puts `MainView`
    ///    behind `NavigationStackView`, which drops the default view from the
    ///    hierarchy while a page is showing (`ContentViews`'
    ///    `if !model.isAlternativeViewShowing(identifier)`), destroying this
    ///    `@State`. Coming back rebuilds it shut.
    ///
    /// Claude's suggested `NSWindow.didResignKeyNotification` is the right
    /// primary signal: AppKit posts it whether the menu window *closes* or
    /// merely *loses key* to another app, so one handler covers both of the
    /// two remaining cases. Unfiltered — those notifications fire for every
    /// window, the usual caveat — deliberately: every other window this app
    /// owns (onboarding, prayer alerts, the colour panel, any open/save sheet)
    /// exists only alongside a *page*, where `MainView` is out of the
    /// hierarchy and these handlers are not subscribed. The prayer alert is
    /// the one exception, and folding the list when an alert window takes
    /// focus is the requested behaviour anyway.
    @State private var isLocationExpanded = false
    /// Bumped on every location-collapse so `FavoritesSection` can reset its
    /// inline searches. It is never mounted-unmounted any more (the accordion
    /// animates height instead, see `AccordionReveal`), so that reset has to be
    /// requested from here rather than falling out of a lifecycle change.
    @State private var locationCollapseToken = 0

    /// Collapses the location accordion in the same frame the push starts, for
    /// the Settings and About buttons.
    ///
    /// Plain assignment, no `withAnimation` — this is the approach that reads as
    /// smooth, and the reason is subtle. `NavigationStackModel
    /// .showAlternativeViewForNode` flips `isAlternativeViewShowing`
    /// synchronously inside `showView`, and the package's `ContentViews` keeps
    /// both views alive in one `ZStack` for the length of the transition, so
    /// this view is still on screen while the push plays out. An *animated*
    /// collapse therefore animated the panel's height through the transition —
    /// the list visibly shrank while the outgoing view was still moving, and
    /// the push crossfade/slide rode on top of it. Two overlapping height
    /// motions read as a flicker.
    ///
    /// Assigning outright collapses the list within the same runloop turn the
    /// push is requested in, so the height change and the transition are laid
    /// out once together instead of competing over the frame. An unanimated
    /// collapse is what the very first implementation did, and it is what
    /// still looks right.
    ///
    /// Nothing is owed on the way back: while a page is showing, `ContentViews`
    /// drops `defaultView()` from the hierarchy entirely, destroying this
    /// `@State`, so returning rebuilds `MainView` shut either way. See
    /// `isLocationExpanded`.
    private func collapseLocationForNavigation() {
        collapseLocation()
    }

    /// The single way the location accordion closes, whatever the reason.
    ///
    /// Bumping the token is what makes the *content* reset as well. The
    /// accordion no longer unmounts its content (see `AccordionReveal`), so
    /// `openSearch` inside `FavoritesSection` would otherwise survive the
    /// collapse and the next open would restore the last search. Routing every
    /// close — the row button, the window notifications, navigation — through
    /// here is what keeps that guarantee: a second close path added later
    /// cannot forget to request the reset.
    private func collapseLocation() {
        isLocationExpanded = false
        locationCollapseToken &+= 1
    }

    /// Collapses the accordion and says why, in the unified log.
    ///
    /// The two SwiftUI-side signals that used to handle this did not fire on a
    /// dismissal (measured: the list stayed expanded through a close and a
    /// focus loss), and SwiftUI's menu-window class is an internal detail that
    /// the usual filter advice depends on. So every reset reports itself: if
    /// this ever fails again, one line says whether the notification arrived
    /// at all, and what window it was posted for. Debug builds only.
    ///
    ///     log stream --predicate 'eventMessage CONTAINS "SAJDA-ACCORDION"'
    private func resetLocationAccordion(_ reason: String, _ note: Notification? = nil) {
        #if DEBUG
        let detail = (note?.object as? NSWindow)
            .map { "\(NSStringFromClass(type(of: $0))) visible=\($0.isVisible)" }
            ?? "no window"
        #endif

        // Two situations must NOT fold the list here. Both produce the same
        // symptom — a flicker when navigating to another page while the list
        // is open — because both resize the panel *while* the push transition
        // runs, and the panel's own resize curve deliberately does not key on
        // navigation (see `panelLayoutSignature`: "two animations on the same
        // transition would fight over the curve").
        //
        // 1. A page push is in flight. This view is leaving the hierarchy
        //    anyway and the stack resets it structurally on the way back (see
        //    `isLocationExpanded`), so folding it here only adds a layout
        //    motion to the transition.
        // 2. An event about a window that is *not* the one holding key — a
        //    tooltip closing or a field editor going away while the menu
        //    window keeps focus. That is noise, not focus loss. This is the
        //    class-name filter the usual advice asks for, keyed on who holds
        //    key instead of on a private class name macOS is free to rename.
        guard !navigationModel.hasAlternativeViewShowing else {
            #if DEBUG
            NSLog("SAJDA-ACCORDION ignored (%@): page push in flight, %@", reason, detail)
            #endif
            return
        }
        if let window = note?.object as? NSWindow, let key = NSApp.keyWindow, key !== window {
            #if DEBUG
            NSLog("SAJDA-ACCORDION ignored (%@): %@, while %@ still holds key", reason, detail,
                  NSStringFromClass(type(of: key)))
            #endif
            return
        }

        #if DEBUG
        NSLog("SAJDA-ACCORDION collapse (%@): %@", reason, detail)
        #endif
        collapseLocation()
    }
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
    /// Location row, and the inline accordion under it.
    ///
    /// Tapping the row expands the whole location list where the row sits —
    /// `FavoritesSection`, the same content the Location page used to show:
    /// the Automatic row, the saved cities and mosques, and both search rows
    /// opening in place underneath. Nothing pushes a page any more, which also
    /// takes away the pop-then-push flicker the searches used to have.
    ///
    /// Outer 4pt + inner 8pt = 12pt, the same gutter PrayerListView's rows use
    /// — and the same 4pt the Location page applied to `FavoritesSection`, so
    /// every row inside the accordion lands on the same x it did there.
    ///
    /// No refresh button here: an overlaid control needs a `Color.clear`
    /// spacer to reserve its slot, and that spacer is greedy — it stretches
    /// the row to the leftover panel height. Re-fetching a stale mosque
    /// timetable is done from the Refresh button in Settings > Calculation &
    /// Location instead.
    private var locationFavoritesBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                if isLocationExpanded {
                    // Same curve as the Settings and search accordions: the
                    // panel and the menu window behind it track the animating
                    // content size and resize in lockstep. The close goes
                    // through `collapseLocation` so the content resets with it.
                    withAnimation(.sajdaAccordion) {
                        collapseLocation()
                    }
                } else {
                    withAnimation(.sajdaAccordion) {
                        isLocationExpanded = true
                    }
                }
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
                    // Expanded points up, the convention every accordion in the
                    // panel follows; collapsed mirrors for RTL via the
                    // chevron the view model hands out.
                    Image(systemName: isLocationExpanded ? "chevron.up" : vm.forwardChevron)
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
            .onHover { hovering in isLocationHovering = hovering }
            .help(Text(NSLocalizedString("Location", comment: "")))
            .accessibilityLabel(Text(NSLocalizedString("Location", comment: "")))
            .accessibilityHint(Text(NSLocalizedString("Opens the location list", comment: "")))
            .accessibilityAddTraits(.isButton)

            // Always mounted, opened and closed by animating the height — the
            // shared accordion mechanism, documented in `AccordionReveal`. This
            // block was where that mechanism was worked out: an `if` plus a
            // transition strands a ghost copy of the rows over the prayer list
            // while the panel resizes, whichever transition is used.
            //
            // The content's own padding and spacing are unchanged, so every row
            // still lands on the x it did on the old Location page.
            AccordionReveal(isExpanded: isLocationExpanded) {
                FavoritesSection(collapseToken: locationCollapseToken)
            }
        }
        // One 4pt for the row and one for the section: 4 + their own 8 = the
        // panel's 12pt gutter, exactly the geometry the Location page had.
        // It lives on this VStack rather than on the Button so the expanded
        // content inherits it too.
        .padding(.horizontal, 4)
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
                        //
                        // Hanya selama akordeonnya tertutup: tarikan itu untuk
                        // merapatkan *baris* ke footer, dan begitu daftarnya
                        // terbuka yang berada di atas footer adalah daftarnya,
                        // bukan barisnya — tetap dipakai, konten yang terbuka
                        // ditarik 5pt menembus footer.
                        .padding(.bottom, isLocationExpanded ? 0 : -5)
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
                        collapseLocationForNavigation()
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
                        collapseLocationForNavigation()
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
        // The resets that fire (see `isLocationExpanded` for why the
        // SwiftUI-side signals do not): AppKit's own window notifications,
        // which are posted whether the menu window closes or merely loses key.
        // Unfiltered on purpose — they fire for every window — because every
        // other window this app owns appears only alongside a page, where
        // `MainView` is out of the hierarchy and these handlers are gone.
        //
        // Plain assignment rather than an animated collapse: the panel is
        // closing or unfocusing, so animating would resize a window that is
        // going away or nobody is watching (the same reasoning behind
        // `resetSettingsTabToDisplay`, and behind `ContentView` calling
        // `hideView(…, animation: nil)`).
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { note in
            // Both ways the panel can lose focus post this alike: closing the
            // key menu window, and handing key to another app while it stays
            // open.
            resetLocationAccordion("didResignKey", note)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { note in
            // Belt for dismissal specifically: if a close ever arrives without
            // the window having been key (ordering differs across releases),
            // this still folds the list. Every window counts except tooltips —
            // `.help()` shows those in their own window, and folding the list
            // because the user moved the mouse off a button would be a bug of
            // its own. (Tooltips almost certainly order out rather than close,
            // so this is defence in depth; the class check is a no-op if they
            // ever rename.)
            guard let window = note.object as? NSWindow,
                  !NSStringFromClass(type(of: window)).localizedCaseInsensitiveContains("tooltip") else { return }
            resetLocationAccordion("willClose", note)
        }
        .onReceive(NotificationCenter.default.publisher(for: .popoverDidClose)) { note in
            // Third belt: the app-level close notification, in case
            // `isMenuPresented` starts flipping on dismissal. In the build this
            // was written against it did not reach here, which is why it is no
            // longer the primary signal.
            resetLocationAccordion("popoverDidClose", note)
        }

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

    /// Slack baked into the measured time column (and the iqama column).
    ///
    /// The measurement pads the reserved box a little wider than "88:88" really
    /// needs, so a wide glyph or a bolder weight can never push the digits out
    /// of their column. That slack opens on the *inner* side of the digits, not
    /// the outer one: both frames are `.trailing`-aligned, so the content hugs
    /// the frame's trailing edge and the spare width shows up on the leading
    /// side — between the digits and whatever sits to their left (the iqama gap,
    /// the mute ring, the row's flexible `Spacer`).
    ///
    /// So it never reaches the row's outer gutter. Subtracting it from the
    /// trailing inset — which 4.4.11 did, reading the slack as if it landed
    /// outside the digits — pulls the clock 4 pt closer to the panel edge than
    /// the prayer name on the opposite end. See `rowTrailingInset`.
    static let columnSlack: CGFloat = 4

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
        return ("88:88" as NSString).size(withAttributes: [.font: font]).width + columnSlack
    }

    /// Trailing gutter for a schedule row: the same 12 pt the prayer name gets
    /// on the leading end, so both ends of a row sit on the panel's gutter.
    ///
    /// Two traps live here, and 4.4.11 fell into both.
    ///
    /// Measured, not shifted: this is deliberately *not*
    /// `rowHorizontalInset - columnSlack`. The column slack sits inside a
    /// `.trailing`-aligned frame, so it never reaches the outer edge — the digits
    /// are already flush with the frame's trailing edge, and their ink lands
    /// 0.4–0.7 pt inside it, the same sub-point bearing a prayer name carries at
    /// the other end.
    ///
    /// Applied as padding on the row's content, *not* as another row child. A
    /// trailing `Spacer().frame(width:)` sits in the stack like any other view,
    /// so it also collects the stack's 6 pt spacing, and the clock's gutter came
    /// out as `width + 6 + bearing`. That is why a nominal 12 pt read as 18.7 pt
    /// before 4.4.11, and why a nominal 8 pt still read as 14.7 pt after it: the
    /// row was never as off as the constant made it look, and the fix for the
    /// first number was applied to a spacer that was not the whole story.
    ///
    /// Padding shrinks the content inside the row instead, so the number here is
    /// the number of points the ink sits from the panel edge, and this constant
    /// is once again the panel's own gutter.
    static var rowTrailingInset: CGFloat { rowHorizontalInset }

    /// Width the sunnah "plusminus" estimate mark adds to the time column.
    ///
    /// Reserved on *every* row, not just the sunnah ones. That sounds wasteful,
    /// but it's what keeps the digits aligned: the column is right-aligned, so
    /// a wider column on sunnah rows alone would push those two times further
    /// left than the five beside them. Reserving it everywhere instead means
    /// every clock in the panel ends on the same x, and the mark sits hard
    /// against its own digits.
    static func sunnahMarkWidth(fontScale: CGFloat) -> CGFloat {
        // The mark is an SF Symbol, so its width comes from the symbol image
        // rather than from a font — a `Text` measurement would be measuring the
        // wrong thing entirely.
        //
        // Measured at its *own* drawing size (`sunnahMarkSize`), not at its
        // natural size, because the panel scales the mark and the row reserves
        // what is actually drawn. Reserving the natural size here would leave a
        // growing gap beside the mark at larger panel text sizes.
        let drawnSize = sunnahMarkSize(fontScale: fontScale)
        let symbol = NSImage(systemSymbolName: "plusminus", accessibilityDescription: nil)
        // SF Symbols keep a square aspect, so the drawn point size is the width.
        // The fallback is only reachable on a system that lacks the symbol.
        let width = symbol.map { $0.size.width * (drawnSize / max($0.size.height, 1)) }
            ?? drawnSize
        // A little slack: SF Symbols carry side bearings that the measured box
        // doesn't account for, and the mark must never push into the digits.
        return width + 4
    }

    /// Point size the sunnah mark is drawn at, matching the row's `.callout`
    /// text.
    ///
    /// `.callout` rather than the row's `.body`: the mark is a qualifier hung off
    /// the clock, not part of the value, and at body size a glyph's full height
    /// competed with the digits instead of sitting under them. It still tracks
    /// the panel's text size — a symbol can't take a font from `scaledFont`, so
    /// the scale is applied here from the same `callout` base that modifier
    /// resolves to. Keep the two in step: if this drifts from the size the row
    /// uses, the mark stops reading as part of the number it qualifies.
    static func sunnahMarkSize(fontScale: CGFloat) -> CGFloat {
        NSFont.preferredFont(forTextStyle: .callout).pointSize * fontScale
    }

    /// Fixed width for the iqama gap column ("+8") that sits between the mute
    /// toggle and the time, drawn only when `displayedIqamaDelay(for:)` returns
    /// a number. Measured from the widest string the gap can be — "+88" — in the
    /// scaled callout font, and reserved on *every* row while a mosque timetable
    /// is active, whether or not this prayer shows a gap, so the times don't
    /// shift as the highlight moves or when one prayer's gap differs from
    /// another's. Under calculated times no row shows a gap at all, so nothing
    /// reserves it (see `hasIqamaColumn`).
    static func iqamaColumnWidth(fontScale: CGFloat) -> CGFloat {
        // Must stay in step with the font `iqamaCell` draws the gap in:
        // `scaledFont(.callout)` resolves to the callout style's preferred font
        // at the panel scale, and `ScaledFontModifier.nsTextStyle` maps
        // `.callout` to `NSFont.TextStyle.callout`. Measuring a different style
        // would either clip the widest case or reserve a column the text no
        // longer fills.
        let size = NSFont.preferredFont(forTextStyle: .callout).pointSize * fontScale
        let font = NSFont.systemFont(ofSize: size)
        return ("+88" as NSString).size(withAttributes: [.font: font]).width + columnSlack
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
    @Environment(\.locale) private var locale

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
                Spacer(minLength: 4)
                toggleCell(isNextPrayer: isNextPrayer, textColor: textColor)
                // The gap goes on whichever side the user picked (Settings >
                // Prayer Times > Iqama Delay). Left puts it between the toggle and
                // the time, so the time stays flush against the edge; right puts
                // it after the time, reading as one time qualified ("13:53 +8").
                // The trailing inset is its own trailing element rather than
                // padding on the last view, so it lands in the same place either
                // way and the row keeps a single right margin.
                if vm.iqamaDelayPosition == .leading {
                    iqamaCell(isNextPrayer: isNextPrayer, textColor: textColor)
                }
                // Time, with the estimate mark for sunnah prayers hard against
                // the digits. Sunnah times are estimates, and "±" says that in
                // one glyph where "Around" needed a word to say the same thing.
                // It lives inside this group rather than out by the prayer name
                // so the pair reads as one qualified value — "±01:46" — instead
                // of a mark stranded mid-row, and so it can never be separated
                // from its time by the row's flexible `Spacer`.
                //
                // `.body`, same style as the time itself: the mark is a
                // qualifier on that clock, not a caption beneath it, and at
                // caption size it read as a speck beside a full-size number.
                // Same scaled style rather than a fixed point size, so it keeps
                // tracking the panel's text size — at XXL a hardcoded 12pt
                // would be the one thing on the row that didn't grow.
                //
                // The frame is on the *group*, not the digits. Putting it on the
                // `Text` instead is what left the mark stranded: a right-aligned
                // frame measured for "88:88" aligns the digits to their own
                // right edge, which pinned every clock to the same x and left
                // the mark adrift in the space the wider sunnah text had opened
                // up between it and the digits. Framing the group right-aligns
                // the mark *and* the digits together, so they stay joined — and
                // since the mark's width is reserved on every row
                // (`sunnahMarkWidth`), all seven clocks still end on one line.
                HStack(spacing: 1) {
                    if prayerName == "Tahajud" || prayerName == "Dhuha" {
                        // The SF Symbol rather than a "±" character: it matches
                        // the rest of the panel's iconography, and it renders
                        // identically in every language and at every weight.
                        // Sized from the panel's scale by hand, because
                        // `scaledFont` sets a font and a symbol is not text.
                        //
                        // `.secondary` on every ordinary row: the mark is a
                        // qualifier, not a value, so it recedes exactly like
                        // the iqama gap and the mute ring beside it. The
                        // highlighted row is the exception — `.secondary` on an
                        // accent fill is unreadable, so there it takes the row's
                        // own text colour.
                        Image(systemName: "plusminus")
                            .font(.system(size: PrayerListView.sunnahMarkSize(fontScale: fontScale)))
                            .foregroundStyle(isNextPrayer ? textColor.opacity(0.8) : Color.secondary)
                    }
                    Text(vm.dateFormatter.string(from: displayTime)).scaledFont(.body, weight: isNextPrayer ? .bold : nil)
                        // Right-anchored, one shared width: every time's leading
                        // edge starts at the same x. The width is measured in the
                        // scaled bold body font, so the time never wraps.
                        .lineLimit(1)
                        // Fixed so a wide "±" can't reflow the row at a large
                        // panel text size; the group's frame does the aligning.
                        .fixedSize(horizontal: true, vertical: false)
                }
                .frame(width: timeColumnWidth + PrayerListView.sunnahMarkWidth(fontScale: fontScale), alignment: .trailing)
                if vm.iqamaDelayPosition == .trailing {
                    iqamaCell(isNextPrayer: isNextPrayer, textColor: textColor)
                }
            }
            // The trailing gutter is padding on the content — the same 12 pt the
            // prayer name carries at the other end. See `rowTrailingInset` for
            // why it is neither a trailing `Spacer` (the stack's 6 pt spacing
            // would ride along with it, which is how a nominal 12 pt measured
            // 18.7) nor `12 - columnSlack`.
            //
            // Padding still leaves the row full-width, so the highlight keeps
            // hugging the panel edges exactly as before: the row is given the
            // panel's width, the content inside it insets, and the capsule then
            // insets itself 5 pt inside the background closure.
            .padding(.trailing, PrayerListView.rowTrailingInset)
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
    /// the mosque publishes no gap for.
    ///
    /// The *width* is reserved for those, so the time column doesn't shift
    /// sideways between a prayer that has a gap and one that doesn't. But only
    /// while a mosque timetable is active — that reservation is there to keep a
    /// visible column stable, and under calculated times the column is empty on
    /// every row, so reserving it just parks the times a column too far from the
    /// right edge. The `hasIqamaColumn` gate is what keeps a "Right" setting
    /// left over from mosque mode from leaving a gap where nothing goes.
    @ViewBuilder
    private func iqamaCell(isNextPrayer: Bool, textColor: Color) -> some View {
        if let minutes = vm.displayedIqamaDelay(for: prayerName) {
            // Locale's own digits ("+8" / "+٨"): `String(format:)` without a
            // locale always prints ASCII.
            Text(verbatim: "+" + LocalizedNumber.string(minutes, locale: locale))
                // `.callout`, matching the sunnah estimate mark beside the time.
                // Both annotate a clock rather than being one, and they read as
                // a matched pair at the same size; at `.caption` the gap was a
                // speck while its neighbour had just grown.
                .scaledFont(.callout)
                // `.secondary`, the system colour, like the mute ring beside it
                // — the gap is a qualifier on the time, not a value of its own,
                // so it should recede the same way the ring does. On the
                // highlighted row it takes the row's own colour instead, since
                // `.secondary` on a light highlight fill is unreadable.
                .foregroundColor(isNextPrayer ? textColor.opacity(0.8) : .secondary)
                .monospacedDigit()
                .lineLimit(1)
                .frame(width: PrayerListView.iqamaColumnWidth(fontScale: fontScale), alignment: .trailing)
                // Same locale-aware digits as the badge itself (`String(format:)`
                // without a locale would fall back to ASCII inside the sentence).
                .help(String(format: NSLocalizedString("iqama_delay_minutes", comment: ""), locale: locale, minutes))
        } else if hasIqamaColumn {
            Color.clear.frame(width: PrayerListView.iqamaColumnWidth(fontScale: fontScale), height: 1)
        }
    }

    /// Whether the rows reserve a slot for an iqama gap. Needs both halves of
    /// the same rule `displayedIqamaDelay(for:)` applies — a live gap somewhere
    /// to show, and the position not turned off — but checked across all rows
    /// rather than one, so the column exists from the first gap onward instead
    /// of shifting the times in as they load.
    private var hasIqamaColumn: Bool {
        vm.isMosqueTimetableActive && vm.iqamaDelayPosition != .none
    }

    /// The highlighted row is the one place the dimmed treatment never applies:
    /// it sits on the highlight fill, where a lightened ring would disappear.
    /// Plain accent mode also keeps the ring at full strength — that colour is
    /// the user's own pick, and dimming it would quietly change what they chose.
    private func isMuteIconDimmed(isNextPrayer: Bool) -> Bool { !isNextPrayer && vm.isMuteIconDimmed }

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
        } else if vm.muteIconStyle == .none {
            // "None" means no control, not an invisible one. The cell is still
            // reserved so the time column doesn't shift when the user switches
            // styles, but nothing is clickable, focusable, hoverable or
            // announced — an invisible button that still flips a setting is
            // worse than no button: it looks like a bug, and hovering it would
            // show a tooltip pointing at nothing.
            //
            // Muting stays reachable: the Adhan Sound page has the same
            // per-prayer toggle, always drawn as a speaker. This option is for
            // someone who wants the panel to be clocks only, not for someone
            // who wants to stop being able to mute from it.
            Color.clear
                .frame(width: 25, height: contentHeight)
        } else {
            // Per-prayer adhan on/off, right on the panel: muting flips
            // `PrayerSoundConfig.muted` (never the sound picked in Settings).
            let muted = vm.isAdhanMuted(prayerName)
            Button(action: { vm.setAdhanMuted(!muted, for: prayerName) }) {
                // One icon, four possible glyphs, one colour — see
                // `AdhanMuteButtonIcon`. The highlighted row is the exception on
                // opacity: it sits on the highlight fill, where a dimmed ring
                // would disappear, so it passes 1.0. Every other row has plain
                // panel behind it and takes the dimming, which applies to the
                // calm secondary ring only (accent off, or "Dim Mute Button" on)
                // and never to the user's own accent at full strength.
                //
                // "Dim Mute Button" extends the calm secondary to accent mode:
                // with it on, the icon is secondary off the highlight, so the
                // accent is spent on the highlight alone.
                AdhanMuteButtonIcon(
                    style: vm.muteIconStyle,
                    muted: muted,
                    color: isNextPrayer ? (vm.useAccentColor ? textColor : .white) : vm.muteIconColor,
                    size: 13,
                    ringOpacity: isMuteIconDimmed(isNextPrayer: isNextPrayer) ? 0.55 : 1,
                    dotOpacity: isMuteIconDimmed(isNextPrayer: isNextPrayer) ? 0.85 : 1,
                    // Plain accent mode is the one case where the muted dot
                    // leaves the ring's colour: the accent is also the
                    // next-prayer highlight, so a muted row drawn in the accent
                    // read as highlighted too. Off the highlight the dot drops
                    // to the system secondary; on the highlight the row's own
                    // text colour already contrasts against the fill.
                    mutedDotColor: isNextPrayer ? nil : vm.mutedMuteDotColor,
                    isOnHighlight: isNextPrayer
                )
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
            // so theirs reads "Around 05:10". The iqama is the mosque's own
            // published gap after the adhan, and appears only under a mosque
            // timetable — under calculated times there is no iqama to know, so
            // the iqama half of the line is simply absent (see
            // `nextPrayerIqamaDate`).
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
