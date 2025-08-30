// MARK: - GANTI FILE: Sajda/PrayerTimeCorrectionView.swift
// Salin dan tempel SELURUH kode ini ke dalam file PrayerTimeCorrectionView.swift

import SwiftUI
import Combine

struct PrayerTimeCorrectionView: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    @Binding var activePage: ActivePage
    
    @State private var isLoading = true
    @State private var contentOpacity: Double = 0.0
    @State private var contentOffsetY: CGFloat = 10.0
    
    @State private var fajrValue: Double = 0
    @State private var dhuhrValue: Double = 0
    @State private var asrValue: Double = 0
    @State private var maghribValue: Double = 0
    @State private var ishaValue: Double = 0
    
    @State private var updateSubject = PassthroughSubject<Void, Never>()
    @State private var cancellable: AnyCancellable?
    
    @State private var isHeaderHovering = false
    // --- PERBAIKAN: State untuk hover pada tombol Reset All ---
    @State private var isResetAllHovering = false

    private var viewWidth: CGFloat {
        return vm.useCompactLayout ? 210 : 250
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: { activePage = .settings }) {
                HStack {
                    Image(systemName: "chevron.left").font(.body.weight(.semibold))
                    Text("Time Correction").font(.body).fontWeight(.bold)
                    Spacer()
                }
                .padding(.vertical, 5).padding(.horizontal, 8)
                .background(Color.secondary.opacity(isHeaderHovering ? 0.25 : 0)).cornerRadius(5)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 5).padding(.top, 2)
            .onHover { hovering in isHeaderHovering = hovering }
            
            Divider().padding(.horizontal, 12)

            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                    Text("Loading Adjustments...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 280)
                .transition(.opacity)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        VStack(spacing: 5) {
                            Text("Click +/- to adjust, or click and hold.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Hover over the number to reset.")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 8)

                        VStack(spacing: 12) {
                            CorrectionRow(prayerName: "Fajr", value: $fajrValue)
                            CorrectionRow(prayerName: "Dhuhr", value: $dhuhrValue)
                            CorrectionRow(prayerName: "Asr", value: $asrValue)
                            CorrectionRow(prayerName: "Maghrib", value: $maghribValue)
                            CorrectionRow(prayerName: "Isha", value: $ishaValue)
                        }
                        
                        // --- PERBAIKAN: Tombol Reset All sekarang memiliki efek hover ---
                        if fajrValue != 0 || dhuhrValue != 0 || asrValue != 0 || maghribValue != 0 || ishaValue != 0 {
                            Divider().padding(.vertical, 4)
                            
                            Button(action: {
                                fajrValue = 0
                                dhuhrValue = 0
                                asrValue = 0
                                maghribValue = 0
                                ishaValue = 0
                            }) {
                                Text("Reset All to Default")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 3)
                                    .padding(.horizontal, 8)
                                    .background(Color.secondary.opacity(isResetAllHovering ? 0.25 : 0))
                                    .cornerRadius(5)
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in isResetAllHovering = hovering }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .animation(.easeInOut(duration: 0.2), value: fajrValue != 0 || dhuhrValue != 0 || asrValue != 0 || maghribValue != 0 || ishaValue != 0)
                }
                .scrollIndicators(.hidden)
                .controlSize(.small)
                .opacity(contentOpacity)
                .offset(y: contentOffsetY)
            }
        }
        .padding(.vertical, 8)
        .frame(minWidth: viewWidth)
        .animation(.default, value: isLoading)
        .task {
            setupInitialValues()
            do {
                try await Task.sleep(nanoseconds: 50_000_000)
            } catch {
                print("Loading task cancelled.")
                return
            }
            isLoading = false
            setupDebouncer()
            
            withAnimation(.easeInOut(duration: 0.4)) {
                contentOpacity = 1.0
                contentOffsetY = 0.0
            }
        }
        .onChange(of: fajrValue) { _ in updateSubject.send() }
        .onChange(of: dhuhrValue) { _ in updateSubject.send() }
        .onChange(of: asrValue) { _ in updateSubject.send() }
        .onChange(of: maghribValue) { _ in updateSubject.send() }
        .onChange(of: ishaValue) { _ in updateSubject.send() }
    }
    
    private func setupInitialValues() {
        fajrValue = vm.fajrCorrection
        dhuhrValue = vm.dhuhrCorrection
        asrValue = vm.asrCorrection
        maghribValue = vm.maghribCorrection
        ishaValue = vm.ishaCorrection
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

struct CorrectionRow: View {
    let prayerName: String
    @Binding var value: Double

    var body: some View {
        HStack {
            Text(prayerName)
            Spacer()
            InteractiveStepper(value: $value)
        }
    }
}
