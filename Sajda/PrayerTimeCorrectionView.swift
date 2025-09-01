// MARK: - GANTI SELURUH FILE: PrayerTimeCorrectionView.swift (TANPA SCROLLVIEW)

import SwiftUI
import Combine
import NavigationStack

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
    @State private var hoveredPrayer: String? = nil

    private var viewWidth: CGFloat {
        return vm.useCompactLayout ? 220 : 260
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: {
                navigationModel.popContent(LocationAndCalcSettingsView.id)
            }) {
                HStack {
                    Image(systemName: "chevron.left").font(.body.weight(.semibold))
                    Text("Time Correction").font(.body).fontWeight(.bold)
                    Spacer()
                }
                .padding(.vertical, 5).padding(.horizontal, 8)
                .background(isHeaderHovering ? Color("HoverColor") : .clear).cornerRadius(5)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 5).padding(.top, 2)
            .onHover { hovering in isHeaderHovering = hovering }
            
            Rectangle()
                .fill(Color("DividerColor"))
                .frame(height: 0.5)
                .padding(.horizontal, 12)

            // ScrollView telah dihapus dari sini.
            VStack(spacing: 12) {
                Text("Adjust prayer times to match your local mosque. Hover over the number to reset.")
                    .font(.caption)
                    .foregroundColor(Color("SecondaryTextColor"))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 4)

                VStack(spacing: 12) {
                    ForEach(["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"], id: \.self) { prayerName in
                        correctionRow(for: prayerName)
                    }
                }
                
                if hasCorrections() {
                    Rectangle()
                        .fill(Color("DividerColor"))
                        .frame(height: 0.5)
                        .padding(.vertical, 4)
                    
                    Button(action: resetAll) {
                        Text("Reset All to Default")
                            .font(.caption)
                            .foregroundColor(Color("SecondaryTextColor"))
                            .padding(.vertical, 3).padding(.horizontal, 8)
                            .background(isResetAllHovering ? Color("HoverColor") : .clear)
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in isResetAllHovering = hovering }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .animation(.easeInOut(duration: 0.2), value: hasCorrections())
            .controlSize(.small)
            
            // Spacer ditambahkan untuk mendorong konten ke atas.
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .frame(width: viewWidth)
        .onAppear(perform: setupValues)
        .onDisappear(perform: { cancellable?.cancel() })
        .onChange(of: fajrValue) { _ in updateSubject.send() }
        .onChange(of: dhuhrValue) { _ in updateSubject.send() }
        .onChange(of: asrValue) { _ in updateSubject.send() }
        .onChange(of: maghribValue) { _ in updateSubject.send() }
        .onChange(of: ishaValue) { _ in updateSubject.send() }
    }
    
    @ViewBuilder
    private func correctionRow(for prayerName: String) -> some View {
        let binding = binding(for: prayerName)
        let originalTime = getOriginalTime(prayerName, for: binding.wrappedValue)
        let adjustedTime = getAdjustedTime(originalTime: originalTime, for: binding.wrappedValue)

        HStack {
            Text(LocalizedStringKey(prayerName)).font(.subheadline).frame(width: 50, alignment: .leading)
            Spacer()
            InteractiveStepper(value: binding, onHover: { isHovering in
                withAnimation(.easeInOut(duration: 0.1)) {
                    hoveredPrayer = isHovering ? prayerName : nil
                }
            })
        }
        .overlay(
            Group {
                if hoveredPrayer == prayerName, let original = originalTime, let adjusted = adjustedTime, binding.wrappedValue != 0 {
                    TimePreviewPopover(originalTime: original, adjustedTime: adjusted, formatter: vm.dateFormatter)
                        .offset(y: -42)
                }
            }
        )
    }

    private func binding(for prayerName: String) -> Binding<Double> {
        switch prayerName {
            case "Fajr": return $fajrValue
            case "Dhuhr": return $dhuhrValue
            case "Asr": return $asrValue
            case "Maghrib": return $maghribValue
            case "Isha": return $ishaValue
            default: return .constant(0)
        }
    }

    private func getOriginalTime(_ prayer: String, for currentValue: Double) -> Date? {
        guard let time = vm.todayTimes[prayer] else { return nil }
        return time.addingTimeInterval(-currentValue * 60)
    }
    
    private func getAdjustedTime(originalTime: Date?, for currentValue: Double) -> Date? {
        return originalTime?.addingTimeInterval(currentValue * 60)
    }

    private func hasCorrections() -> Bool {
        return fajrValue != 0 || dhuhrValue != 0 || asrValue != 0 || maghribValue != 0 || ishaValue != 0
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
        fajrValue = 0; dhuhrValue = 0; asrValue = 0; maghribValue = 0; ishaValue = 0
    }
}
