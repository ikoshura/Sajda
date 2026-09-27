// MARK: - GANTI SELURUH FILE: SettingsView.swift

import SwiftUI
import AppKit
import NavigationStack
import ColorSelector
import MacControlCenterUI

struct SettingsView: View {
    static let id = "SettingsNavigationStack"

    /// Top tab bar groups on this page. Calculation & Location, Adhan
    /// Sound, and Accessibility stay separate navigation pages below.
    /// Display leads the tab bar (its highlight swatch is the most-used
    /// control); System closes it.
    enum SettingsSection: String, CaseIterable, Identifiable {
        case display
        case appearance
        case prayerTimes
        case system

        var id: String { rawValue }

        /// Tab bar icon for each group.
        var icon: String {
            switch self {
            case .system: return "gearshape"
            case .display: return "display"
            case .appearance: return "paintpalette"
            case .prayerTimes: return "clock"
            }
        }

        /// Localized tab title.
        var titleKey: String {
            switch self {
            case .system: return "System"
            case .display: return "Display"
            case .appearance: return "Appearance"
            case .prayerTimes: return "Prayer"
            }
        }
    }

    @EnvironmentObject var vm: PrayerTimeViewModel
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var navigationModel: NavigationModel
    
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage(UpdateChecker.autoCheckKey) private var autoCheckForUpdates = false
    @State private var isHeaderHovering = false
    @State private var isLockHovering = false
    @State private var isCalcHovering = false
    @State private var isAdhanHovering = false
    @State private var isAccessibilityHovering = false
    @State private var isSyncingLaunchAtLogin = false
    /// Active Settings tab, persisted in `vm.settingsSelectedTab` (not `@State`):
    /// NavigationStack swaps its content branch when the pop's precede flag
    /// flips, recreating the pushed SettingsView with fresh state — fresh
    /// `.display` is what used to flash over Appearance during the fade back
    /// to Main. Display starts open so the page still shows real settings.
    private var expandedSection: SettingsSection {
        SettingsSection(rawValue: vm.settingsSelectedTab) ?? .display
    }
    @State private var hoveringTab: SettingsSection? = nil
    /// Travel direction of the last tab change. Drives the slide edges; the
    /// `leading`/`trailing` edges below are layout-direction aware, so Arabic
    /// mirrors the whole motion for free.
    @State private var tabTravel: TabTravel = .forward

    private enum TabTravel {
        case forward   // moving right in the tab bar (higher index)
        case backward  // moving left in the tab bar (lower index)
    }

    private var viewWidth: CGFloat {

        return vm.panelWidth(base: vm.useCompactLayout ? 220 : 260)
    }


    /// The swatch button the package ships always writes `true` into its
    /// `popover` binding, so this binding turns that into a toggle: tapping the
    /// swatch while the dropdown is open closes it.
    private var colorPickerToggle: Binding<Bool> {
        Binding(
            get: { vm.settingsColorPickerOpen },
            set: { _ in vm.settingsColorPickerOpen.toggle() }
        )
    }

    /// ColorSelector writes the picked colour as "#RRGGBB[AA]" (alpha from
    /// the opacity slider); nil means "no custom colour yet". Picking one
    /// enables accent mode, exactly like tapping a palette swatch.
    private var highlightColorSelection: Binding<Color?> {
        Binding(
            get: { PrayerTimeViewModel.color(fromHex: vm.customHighlightColorHex) },
            set: { picked in
                guard let picked else { return }
                vm.customHighlightColorHex = PrayerTimeViewModel.hexString(from: picked)
                if !vm.useAccentColor { vm.useAccentColor = true }
            }
        )
    }

    // MARK: - Tab swap animation

    /// Animation for the tab content swap, mirroring the curves the pushed
    /// pages use for the same `Animation Style` setting — the library's
    /// `sajdaCrossfade` (`.easeInOut(0.25)`) and `push`/`pop` (`.easeOut`).
    private var tabAnimation: Animation? {
        return nil
    }

    /// Transition for the tab content swap. Fade keeps the library's
    /// crossfade (with the tiny scale that sells the depth); slide runs along
    /// the tab order — the incoming tab enters from the trailing edge while
    /// the outgoing one leaves to the leading edge, mirrored when travelling
    /// backwards to the left.
    private var tabTransition: AnyTransition {
        return .identity
    }

