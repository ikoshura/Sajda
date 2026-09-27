// MARK: - GANTI SELURUH FILE: PrayerTimeCorrectionView.swift

import SwiftUI
import Combine
import NavigationStack

struct CorrectionRow: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    let prayerName: String
    @Binding var value: Double
    
    var body: some View {
        let originalTime = getOriginalTime(prayerName, for: value)
        let adjustedTime = getAdjustedTime(originalTime: originalTime, for: value)
        let isDefaultValue = value == 0
        
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(LocalizedStringKey(prayerName))
                    .scaledFont(.caption)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Button(action: {
                        withAnimation(.spring()) { value = 0 }
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .disabled(isDefaultValue)
                    
                    SajdaStepper(value: $value)
                }
            }
            
            // Pratinjau Inline
            HStack {
                Spacer()
                if let original = originalTime, let adjusted = adjustedTime {
                    Text(vm.dateFormatter.string(from: original))
                        .strikethrough(color: .secondary)
                    Image(systemName: vm.forwardArrow)
                        .font(.system(size: 11, weight: .semibold))
                    Text(vm.dateFormatter.string(from: adjusted))
                        .fontWeight(.semibold)
                        // Follows the selected highlight colour, like the rest
                        // of the panel's interactive accents.
                        .foregroundColor(vm.selectedHighlightColor)
                } else {
                    Text("00:00 → 00:00").hidden()
                }
            }
            .scaledFont(.caption2)
            .foregroundColor(.secondary)
            .opacity(isDefaultValue ? 0 : 1)
            .animation(.easeInOut(duration: 0.2), value: isDefaultValue)
        }
    }
    
    private func getOriginalTime(_ prayer: String, for currentValue: Double) -> Date? {
        // Fajr follows the shared display date: after Isha that is tomorrow's
        // Fajr, so the preview matches the panel row and the menu bar.
        let baseTime = prayer == "Fajr" ? (vm.displayedFajrTime ?? vm.todayTimes[prayer]) : vm.todayTimes[prayer]
        guard let time = baseTime else { return nil }
        return time.addingTimeInterval(-currentValue * 60)
    }
    
    private func getAdjustedTime(originalTime: Date?, for currentValue: Double) -> Date? {
        return originalTime?.addingTimeInterval(currentValue * 60)
    }
}


/// One iqama row on the Time Correction page: the prayer's own gap after the
/// adhan, in the same shape as `CorrectionRow` (name, reset, stepper, preview)
/// so both halves of the page read as one list. The preview is adhan → iqama —
/// exactly the time the countdown header will show for that prayer.
struct IqamaRow: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    let prayerName: String
    @Binding var value: Double

    /// Row default: the untouched baseline every prayer starts on until the
    /// user gives it its own gap.
    private var defaultValue: Double { Double(vm.iqamaDelayMinutes) }

    var body: some View {
        let isDefaultValue = value == defaultValue

        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(LocalizedStringKey(prayerName))
                    .scaledFont(.caption)

                Spacer()

                HStack(spacing: 6) {
                    Button(action: {
                        withAnimation(.spring()) { value = defaultValue }
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .disabled(isDefaultValue)

                    // Unsigned minutes: the iqama always follows the adhan.
                    SajdaStepper(value: $value, range: 0...60, showsSign: false)
                }
            }

            // Preview adhan → iqama, hidden while the row sits on the default —
            // same rule as the correction rows above.
            HStack {
                Spacer()
                if let adhan = adhanTime, let iqama = iqamaTime {
                    Text(vm.dateFormatter.string(from: adhan))
                        .strikethrough(color: .secondary)
                    Image(systemName: vm.forwardArrow)
                        .font(.system(size: 11, weight: .semibold))
                    Text(vm.dateFormatter.string(from: iqama))
                        .fontWeight(.semibold)
                        // Follows the selected highlight colour, like the rest
                        // of the panel's interactive accents.
                        .foregroundColor(vm.selectedHighlightColor)
                } else {
                    Text("00:00 → 00:00").hidden()
                }
            }
            .scaledFont(.caption2)
            .foregroundColor(.secondary)
            .opacity(isDefaultValue ? 0 : 1)
            .animation(.easeInOut(duration: 0.2), value: isDefaultValue)
        }
    }

    /// The corrected adhan the gap is counted from — Fajr follows the shared
    /// display date (after Isha that is tomorrow's Fajr), like `CorrectionRow`.
    private var adhanTime: Date? {
        prayerName == "Fajr" ? (vm.displayedFajrTime ?? vm.todayTimes[prayerName]) : vm.todayTimes[prayerName]
    }

    private var iqamaTime: Date? {
        adhanTime?.addingTimeInterval(value * 60)
    }
}


