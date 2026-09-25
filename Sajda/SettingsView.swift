// MARK: - GANTI SELURUH FILE: SettingsView.swift

import SwiftUI
import NavigationStack
import ColorSelector

struct SettingsView: View {
    static let id = "SettingsNavigationStack"

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
    @State private var showHighlightColorPicker = false
    /// Whether this picker's popover is meant to be up right now. Set from
    /// the same taps that flip `showHighlightColorPicker`, and read back on
    /// the guarded navigation instead of the popover's own fade timing.
    @State private var isHighlightColorPickerOpen = false

    /// Single identifier for "is the colour-selector popup up right now".
    /// True when the drawer is open; false when never opened or already
    /// dismissed (e.g. by an outside click). The back button reads this:
    /// open → close + ~0.55 s delay, closed → pop instantly, no delay.
    private var isColorSelectorPopupOpen: Bool {
        showHighlightColorPicker || isHighlightColorPickerOpen
    }

    /// Close the colour-picker drawer, then run `work` once its dismiss
    /// animation AND the panel resize it drives have both settled. The
    /// drawer's `.popover` fade plus the window's animated `setFrame`
    /// together run ~0.4 s from the click (state flip → next-runloop
    /// dismiss start → ~0.25–0.35 s frame animation). Firing the page pop
    /// at 0.3 s lands mid-resize, so both `setFrame` animations overlap
    /// and fight — that's the top-bottom-top jump. Waiting ~0.55 s only
    /// when the drawer was actually open keeps the already-closed path
    /// instant.
    private func afterPickerClosed(_ work: @escaping () -> Void) {
        if isColorSelectorPopupOpen {
            showHighlightColorPicker = false
            isHighlightColorPickerOpen = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55, execute: work)
        } else {
            work()
        }
    }

    /// Record that the drawer's popover is meant to be up. Kept in the same
    /// places the picker's `isPresented` binding flips, so the navigation
    /// buttons above can tell an open drawer from one that was already
    /// dismissed by an outside click.
    private func noteHighlightColorPicker(presented: Bool) {
        isHighlightColorPickerOpen = presented
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

    var body: some View {
        NavigationStackView(Self.id) {
            VStack(alignment: .leading, spacing: 6) {
                Button(action: {
                    // One click: close the drawer first, then pop once its
                    // dismiss + panel resize have both settled. 0.3 s fired
                    // mid-resize so the two `setFrame` animations overlapped
                    // and fought (the jump); ~0.55 s only applies when the
                    // drawer was actually open, otherwise the pop is instant.
                    afterPickerClosed {
                        navigationModel.hideView(ContentView.id, animation: vm.backwardAnimation())
                    }
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

                VStack(alignment: .leading, spacing: 12) {
                    Text("System").scaledFont(.caption).foregroundColor(Color("SecondaryTextColor"))
                    StyledToggle(label: "Run at Login", isOn: $launchAtLogin)
                    StyledToggle(label: "Check for Updates Automatically", isOn: $autoCheckForUpdates)
                        .onChange(of: autoCheckForUpdates) { enabled in
                            if enabled { UpdateChecker.shared.checkIfDue() }
                        }

                    HStack {
                        Text("Animation Style").scaledFont(.subheadline)
                        Spacer()
                        ScaledMenuPicker(selection: $vm.animationType, options: AnimationType.allCases) { NSLocalizedString($0.rawValue, comment: "") }
                    }

                    Text("Display").scaledFont(.caption).foregroundColor(Color("SecondaryTextColor"))
                    HStack { Text("Language").scaledFont(.subheadline); Spacer(); ScaledMenuPicker(selection: $languageManager.language, options: ["en", "ar", "id", "es", "fr", "de", "ja", "zh-Hans", "ko"]) { code in ["en": "English", "ar": "العربية", "id": "Indonesia", "es": "Español", "fr": "Français", "de": "Deutsch", "ja": "日本語", "zh-Hans": "简体中文", "ko": "한국어"][code] ?? code } }
                    HStack { Text("Menu Bar Style").scaledFont(.subheadline); Spacer(); ScaledMenuPicker(selection: $vm.menuBarTextMode, options: MenuBarTextMode.allCases) { NSLocalizedString($0.rawValue, comment: "") } }
                    // Umm al-Qura Hijri header (matches the system Calendar)
                    // with a ±2 day correction where the local announcement
                    // differs.
                    HStack {
                        Text("Hijri Date").scaledFont(.subheadline)
                        Spacer()
                        SajdaStepper(value: Binding(get: { Double(vm.hijriDateAdjustment) }, set: { vm.hijriDateAdjustment = Int($0) }), range: -2...2)
                    }
                    StyledToggle(label: "Compact View", isOn: $vm.useCompactLayout)
                    StyledToggle(label: "24-Hour Time", isOn: $vm.use24HourFormat)
                    StyledToggle(label: "Minimal Menu Bar", isOn: $vm.useMinimalMenuBarText).disabled(vm.menuBarTextMode == .hidden)
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
                                popover: Binding(
                                    get: { showHighlightColorPicker },
                                    set: {
                                        showHighlightColorPicker = $0
                                        noteHighlightColorPicker(presented: $0)
                                    }
                                ),
                                selection: highlightColorSelection,
                                controlSize: .constant(.mini)
                            )
                                .colorSelectorPopover(selection: highlightColorSelection, isPresented: $showHighlightColorPicker)
                            Spacer(minLength: 0)
                        }
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
                    StyledToggle(label: "Glass Highlight", isOn: $vm.useGlassPrayerHighlight)
                    StyledToggle(label: "Show Countdown Header", isOn: $vm.showCountdownHeader)
                    StyledToggle(label: "Show Sunnah Prayers", isOn: $vm.showSunnahPrayers)
                }
                .controlSize(.small)
                .padding(.horizontal, 16).padding(.top, 8)

                Spacer(minLength: 0)

                Rectangle().fill(Color("DividerColor")).frame(height: 1).padding(.horizontal, 12)

                VStack(alignment: .leading, spacing: 0) {
                    Button(action: {
                        if showHighlightColorPicker || isHighlightColorPickerOpen {
                            showHighlightColorPicker = false
                            isHighlightColorPickerOpen = false
                        }
                        navigationModel.showView(Self.id, animation: vm.forwardAnimation()) { LocationAndCalcSettingsView() }
                    }) {
                        HStack { Text("Calculation & Location").scaledFont(.subheadline); Spacer(); Image(systemName: vm.forwardChevron).scaledFont(.caption, weight: .bold).foregroundColor(.secondary) }
                        .padding(.vertical, 5).padding(.horizontal, 8).liquidHover(isCalcHovering)
                    }.buttonStyle(.plain).padding(.horizontal, 5).onHover { hovering in isCalcHovering = hovering }

                    Button(action: {
                        if showHighlightColorPicker || isHighlightColorPickerOpen {
                            showHighlightColorPicker = false
                            isHighlightColorPickerOpen = false
                        }
                        navigationModel.showView(Self.id, animation: vm.forwardAnimation()) { SystemAndNotificationsSettingsView() }
                    }) {
                        HStack { Text("Adhan Sound").scaledFont(.subheadline); Spacer(); Image(systemName: vm.forwardChevron).scaledFont(.caption, weight: .bold).foregroundColor(.secondary) }
                        .padding(.vertical, 5).padding(.horizontal, 8).liquidHover(isAdhanHovering)
                    }.buttonStyle(.plain).padding(.horizontal, 5).onHover { hovering in isAdhanHovering = hovering }

                    Button(action: {
                        if showHighlightColorPicker || isHighlightColorPickerOpen {
                            showHighlightColorPicker = false
                            isHighlightColorPickerOpen = false
                        }
                        navigationModel.showView(Self.id, animation: vm.forwardAnimation()) { AccessibilitySettingsView() }
                    }) {
                        HStack { Text("Accessibility").scaledFont(.subheadline); Spacer(); Image(systemName: vm.forwardChevron).scaledFont(.caption, weight: .bold).foregroundColor(.secondary) }
                        .padding(.vertical, 5).padding(.horizontal, 8).liquidHover(isAccessibilityHovering)
                    }.buttonStyle(.plain).padding(.horizontal, 5).onHover { hovering in isAccessibilityHovering = hovering }
                }
            }
            .padding(.vertical, 8)
            .frame(width: viewWidth)
            .onAppear(perform: syncLaunchAtLoginState)
            .onChange(of: launchAtLogin) { newValue in
                guard !isSyncingLaunchAtLogin else { return }
                StartupManager.toggleLaunchAtLogin(isEnabled: newValue)
            }
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