    /// Switches the active tab: records which way the tab bar travels, then
    /// swaps the content using the user's `Animation Style`.
    private func selectTab(_ section: SettingsSection) {
        guard section != expandedSection else { return }

        // Leaving a tab takes its transient UI with it: the colour dropdown's
        // rows are torn out by the swap now that only the picked tab is built,
        // so it is dismissed here rather than left open to re-expand the panel
        // the next time Appearance is picked.
        if vm.settingsColorPickerOpen { vm.settingsColorPickerOpen = false }

        let order = SettingsSection.allCases
        let from = order.firstIndex(of: expandedSection) ?? 0
        let to = order.firstIndex(of: section) ?? 0
        tabTravel = to > from ? .forward : .backward

        // SwiftUI takes the *removal* transition from the body built before the
        // swap, so the direction has to land in an earlier update — otherwise
        // the outgoing tab slides the way of the previous change.
        // Writes to `vm.settingsSelectedTab` (a @Published @AppStorage on the
        // view model) rather than local @State: NavigationStack recreates the
        // pushed SettingsView mid-pop (precede-branch swap), and fresh @State
        // would snap back to `.display` — the Display-tab flash over
        // Appearance on the way back to Main.
        DispatchQueue.main.async {
            withAnimation(tabAnimation) {
                vm.settingsSelectedTab = section.rawValue
            }
        }
    }

