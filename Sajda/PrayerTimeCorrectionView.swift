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

struct PrayerTimeCorrectionView: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    @EnvironmentObject var navigationModel: NavigationModel
    
    @State private var fajrValue: Double = 0
    @State private var dhuhrValue: Double = 0
    @State private var asrValue: Double = 0
    @State private var maghribValue: Double = 0
    @State private var ishaValue: Double = 0

    @State private var updateSubject = PassthroughSubject<Void, Never>()
    @State private var cancellable: AnyCancellable?
    
    @State private var isHeaderHovering = false
    @State private var isResetAllHovering = false

    private var viewWidth: CGFloat {
        return vm.panelWidth(base: vm.useCompactLayout ? 220 : 260)
    }

    /// Side inset for the whole page, matching the prayer rows' own inset in
    /// `PrayerListView` so pushing into this page from the panel below lines up
    /// with the panel's own content.
    private static let contentInset: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            Button(action: {
                navigationModel.hideView(LocationAndCalcSettingsView.id, animation: vm.backwardAnimation())
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
            .padding(.top, 2)
            .onHover { hovering in isHeaderHovering = hovering }
            
            Rectangle()
                .fill(Color("DividerColor"))
                .frame(height: 0.5)

            Text("Adjust prayer times to match your local mosque.")
                .scaledFont(.caption2)
                .foregroundColor(Color("SecondaryTextColor"))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            // A mosque timetable publishes the mosque's own adhan times, so
            // the adhan offsets have nothing to correct — `applyMawaqitDay`
            // no longer shifts them. The stored values are kept rather than
            // cleared, for the same reason: they come straight back if the
            // timetable is switched off.
            if vm.isMosqueTimetableActive {
                Text(NSLocalizedString("mosque_adhan_in_use", comment: ""))
                    .scaledFont(.caption2)
                    .foregroundColor(Color("SecondaryTextColor"))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            VStack(spacing: 8) {
                CorrectionRow(prayerName: "Fajr", value: $fajrValue)
                CorrectionRow(prayerName: "Dhuhr", value: $dhuhrValue)
                CorrectionRow(prayerName: "Asr", value: $asrValue)
                CorrectionRow(prayerName: "Maghrib", value: $maghribValue)
                CorrectionRow(prayerName: "Isha", value: $ishaValue)
            }
            .allowsHitTesting(!vm.isMosqueTimetableActive)
            .disabled(vm.isMosqueTimetableActive)
            .opacity(vm.isMosqueTimetableActive ? 0.5 : 1)

            if hasCorrections() {
                Rectangle()
                    .fill(Color("DividerColor"))
                    .frame(height: 0.5)
                    .padding(.vertical, 2)

                Button(action: { withAnimation { resetCorrections() } }) {
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

            Spacer(minLength: 0)
        }
        // One inset for the whole page, so the header, the rule, the hint, the
        // rows and the reset button all start and end on the same line. The
        // per-row padding that used to do this lived on the tab-well wrapper
        // that went away with the tabs; putting it on the `VStack` instead means
        // it survives a future change to the page's contents.
        .padding(.horizontal, Self.contentInset)
        .padding(.vertical, 6)
        .frame(width: viewWidth)
        .onAppear(perform: setupValues)
        .onDisappear(perform: { cancellable?.cancel() })
        .onChange(of: fajrValue) { _ in updateSubject.send() }
        .onChange(of: dhuhrValue) { _ in updateSubject.send() }
        .onChange(of: asrValue) { _ in updateSubject.send() }
        .onChange(of: maghribValue) { _ in updateSubject.send() }
        .onChange(of: ishaValue) { _ in updateSubject.send() }
    }
    
    private func hasCorrections() -> Bool {
        fajrValue != 0 || dhuhrValue != 0 || asrValue != 0 || maghribValue != 0 || ishaValue != 0
    }

    /// Zeroes every adhan row — one page, one reset.
    private func resetCorrections() {
        fajrValue = 0; dhuhrValue = 0; asrValue = 0; maghribValue = 0; ishaValue = 0
    }

    private func setupValues() {
        fajrValue = vm.fajrCorrection
        dhuhrValue = vm.dhuhrCorrection
        asrValue = vm.asrCorrection
        maghribValue = vm.maghribCorrection
        ishaValue = vm.ishaCorrection
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
            }
    }
    
}
