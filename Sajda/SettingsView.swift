// MARK: - GANTI SELURUH FILE: SettingsView.swift

import SwiftUI
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
            case .prayerTimes: return "Prayer Times"
            }
        }
    }

    @EnvironmentObject var vm: PrayerTimeViewModel
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var navigationModel: NavigationModel
    
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage(UpdateChecker.autoCheckKey) private var autoCheckForUpdates = false
    @State private var isHeaderHovering = false
    @State private var isCalcHovering = false
    @State private var isAdhanHovering = false
    @State private var isAccessibilityHovering = false
    @State private var isSyncingLaunchAtLogin = false
    /// Single-open accordion: only one section is expanded at a time. Display
    /// starts open so the page's top still shows real settings on entry.
    @State private var expandedSection: SettingsSection = .display
    @State private var showHighlightColorPicker = false
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
        switch vm.animationType {
        case .none: return nil
        case .fade: return .easeInOut(duration: 0.25)
        case .slide: return .easeOut
        }
    }

    /// Transition for the tab content swap. Fade keeps the library's
    /// crossfade (with the tiny scale that sells the depth); slide runs along
    /// the tab order — the incoming tab enters from the trailing edge while
    /// the outgoing one leaves to the leading edge, mirrored when travelling
    /// backwards to the left.
    private var tabTransition: AnyTransition {
        switch vm.animationType {
        case .none:
            return .identity
        case .fade:
            return .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.97)),
                removal: .opacity
            )
        case .slide:
            return .asymmetric(
                insertion: .move(edge: tabTravel == .forward ? .trailing : .leading),
                removal: .move(edge: tabTravel == .forward ? .leading : .trailing)
            )
        }
    }

    /// Switches the active tab: records which way the tab bar travels, then
    /// swaps the content using the user's `Animation Style`.
    private func selectTab(_ section: SettingsSection) {
        guard section != expandedSection else { return }

        let order = SettingsSection.allCases
        let from = order.firstIndex(of: expandedSection) ?? 0
        let to = order.firstIndex(of: section) ?? 0
        tabTravel = to > from ? .forward : .backward

        // SwiftUI takes the *removal* transition from the body built before the
        // swap, so the direction has to land in an earlier update — otherwise
        // the outgoing tab slides the way of the previous change.
        DispatchQueue.main.async {
            withAnimation(tabAnimation) {
                expandedSection = section
            }
        }
    }

    var body: some View {
        NavigationStackView(Self.id) {
            VStack(alignment: .leading, spacing: 6) {
                Button(action: {
            showHighlightColorPicker = false
            navigationModel.hideView(ContentView.id, animation: vm.backwardAnimation())
                }) {
            HStack {
            Image(systemName: vm.backChevron).scaledFont(.body, weight: .semibold)
            Text("Settings").scaledFont(.body, weight: .bold)
            Spacer()
            }
            .padding(.vertical, 5).padding(.horizontal, 8)
            .liquidHover(isHeaderHovering)
                }.buttonStyle(.plain).padding(.horizontal, 5).padding(.top, 2).onHover { hovering in isHeaderHovering = hovering }
                
                Rectangle()
            .fill(Color("DividerColor"))
            .frame(height: 0.5)
            .padding(.horizontal, 12)

                // Tab bar: four icon tabs (no expand/collapse animation) —
                // tapping a tab swaps the content below with a quick crossfade.
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

                // Active tab content, inside a well that is always as tall as
                // the tallest tab (the inactive bodies are laid out invisibly
                // underneath it). Without that the panel resized on every tab
                // change: the separator above the footer rows drifted, and it
                // bounced while the outgoing and incoming bodies briefly
                // coexisted during the transition.
                ZStack(alignment: .topLeading) {
                    ForEach(SettingsSection.allCases) { section in
                        sectionBody(section, isLive: false)
                            .hidden()
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }

                    Group { sectionBody(expandedSection, isLive: true) }
                        .id(expandedSection)
                        .transition(tabTransition)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .controlSize(.small)
                .padding(.horizontal, 13)
                // Keeps a sliding tab inside the content area instead of
                // sweeping across the tab bar and the rows below it.
                .clipped()
                .padding(.top, 2)
                // Single instance of the side effect the System tab's toggle
                // carries — the invisible height copies must not repeat it.
                .onChange(of: autoCheckForUpdates) { enabled in
                    if enabled { UpdateChecker.shared.checkIfDue() }
                }

                Spacer(minLength: 0)

                Rectangle().fill(Color("DividerColor")).frame(height: 1).padding(.horizontal, 12)

                VStack(alignment: .leading, spacing: 0) {
                    Button(action: {
                        if showHighlightColorPicker {
                            showHighlightColorPicker = false
                        }
                        navigationModel.showView(Self.id, animation: vm.forwardAnimation()) { LocationAndCalcSettingsView() }
                    }) {
                        HStack { Text("Calculation & Location").scaledFont(.subheadline); Spacer(); Image(systemName: vm.forwardChevron).scaledFont(.caption, weight: .bold).foregroundColor(.secondary) }
            .padding(.vertical, 5).padding(.horizontal, 8).liquidHover(isCalcHovering)
            }.buttonStyle(.plain).padding(.horizontal, 5).onHover { hovering in isCalcHovering = hovering }

                    Button(action: {
                        if showHighlightColorPicker {
                            showHighlightColorPicker = false
                        }
                        navigationModel.showView(Self.id, animation: vm.forwardAnimation()) { SystemAndNotificationsSettingsView() }
                    }) {
                        HStack { Text("Adhan Sound").scaledFont(.subheadline); Spacer(); Image(systemName: vm.forwardChevron).scaledFont(.caption, weight: .bold).foregroundColor(.secondary) }
            .padding(.vertical, 5).padding(.horizontal, 8).liquidHover(isAdhanHovering)
            }.buttonStyle(.plain).padding(.horizontal, 5).onHover { hovering in isAdhanHovering = hovering }

                    Button(action: {
                        if showHighlightColorPicker {
                            showHighlightColorPicker = false
                        }
                        navigationModel.showView(Self.id, animation: vm.forwardAnimation()) { AccessibilitySettingsView() }
                    }) {
                        HStack { Text("Accessibility").scaledFont(.subheadline); Spacer(); Image(systemName: vm.forwardChevron).scaledFont(.caption, weight: .bold).foregroundColor(.secondary) }
            .padding(.vertical, 5).padding(.horizontal, 8).liquidHover(isAccessibilityHovering)
            }.buttonStyle(.plain).padding(.horizontal, 5).onHover { hovering in isAccessibilityHovering = hovering }
                }
            }
            // Only the sliver the library's own ~6pt menu chrome does not
            // already cover: an 8pt pad here doubled the panel's dead air at
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

    /// One tab's settings rows.
    ///
    /// - Parameter isLive: `false` for the invisible copies that give the
    ///   content well the height of the tallest tab. Those copies must never
    ///   present transient UI (the colour popover) or repeat side effects.
    @ViewBuilder
    private func sectionBody(_ section: SettingsSection, isLive: Bool) -> some View {
        switch section {
        case .system:
            systemSection
        case .display:
            displaySection
        case .appearance:
            appearanceSection(isLive: isLive)
        case .prayerTimes:
            prayerTimesSection
        }
    }

    private var systemSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            StyledToggle(label: "Run at Login", isOn: $launchAtLogin)
                .disabled(isSyncingLaunchAtLogin)
            // The "check now" side effect lives on the content well, so the
            // invisible copies of this tab cannot fire it more than once.
            StyledToggle(label: "Check for Updates Automatically", isOn: $autoCheckForUpdates)
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

    /// - Parameter isLive: `false` on the invisible height copies, where the
    ///   colour popover must stay shut.
    private func appearanceSection(isLive: Bool) -> some View {
        // The popover binding reports "closed" for every non-live copy, so a
        // single presentation can never be triggered five times over.
        let pickerPresented = Binding(
            get: { isLive && showHighlightColorPicker },
            set: { presented in if isLive { showHighlightColorPicker = presented } }
        )
        return VStack(alignment: .leading, spacing: 12) {
            StyledToggle(label: "Accent Color", isOn: $vm.useAccentColor)
            // Tints the whole panel; the panel's colour scheme flips
            // to balance text and controls against the tint.
            StyledToggle(label: "Accent Panel", isOn: $vm.accentPanelTheme)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Highlight Color").scaledFont(.subheadline)
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
                    // Any-colour picker (jaywcjlove/ColorSelector): a
                    // native SwiftUI popover, unlike NSColorPanel, so it
                    // works inside this non-activating menu bar panel.
                    ColorSelectorButton(
                        popover: pickerPresented,
                        selection: highlightColorSelection,
                        controlSize: .constant(.mini)
                    )
                        .colorSelectorPopover(selection: highlightColorSelection, isPresented: pickerPresented)
                    Spacer(minLength: 0)
                }
            } // closes the Highlight Color inner stack
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
        }
    }

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