    var body: some View {
        NavigationStackView(Self.id) {
            VStack(alignment: .leading, spacing: 6) {
                // Header overlay: the back button spans the full row so its
                // hover pill reaches the lock area, while the lock sits on top
                // with its own pill. While the lock is hovered the back pill
                // is suppressed, so only the lock highlights.
                ZStack(alignment: .trailing) {
                    Button(action: {
                        vm.settingsColorPickerOpen = false
                        navigationModel.hideView(ContentView.id, animation: vm.backwardAnimation())
                        // Reset to Display AFTER the exit transition finishes (unless the
                        // tab is locked): resetting now would snap the exiting view to
                        // Display mid-fade (the original flash). Delays mirror the exit
                        // curves (0.25s fade, ~0.35s slide).
                        if !vm.settingsTabLocked {
                            let delay: Double
                            switch vm.animationType {
                            case .none: delay = 0
                            case .fade: delay = 0.3
                            case .slide: delay = 0.4
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                vm.settingsSelectedTab = SettingsSection.display.rawValue
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: vm.backChevron).scaledFont(.body, weight: .semibold)
                            Text("Settings").scaledFont(.body, weight: .bold)
                            Spacer()
                        }
                        .padding(.vertical, 5).padding(.horizontal, 8)
                        .liquidHover(isHeaderHovering && !isLockHovering)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in isHeaderHovering = hovering }
                    // Tab pin at the trailing edge: locked keeps the last-used tab
                    // when Settings is reopened; unlocked always reopens on Display.
                    Button(action: { vm.settingsTabLocked.toggle() }) {
                        Image(systemName: vm.settingsTabLocked ? "lock.fill" : "lock.open")
                            .scaledFont(.body, weight: .semibold)
                            .foregroundColor(vm.settingsTabLocked ? vm.selectedHighlightColor : .secondary)
                            .padding(.vertical, 5).padding(.horizontal, 8)
                            .liquidHover(isLockHovering)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .onHover { hovering in isLockHovering = hovering }
                    .help(Text(NSLocalizedString(vm.settingsTabLocked ? "Unlock Settings tab" : "Lock Settings tab", comment: "")))
                    .accessibilityLabel(Text(NSLocalizedString(vm.settingsTabLocked ? "Unlock Settings tab" : "Lock Settings tab", comment: "")))
                }
                .padding(.horizontal, 5).padding(.top, 2)

                Rectangle()
                .fill(Color("DividerColor"))
                .frame(height: 0.5)
                .padding(.horizontal, 12)

                // Tab bar: four icon tabs. Tapping one drops the other three's
                // rows away and lets the panel resize to the picked tab's — a
                // dropdown for the page content, so each tab gets its own
                // height. (The swap itself is still the disabled-by-design
                // crossfade; the resize is animated by the menu below.)
                HStack(spacing: 2) {
                    ForEach(SettingsSection.allCases) { section in
                        SettingsTabButton(
                            section: section,
                            isSelected: expandedSection == section,
                            isHovering: hoveringTab == section,
                            accent: vm.selectedHighlightColor,
                            onTap: {
                                selectTab(section)
                            },
                            onHover: { hovering in
                                hoveringTab = hovering ? section : nil
                            }
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)

                // The tab bar works as a dropdown: only the picked tab’s rows
                // are built, and the panel resizes to them — every tab sizes
                // the page differently, so there is neither a scroller nor a
                // fixed-height well here. (The menu’s own max-height scroller
                // still takes over if a page ever outgrows the screen.)
                Group { sectionBody(expandedSection) }
                    .id(expandedSection)
                    .transition(tabTransition)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .controlSize(.small)
                    .padding(.horizontal, 13)
                // Keeps a sliding tab inside the content area instead of
                // sweeping across the tab bar and the rows below it.
                    .clipped()
                    .padding(.top, 2)
                // The System tab’s "check now" side effect fires from here —
                // there is a single live copy of that toggle.
                    .onChange(of: autoCheckForUpdates) { enabled in
                        if enabled { UpdateChecker.shared.checkIfDue() }
                    }

                Spacer(minLength: 0)

                Rectangle().fill(Color("DividerColor")).frame(height: 1).padding(.horizontal, 12)

                VStack(alignment: .leading, spacing: 0) {
                    Button(action: {
                        if vm.settingsColorPickerOpen {
                            vm.settingsColorPickerOpen = false
                        }
                        navigationModel.showView(Self.id, animation: vm.forwardAnimation()) { LocationAndCalcSettingsView() }
                    }) {
                        HStack { Text("Calculation & Location").scaledFont(.subheadline); Spacer(); Image(systemName: vm.forwardChevron).scaledFont(.caption, weight: .bold).foregroundColor(.secondary) }
                .padding(.vertical, 5).padding(.horizontal, 8).liquidHover(isCalcHovering)
                }.buttonStyle(.plain).padding(.horizontal, 5).onHover { hovering in isCalcHovering = hovering }

                    Button(action: {
                        if vm.settingsColorPickerOpen {
                            vm.settingsColorPickerOpen = false
                        }
                        navigationModel.showView(Self.id, animation: vm.forwardAnimation()) { SystemAndNotificationsSettingsView() }
                    }) {
                        HStack { Text("Adhan Sound").scaledFont(.subheadline); Spacer(); Image(systemName: vm.forwardChevron).scaledFont(.caption, weight: .bold).foregroundColor(.secondary) }
                .padding(.vertical, 5).padding(.horizontal, 8).liquidHover(isAdhanHovering)
                }.buttonStyle(.plain).padding(.horizontal, 5).onHover { hovering in isAdhanHovering = hovering }

                    Button(action: {
                        if vm.settingsColorPickerOpen {
                            vm.settingsColorPickerOpen = false
                        }
                        navigationModel.showView(Self.id, animation: vm.forwardAnimation()) { AccessibilitySettingsView() }
                    }) {
                        HStack { Text("Accessibility").scaledFont(.subheadline); Spacer(); Image(systemName: vm.forwardChevron).scaledFont(.caption, weight: .bold).foregroundColor(.secondary) }
                .padding(.vertical, 5).padding(.horizontal, 8).liquidHover(isAccessibilityHovering)
                }.buttonStyle(.plain).padding(.horizontal, 5).onHover { hovering in isAccessibilityHovering = hovering }
                }
            }
            // Only the sliver the library’s own ~6pt menu chrome does not
            // already cover: an 8pt pad here doubled the panel’s dead air at
            // the top and bottom edges.
            .padding(.top, 2)
            .padding(.bottom, 2)
            .frame(width: viewWidth)
            .onAppear(perform: syncLaunchAtLoginState)
            .onChange(of: launchAtLogin) { newValue in
                guard !isSyncingLaunchAtLogin else { return }
                StartupManager.toggleLaunchAtLogin(isEnabled: newValue)
            }
        }
    }

    /// One tab's settings rows. Only the picked tab's body is built, so this is
    /// always the live copy — there is no invisible twin to keep a side effect
    /// or the colour popover away from.
    @ViewBuilder
    private func sectionBody(_ section: SettingsSection) -> some View {
        switch section {
        case .system:
            systemSection
        case .display:
            displaySection
        case .appearance:
            appearanceSection
        case .prayerTimes:
            prayerTimesSection
        }
    }

    private var systemSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            StyledToggle(label: "Run at Login", isOn: $launchAtLogin)
                .disabled(isSyncingLaunchAtLogin)
            // The "check now" side effect fires from this one live copy of the
            // row — see `.onChange(of: autoCheckForUpdates)` on the content.
            StyledToggle(label: "Check for Updates Automatically", isOn: $autoCheckForUpdates)
            // Seconds only exist in the countdown modes: the exact-time modes
            // print a fixed clock time, and Icon Only prints no text at all.
            StyledToggle(label: "Show Seconds", isOn: $vm.menuBarShowSeconds).disabled(!vm.menuBarTextMode.isCountdown)
            HStack {
                Text("Animation Style").scaledFont(.subheadline)
                Spacer()
                ScaledMenuPicker(selection: $vm.animationType, options: AnimationType.allCases) { NSLocalizedString($0.rawValue, comment: "") }
            }
        }
    }

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Language").scaledFont(.subheadline); Spacer(); ScaledMenuPicker(selection: $languageManager.language, options: ["en", "ar", "id", "es", "fr", "de", "ja", "日本語", "zh-Hans", "ko"]) { code in ["en": "English", "ar": "العربية", "id": "Indonesia", "es": "Español", "fr": "Français", "de": "Deutsch", "ja": "日本語", "zh-Hans": "简体中文", "ko": "한국어"][code] ?? code } }
            HStack { Text("Menu Bar Style").scaledFont(.subheadline); Spacer(); ScaledMenuPicker(selection: $vm.menuBarTextMode, options: MenuBarTextMode.allCases) { NSLocalizedString($0.rawValue, comment: "") } }
            StyledToggle(label: "Compact View", isOn: $vm.useCompactLayout)
            StyledToggle(label: "24-Hour Time", isOn: $vm.use24HourFormat)
            StyledToggle(label: "Minimal Menu Bar", isOn: $vm.useMinimalMenuBarText).disabled(vm.menuBarTextMode == .hidden)
        }
    }

