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
                    .font(.caption)
                
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
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                    Text(vm.dateFormatter.string(from: adjusted))
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                } else {
                    Text("00:00 → 00:00").hidden()
                }
            }
            .font(.caption2)
            .foregroundColor(.secondary)
            .opacity(isDefaultValue ? 0 : 1)
            .animation(.easeInOut(duration: 0.2), value: isDefaultValue)
        }
    }
    
    private func getOriginalTime(_ prayer: String, for currentValue: Double) -> Date? {
        guard let time = vm.todayTimes[prayer] else { return nil }
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
        return vm.useCompactLayout ? 200 : 240
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            Button(action: {
                navigationModel.hideView(LocationAndCalcSettingsView.id, animation: vm.backwardAnimation())
            }) {
                HStack {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Time Correction")
                        .font(.subheadline).fontWeight(.bold)
                    Spacer()
                }
                .padding(.vertical, 4).padding(.horizontal, 6)
                .background(isHeaderHovering ? Color("HoverColor") : .clear).cornerRadius(4)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 5).padding(.top, 2)
            .onHover { hovering in isHeaderHovering = hovering }
            
            Rectangle()
                .fill(Color("DividerColor"))
                .frame(height: 0.5)
                .padding(.horizontal, 12)

            VStack(spacing: 8) {
                Text("Adjust prayer times to match your local mosque.")
                    .font(.caption2)
                    .foregroundColor(Color("SecondaryTextColor"))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 2)

                VStack(spacing: 8) {
                    CorrectionRow(prayerName: "Fajr", value: $fajrValue)
                    CorrectionRow(prayerName: "Dhuhr", value: $dhuhrValue)
                    CorrectionRow(prayerName: "Asr", value: $asrValue)
                    CorrectionRow(prayerName: "Maghrib", value: $maghribValue)
                    CorrectionRow(prayerName: "Isha", value: $ishaValue)
                }
                
                if hasCorrections() {
                    Rectangle()
                        .fill(Color("DividerColor"))
                        .frame(height: 0.5)
                        .padding(.vertical, 2)
                    
                    Button(action: resetAll) {
                        Text("Reset All to Default")
                            .font(.caption2)
                            .foregroundColor(Color("SecondaryTextColor"))
                            .padding(.vertical, 2).padding(.horizontal, 6)
                            .background(isResetAllHovering ? Color("HoverColor") : .clear)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in isResetAllHovering = hovering }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .animation(.easeInOut(duration: 0.2), value: hasCorrections())
            .controlSize(.mini)
            
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
    }
    
    private func hasCorrections() -> Bool {
        fajrValue != 0 || dhuhrValue != 0 || asrValue != 0 || maghribValue != 0 || ishaValue != 0
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
    
    private func resetAll() {
        withAnimation {
            fajrValue = 0; dhuhrValue = 0; asrValue = 0; maghribValue = 0; ishaValue = 0
        }
    }
}