struct PrayerTimeCorrectionView: View {
    /// Top tabs of the Time Correction page: the adhan shift and the iqama
    /// estimate. Two short stacks instead of one long page — the same top tab
    /// bar idea as Settings, but text-only (a plain label, no icon).
    enum CorrectionTab: String, CaseIterable, Identifiable {
        case adhan
        case iqama

        var id: String { rawValue }

        /// Localized tab title.
        var titleKey: String {
            switch self {
            case .adhan: return "Adhan"
            case .iqama: return "Iqama"
            }
        }
    }

    @EnvironmentObject var vm: PrayerTimeViewModel
    @EnvironmentObject var navigationModel: NavigationModel
    
    @State private var fajrValue: Double = 0
    @State private var dhuhrValue: Double = 0
    @State private var asrValue: Double = 0
    @State private var maghribValue: Double = 0
    @State private var ishaValue: Double = 0

    // Iqama estimate per prayer (minutes after the adhan), seeded from
    // `iqamaDelay(for:)` so an untouched row starts on the default gap.
    @State private var fajrIqamaValue: Double = 0
    @State private var dhuhrIqamaValue: Double = 0
    @State private var asrIqamaValue: Double = 0
    @State private var maghribIqamaValue: Double = 0
    @State private var ishaIqamaValue: Double = 0
    
    @State private var updateSubject = PassthroughSubject<Void, Never>()
    @State private var cancellable: AnyCancellable?
    
    @State private var isHeaderHovering = false
    @State private var isResetAllHovering = false
    @State private var hoveringTab: CorrectionTab?

    /// Active tab. Kept in UserDefaults rather than `@State` because
    /// NavigationStack recreates the pushed page mid-pop — a fresh `@State`
    /// would snap the visible tab back to Adhan during the exit, the same
    /// flash SettingsView works around. The back button resets it once the
    /// exit has finished, so every open still starts on Adhan.
    @AppStorage("timeCorrectionTab") private var selectedTabRaw: String = CorrectionTab.adhan.rawValue
    private var selectedTab: CorrectionTab { CorrectionTab(rawValue: selectedTabRaw) ?? .adhan }