    /// Appearance rows. The colour surface's open flag lives on the view model
    /// (`settingsColorPickerOpen`) so the menu can animate the panel's height
    /// as it drops down — it is not a popover any more, it is rows of this page.
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            StyledToggle(label: "Accent Color", isOn: $vm.useAccentColor)
            // Tints the whole panel; the panel's colour scheme flips
            // to balance text and controls against the tint.
            StyledToggle(label: "Accent Panel", isOn: $vm.accentPanelTheme)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Custom Color").scaledFont(.subheadline)
                    Spacer()
                    Button("Default") { vm.customHighlightColorHex = "" }
                        .controlSize(.mini)
                        .disabled(vm.customHighlightColorHex.isEmpty)
                }
                // Fixed palette instead of a system colour picker: the
                // picker's NSColorPanel never becomes usable inside this
                // non-activating menu bar panel.
                HStack(spacing: 4) {
                    ForEach(PrayerTimeViewModel.highlightColorPresets, id: \.hex) { preset in
                        HighlightColorSwatch(
                            hex: preset.hex,
                            nameKey: preset.key,
                            isSelected: vm.customHighlightColorHex.caseInsensitiveCompare(preset.hex) == .orderedSame
                        ) {
                            vm.customHighlightColorHex = preset.hex
                            // The custom fill only shows while accent mode
                            // is on, so picking one enables it instead of
                            // appearing to do nothing.
                            if !vm.useAccentColor { vm.useAccentColor = true }
                        }
                    }
                    // Any-colour picker (jaywcjlove/ColorSelector): the same
                    // swatch, but its surface drops down inside the page under
                    // the row instead of opening as a popover. Part of the
                    // panel, so it can never leave an orphaned popover over it,
                    // and the height it adds is eased in by the menu (the open
                    // flag is half of its layout signature).
                    ColorSelectorButton(
                        popover: colorPickerToggle,
                        selection: highlightColorSelection,
                        controlSize: .constant(.mini)
                    )
                    Spacer(minLength: 0)
                }
                if vm.settingsColorPickerOpen {
                    InlineColorSelector(selection: highlightColorSelection)
                }
            } // closes the Custom Color inner stack
            StyledToggle(label: "Glass Highlight", isOn: $vm.useGlassPrayerHighlight)
        }
    }

    private var prayerTimesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Umm al-Qura Hijri header (matches the system Calendar)
            // with a ±2 day correction where the local announcement
            // differs.
            HStack {
                Text("Hijri Date").scaledFont(.subheadline)
                Spacer()
                SajdaStepper(value: Binding(get: { Double(vm.hijriDateAdjustment) }, set: { vm.hijriDateAdjustment = Int($0) }), range: -2...2)
            }
            // How long before prayer the red imminent alert starts;
            // 0 disables it (shown as "Off"). Default is 10 minutes.
            HStack {
                Text("Red Alert").scaledFont(.subheadline)
                Spacer()
                if vm.redAlertMinutes == 0 {
                    Text("Red Alert Off").scaledFont(.caption).foregroundColor(Color("SecondaryTextColor"))
                }
                SajdaStepper(value: Binding(get: { Double(vm.redAlertMinutes) }, set: { vm.redAlertMinutes = Int($0) }), range: 0...60, showsSign: false)
            }
            StyledToggle(label: "Show Countdown Header", isOn: $vm.showCountdownHeader)
            StyledToggle(label: "Show Sunnah Prayers", isOn: $vm.showSunnahPrayers)
            // Travellers plan around Friday: with this on, the Jumu'ah row
            // under Dhuhr shows every day instead of Fridays only.
            StyledToggle(label: "Always Show Jumu'ah", isOn: $vm.alwaysShowJumuah)
            // Friday (Jumu'ah) sessions, one clock row each: several mosques
            // hold multiple gatherings. Empty = no Jumu'ah row on the panel.
            // A text input was considered; the ± steppers win — free-typing
            // needs its own validation/error surface, and time input inside
            // this non-activating panel has proven fiddly (see `SajdaSearchField`).
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Jumu'ah Sessions").scaledFont(.subheadline)
                    Spacer()
                    Button(action: addJumuahSession) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canAddJumuahSession)
                    .opacity(canAddJumuahSession ? 1 : 0.3)
                    .help(Text(NSLocalizedString("Add session", comment: "")))
                    .accessibilityLabel(Text(NSLocalizedString("Add session", comment: "")))
                }
                if vm.jumuahSessions.isEmpty {
                    Text("No sessions — nothing extra shows on Fridays.")
                        .scaledFont(.caption2)
                        .foregroundColor(Color("SecondaryTextColor"))
                } else {
                    VStack(spacing: 6) {
                        ForEach(vm.jumuahSessions.indices, id: \.self) { index in
                            JumuahSessionTimeField(
                                index: index + 1,
                                minutes: jumuahSessionBinding(for: index),
                                onDelete: { removeJumuahSession(at: index) }
                            )
                        }
                    }
                }
            }
        }
    }

    /// Whether one more Friday session can be appended: strictly below the cap.
    private var canAddJumuahSession: Bool {
        vm.jumuahSessions.count < PrayerTimeViewModel.maxJumuahSessions
    }

    /// Appends a session seeded at today's Dhuhr rounded up to the next quarter
    /// hour (`vm.jumuahSeedMinutes`): Jumu'ah follows Dhuhr, so a seed off the
    /// wall clock dropped new rows at arbitrary morning times. The clash nudge
    /// keeps the new row from silently deduping away on write.
    private func addJumuahSession() {
        var sessions = vm.jumuahSessions
        guard sessions.count < PrayerTimeViewModel.maxJumuahSessions else { return }
        var seed = vm.jumuahSeedMinutes
        var guardCount = 0
        while sessions.contains(seed), guardCount < PrayerTimeViewModel.maxJumuahSessions * 20 {
            seed = (seed + 15) % 1440
            guardCount += 1
        }
        sessions.append(seed)
        vm.jumuahSessions = sessions
    }

    /// Two-way binding from the sanitised list to one session's clock time in
    /// minutes past midnight (0...1439), so the ± steppers never build an
    /// invalid clock time.
    private func jumuahSessionBinding(for index: Int) -> Binding<Int> {
        Binding(
            get: {
                let sessions = vm.jumuahSessions
                guard sessions.indices.contains(index) else { return 0 }
                return sessions[index]
            },
            set: { newMinutes in
                var sessions = vm.jumuahSessions
                guard sessions.indices.contains(index) else { return }
                sessions[index] = ((newMinutes % 1440) + 1440) % 1440
                vm.jumuahSessions = sessions
            }
        )
    }

    private func removeJumuahSession(at index: Int) {
        var sessions = vm.jumuahSessions
        guard sessions.indices.contains(index) else { return }
        sessions.remove(at: index)
        vm.jumuahSessions = sessions
    }

    /// Keeps the login-item toggle in sync with the real system state when the
    /// page appears (it may have been changed in System Settings).
    private func syncLaunchAtLoginState() {
        let currentSystemState = StartupManager.isLaunchAtLoginEnabled
        guard launchAtLogin != currentSystemState else { return }

        isSyncingLaunchAtLogin = true
        launchAtLogin = currentSystemState
        DispatchQueue.main.async {
            isSyncingLaunchAtLogin = false
        }
    }
}

/// One Friday session row in the Settings > Prayer tab: the row number ("1",
/// "2", …) plus the clock as two ± steppers (hour, then minute) and a trailing
/// delete, in the same row shape as the other settings controls. Hour and
/// minute steps beat the ±15 minute variant: sessions like 12:30 are one row
/// either way, but an odd time like 13:05 can't be reached by quarter-hour
/// steps at all.
///
/// The number replaces the old repeated "Session" label: next to two steppers
/// and the delete button the word had no room left even at the 260 pt panel
/// width (let alone compact 220 pt), so it wrapped into a vertical
/// letter-per-line column and stretched every row into a block.
private struct JumuahSessionTimeField: View {
    /// 1-based position in the session list, shown in the leading slot.
    let index: Int
    /// Session clock time in minutes past midnight (0...1439).
    @Binding var minutes: Int
    let onDelete: () -> Void

    @Environment(\.panelFontScale) private var fontScale
    @State private var isDeleteHovering = false

    var body: some View {
        HStack(spacing: 4) {
            Text(verbatim: "\(index)")
                .scaledFont(.caption)
                .foregroundColor(Color("SecondaryTextColor"))
                .frame(minWidth: 12, alignment: .leading)
                .fixedSize()
                .accessibilityLabel(Text(NSLocalizedString("Session", comment: "")))
                .accessibilityValue(Text(verbatim: "\(index)"))
            Spacer(minLength: 4)
            // Narrower fields than the other settings rows: the hour + minute
            // pair, the row number and the delete only fit the compact panel
            // width with a few points shaved off each field. Scaled with the
            // text preset so the bigger fonts (which also widen the panel)
            // never clip the digits.
            SajdaStepper(value: hourBinding, range: 0...23, showsSign: false, fieldWidth: 22 * fontScale)
            Text(":")
                .scaledFont(.subheadline)
                .foregroundColor(.secondary)
            SajdaStepper(value: minuteBinding, range: 0...59, showsSign: false, fieldWidth: 22 * fontScale)
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(Text(NSLocalizedString("Remove session", comment: "")))
            .accessibilityLabel(Text(NSLocalizedString("Remove session", comment: "")))
            .onHover { hovering in isDeleteHovering = hovering }
        }
        .liquidHover(false)
    }