    private var viewWidth: CGFloat {
        return vm.panelWidth(base: vm.useCompactLayout ? 220 : 260)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            Button(action: {
                navigationModel.hideView(LocationAndCalcSettingsView.id, animation: vm.backwardAnimation())
                // Land on Adhan for the next open — the reset waits for the
                // exit transition to finish, otherwise the visible tab snaps
                // mid-fade (the flash SettingsView fixes). Delays mirror the
                // exit curves (0.25s fade, ~0.35s slide).
                let delay: Double
                switch vm.animationType {
                case .none: delay = 0
                case .fade: delay = 0.3
                case .slide: delay = 0.4
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    selectedTabRaw = CorrectionTab.adhan.rawValue
                }
            }) {
                HStack {
                    Image(systemName: vm.backChevron).scaledFont(.body, weight: .semibold)
                    Text("Time Correction").scaledFont(.body, weight: .semibold)
                    Spacer()
                }
                .padding(.vertical, 5).padding(.horizontal, 8)
                .liquidHover(isHeaderHovering)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 5).padding(.top, 2)
            .onHover { hovering in isHeaderHovering = hovering }
            
            Rectangle()
                .fill(Color("DividerColor"))
                .frame(height: 0.5)
                .padding(.horizontal, 12)

            // Tab bar: two text tabs (no icon, unlike Settings) — the adhan
            // shift and the iqama estimate, one stack of rows each so the page
            // stays a single screen.
            HStack(spacing: 2) {
                ForEach(CorrectionTab.allCases) { tab in
                    CorrectionTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        isHovering: hoveringTab == tab,
                        accent: vm.selectedHighlightColor,
                        highlightHex: vm.customHighlightColorHex,
                        useGlass: vm.useGlassPrayerHighlight,
                        onTap: { selectedTabRaw = tab.rawValue },
                        onHover: { hovering in hoveringTab = hovering ? tab : nil }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)

            // Active tab's rows inside a well sized by the taller of the two
            // tabs (the inactive body is laid out invisibly underneath it) —
            // the same trick as the Settings tab bar, so the panel height
            // never changes when the tabs swap.
            ZStack(alignment: .topLeading) {
                ForEach(CorrectionTab.allCases) { tab in
                    tabBody(tab)
                        .hidden()
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                Group { tabBody(selectedTab) }
                    .id(selectedTab)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .controlSize(.mini)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .frame(width: viewWidth)
        .onAppear(perform: setupValues)
        .onDisappear(perform: { cancellable?.cancel() })
        .onChange(of: fajrValue) { _ in updateSubject.send() }
        .onChange(of: dhuhrValue) { _ in updateSubject.send() }
        .onChange(of: asrValue) { _ in updateSubject.send() }
        .onChange(of: maghribValue) { _ in updateSubject.send() }
        .onChange(of: ishaValue) { _ in updateSubject.send() }
        .onChange(of: fajrIqamaValue) { _ in updateSubject.send() }
        .onChange(of: dhuhrIqamaValue) { _ in updateSubject.send() }
        .onChange(of: asrIqamaValue) { _ in updateSubject.send() }
        .onChange(of: maghribIqamaValue) { _ in updateSubject.send() }
        .onChange(of: ishaIqamaValue) { _ in updateSubject.send() }
    }
    
    private func hasCorrections() -> Bool {
        fajrValue != 0 || dhuhrValue != 0 || asrValue != 0 || maghribValue != 0 || ishaValue != 0
    }

    /// Any iqama row sitting away from the default gap — those are exactly
    /// the prayers carrying an override (see `setIqamaDelay`).
    private func hasIqamaChanges() -> Bool {
        let base = Double(vm.iqamaDelayMinutes)
        return fajrIqamaValue != base || dhuhrIqamaValue != base || asrIqamaValue != base
            || maghribIqamaValue != base || ishaIqamaValue != base
    }

    /// Rows for one tab plus that tab's own reset button. Driven by the
    /// requested `tab` rather than the selection, so the hidden copy in the
    /// height well always lays out exactly like its live twin.
    @ViewBuilder
    private func tabBody(_ tab: CorrectionTab) -> some View {
        VStack(spacing: 8) {
            if tab == .adhan {
                Text("Adjust prayer times to match your local mosque.")
                    .scaledFont(.caption2)
                    .foregroundColor(Color("SecondaryTextColor"))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 2)

                VStack(spacing: 8) {
                    // A mosque timetable publishes the mosque's own adhan
                    // times, so the adhan offsets have nothing to correct —
                    // `applyMawaqitDay` no longer shifts them. Dimmed for the
                    // same reason as the Iqama tab below, and for the same
                    // reason the stored values are kept rather than cleared:
                    // they come straight back with calculated times.
                    if vm.isMosqueTimetableActive {
                        Text(NSLocalizedString("mosque_adhan_in_use", comment: ""))
                            .scaledFont(.caption2)
                            .foregroundColor(Color("SecondaryTextColor"))
                            .padding(.bottom, 2)
                    }
                    CorrectionRow(prayerName: "Fajr", value: $fajrValue)
                    CorrectionRow(prayerName: "Dhuhr", value: $dhuhrValue)
                    CorrectionRow(prayerName: "Asr", value: $asrValue)
                    CorrectionRow(prayerName: "Maghrib", value: $maghribValue)
                    CorrectionRow(prayerName: "Isha", value: $ishaValue)
                }
                .allowsHitTesting(!vm.isMosqueTimetableActive)
                .disabled(vm.isMosqueTimetableActive)
                .opacity(vm.isMosqueTimetableActive ? 0.5 : 1)
            } else {
                VStack(alignment: .center, spacing: 1) {
                    // Reuses the existing translated "Iqama Delay" key.
                    Text("Iqama Delay")
                        .scaledFont(.caption, weight: .semibold)
                        .foregroundColor(Color("SecondaryTextColor"))
                    Text("Minutes after the adhan for each prayer.")
                        .scaledFont(.caption2)
                        .foregroundColor(Color("SecondaryTextColor"))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 4)
                .padding(.bottom, 2)

                // The mosque's published iqama wins for every prayer it
                // publishes one for (`effectiveIqamaDelay(for:)`), so these
                // rows are inert while a timetable is the active source. Dimmed
                // with a reason, matching the Jumu'ah sessions block in
                // Settings — the stored gaps come straight back when the
                // timetable is switched off.
                VStack(spacing: 8) {
                    if vm.isMosqueTimetableActive {
                        Text(NSLocalizedString("mosque_iqama_in_use", comment: ""))
                            .scaledFont(.caption2)
                            .foregroundColor(Color("SecondaryTextColor"))
                            .padding(.bottom, 2)
                    }
                    IqamaRow(prayerName: "Fajr", value: $fajrIqamaValue)
                    IqamaRow(prayerName: "Dhuhr", value: $dhuhrIqamaValue)
                    IqamaRow(prayerName: "Asr", value: $asrIqamaValue)
                    IqamaRow(prayerName: "Maghrib", value: $maghribIqamaValue)
                    IqamaRow(prayerName: "Isha", value: $ishaIqamaValue)
                }
                .allowsHitTesting(!vm.isMosqueTimetableActive)
                .disabled(vm.isMosqueTimetableActive)
                .opacity(vm.isMosqueTimetableActive ? 0.5 : 1)
            }

            if tabHasChanges(tab) {
                Rectangle()
                    .fill(Color("DividerColor"))
                    .frame(height: 0.5)
                    .padding(.vertical, 2)

                Button(action: { resetTab(tab) }) {
                    Text("Reset All to Default")
                        .scaledFont(.caption2)
                        .foregroundColor(Color("SecondaryTextColor"))
                        .padding(.vertical, 2).padding(.horizontal, 6)
                        .liquidHover(isResetAllHovering, cornerRadius: 4)
                }
                .buttonStyle(.plain)
                .onHover { hovering in isResetAllHovering = hovering }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: tabHasChanges(tab))
    }

    /// Whether a tab shows its reset button: any row on it away from its own
    /// default (adhan rows start at 0, iqama rows at the global gap).
    private func tabHasChanges(_ tab: CorrectionTab) -> Bool {
        tab == .adhan ? hasCorrections() : hasIqamaChanges()
    }

    /// Resets only the tab it is handed — each tab carries its own button.
    private func resetTab(_ tab: CorrectionTab) {
        withAnimation {
            if tab == .adhan {
                fajrValue = 0; dhuhrValue = 0; asrValue = 0; maghribValue = 0; ishaValue = 0
            } else {
                fajrIqamaValue = Double(vm.iqamaDelayMinutes)
                dhuhrIqamaValue = Double(vm.iqamaDelayMinutes)
                asrIqamaValue = Double(vm.iqamaDelayMinutes)
                maghribIqamaValue = Double(vm.iqamaDelayMinutes)
                ishaIqamaValue = Double(vm.iqamaDelayMinutes)
            }
        }
    }
    
    private func setupValues() {
        fajrValue = vm.fajrCorrection
        dhuhrValue = vm.dhuhrCorrection
        asrValue = vm.asrCorrection
        maghribValue = vm.maghribCorrection
        ishaValue = vm.ishaCorrection
        fajrIqamaValue = Double(vm.iqamaDelay(for: "Fajr"))
        dhuhrIqamaValue = Double(vm.iqamaDelay(for: "Dhuhr"))
        asrIqamaValue = Double(vm.iqamaDelay(for: "Asr"))
        maghribIqamaValue = Double(vm.iqamaDelay(for: "Maghrib"))
        ishaIqamaValue = Double(vm.iqamaDelay(for: "Isha"))
        setupDebouncer()
    }
    
    private func setupDebouncer() {
        cancellable = updateSubject
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [self] in
                vm.fajrCorrection = self.fajrValue
                vm.dhuhrCorrection = self.dhuhrValue
                vm.asrCorrection = self.asrValue
                vm.maghribCorrection = self.maghribValue
                vm.ishaCorrection = self.ishaValue
                vm.setIqamaDelay(Int(self.fajrIqamaValue), for: "Fajr")
                vm.setIqamaDelay(Int(self.dhuhrIqamaValue), for: "Dhuhr")
                vm.setIqamaDelay(Int(self.asrIqamaValue), for: "Asr")
                vm.setIqamaDelay(Int(self.maghribIqamaValue), for: "Maghrib")
                vm.setIqamaDelay(Int(self.ishaIqamaValue), for: "Isha")
            }
    }
    
}

/// Text-only top tab in the Time Correction tab bar: a single centred label.
///
/// Same selection treatment as `SettingsTabButton` — a solid pill in the
/// highlight colour, no underline, hover only while unselected — so the two
/// tab bars read as one system. This one stacks no icon above its label.
private struct CorrectionTabButton: View {
    let tab: PrayerTimeCorrectionView.CorrectionTab
    let isSelected: Bool
    let isHovering: Bool
    /// Selected-tab fill: the user's highlight colour, or the system accent when
    /// none is picked (`vm.selectedHighlightColor`).
    let accent: Color
    /// Raw picked colour, so the label tone can be chosen against the fill.
    let highlightHex: String
    /// Mirrors the "Glass Highlight" switch; layered over the accent fill when on.
    let useGlass: Bool
    let onTap: () -> Void
    let onHover: (Bool) -> Void

    var body: some View {
        Button(action: onTap) {
            Text(LocalizedStringKey(tab.titleKey))
                .scaledFont(.caption, weight: isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? onFillColor : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .accentPillBackground(
                    isSelected: isSelected,
                    fill: accent,
                    useGlass: useGlass
                )
                // Hover only while unselected: a hover tint under the selected
                // tab's fill would muddy the picked colour.
                .liquidHover(isHovering && !isSelected)
        }
        .buttonStyle(.plain)
        .onHover(perform: onHover)
        .help(Text(LocalizedStringKey(tab.titleKey)))
        .accessibilityLabel(Text(LocalizedStringKey(tab.titleKey)))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var onFillColor: Color {
        PrayerTimeViewModel.onFillColorForHighlight(highlightHex)
    }
}