    /// Hour of the session clock, driven back into the minutes-past-midnight
    /// binding: the ± steppers never build an invalid time.
    private var hourBinding: Binding<Double> {
        Binding(
            get: { Double(minutes / 60) },
            set: { minutes = (Int($0) % 24) * 60 + minutes % 60 }
        )
    }

    /// Minute of the session clock, same round trip.
    private var minuteBinding: Binding<Double> {
        Binding(
            get: { Double(minutes % 60) },
            set: { minutes = (minutes / 60) * 60 + (Int($0) % 60) }
        )
    }
}

/// Top icon tab in the Settings tab bar: icon above a tiny grey label,
/// with a liquid-hover pill and a highlight-colour underline when selected.
private struct SettingsTabButton: View {
    let section: SettingsView.SettingsSection
    let isSelected: Bool
    let isHovering: Bool
    /// Selected-tab tint: the user's highlight colour, or the system accent
    /// when none is picked (`vm.selectedHighlightColor`).
    let accent: Color
    let onTap: () -> Void
    let onHover: (Bool) -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Image(systemName: section.icon)
                    .scaledFont(.body, weight: isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? accent : .secondary)
                    .frame(height: 20)
                Text(LocalizedStringKey(section.titleKey))
                    .scaledFont(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .liquidHover(isHovering || isSelected)
            .overlay(alignment: .bottom) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(accent)
                        .frame(height: 2)
                        .padding(.horizontal, 10)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover(perform: onHover)
        .help(Text(LocalizedStringKey(section.titleKey)))
        .accessibilityLabel(Text(LocalizedStringKey(section.titleKey)))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
/// The colour surface behind ColorSelector's popover, hosted inline as a
/// dropdown under the "Custom Color" row: saturation square plus hue and alpha
/// sliders, part of the Settings page instead of floating over it. Opening it
/// grows the panel (the menu eases that resize in — `settingsColorPickerOpen`
/// is half of its layout signature), and since the surface is the page itself
/// there is no popover anchor left to lose when the row moves or the page
/// swaps.
///
/// `Sketch` and its HSB bindings are the package's public API. The seeding is
/// ours because the package's own `Color.hue/saturation/brightness/alpha`
/// helpers are internal to it — see `PrayerTimeViewModel.hsbaComponents(from:)`.
private struct InlineColorSelector: View {
    /// The picked colour ("#RRGGBB[AA]"), written back through the same
    /// binding the preset palette uses.
    @Binding var selection: Color?

    @State private var hue: CGFloat = 0
    @State private var saturation: CGFloat = 1
    @State private var brightness: CGFloat = 1
    @State private var alpha: CGFloat = 1

    var body: some View {
        ZStack {
            Color(nsColor: NSColor.windowBackgroundColor)
            Sketch(hue: $hue, saturation: $saturation, brightness: $brightness, alpha: $alpha)
                .showsAlpha(true)
                // Same round trip the package's popover runs: HSB is the
                // surface's working state, `selection` is what the rest of the
                // panel reads (and what persists).
                .onChange(of: hue) { _, _ in pushSelection() }
                .onChange(of: saturation) { _, _ in pushSelection() }
                .onChange(of: brightness) { _, _ in pushSelection() }
                .onChange(of: alpha) { _, _ in pushSelection() }
        }
        .frame(maxWidth: .infinity)
        // The package's own surface size (its popover is 180 × 250); the width
        // fills the row instead so it reads as one block of the page.
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        // Seeded once per opening, exactly as the popover did — also watching
        // `selection` would feed this round trip back into itself.
        .onAppear(perform: seedFromSelection)
    }

    /// Writes the surface's HSB state back out as the picked colour.
    private func pushSelection() {
        selection = Color(hue: hue, saturation: saturation, brightness: brightness, opacity: alpha)
    }

    /// Loads the current pick into the surface when it drops down.
    private func seedFromSelection() {
        let hsba = PrayerTimeViewModel.hsbaComponents(from: selection)
        hue = hsba.hue
        saturation = hsba.saturation
        brightness = hsba.brightness
        alpha = hsba.alpha
    }
}

/// One preset in the highlight palette: a filled circle with a selection ring.
/// Sized to sit on the settings rows' small control size, and labelled with the
/// localized colour name for hover help and VoiceOver.
private struct HighlightColorSwatch: View {
    let hex: String
    let nameKey: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(PrayerTimeViewModel.color(fromHex: hex))
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(Color.primary.opacity(0.25), lineWidth: 0.5))
                .overlay {
            // The selection ring hugs the swatch so it can never overlap
            // its neighbour in the compact (220 pt) panel layout.
            if isSelected {
            Circle().stroke(Color.primary.opacity(0.9), lineWidth: 1.5)
            }
                }
                // Slightly larger than the dot: a 14 pt target is easy to miss.
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(Text(NSLocalizedString(nameKey, comment: "")))
        .accessibilityLabel(Text(NSLocalizedString(nameKey, comment: "")))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
