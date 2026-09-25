// MARK: - GANTI SELURUH FILE: LocationAndCalcSettingsView.swift

import SwiftUI
import NavigationStack

struct LocationAndCalcSettingsView: View {
    static let id = "LocationAndCalcSettingsStack"

    @EnvironmentObject var vm: PrayerTimeViewModel
    @EnvironmentObject var navigationModel: NavigationModel
    
    @State private var isHeaderHovering = false

    @State private var mosqueQuery = ""
    @State private var mosqueResults: [MosqueSearchResult] = []
    @State private var isDownloadingMosque = false
    @State private var mosqueDownloadFailed = false
    @State private var mosqueSearchTask: Task<Void, Never>?

    private var viewWidth: CGFloat {
        return vm.panelWidth(base: vm.useCompactLayout ? 220 : 260)
    }

    /// Debounced keyword search (350 ms) against Mawaqit's public endpoint.
    @MainActor
    private func scheduleMosqueSearch(_ text: String) {
        mosqueSearchTask?.cancel()
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            mosqueResults = []
            return
        }
        mosqueSearchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            do {
                let hits = try await MawaqitService.searchMosques(matching: query)
                guard !Task.isCancelled else { return }
                mosqueResults = hits
            } catch {
                guard !Task.isCancelled else { return }
                mosqueResults = []
            }
        }
    }

    /// Downloads the mosque's yearly calendar, saves it offline, and switches
    /// the panel, menu bar, and notifications to it.
    @MainActor
    private func downloadMosque(_ result: MosqueSearchResult) {
        isDownloadingMosque = true
        mosqueDownloadFailed = false
        Task {
            do {
                let mosque = try await MawaqitService.fetchCalendar(slug: result.slug)
                guard !Task.isCancelled else { return }
                vm.activateMosqueSchedule(mosque)
                isDownloadingMosque = false
                mosqueQuery = ""
                mosqueResults = []
            } catch {
                guard !Task.isCancelled else { return }
                isDownloadingMosque = false
                mosqueDownloadFailed = true
            }
        }
    }

    /// Re-downloads the active mosque's calendar (schedule updates, new year).
    @MainActor
    private func refreshMosqueSchedule() {
        guard let slug = vm.mawaqitMosque?.slug else { return }
        downloadMosque(MosqueSearchResult(slug: slug, label: slug))
    }

    var body: some View {
        NavigationStackView(Self.id) {
            VStack(alignment: .leading, spacing: 6) {
                Button(action: {
                    navigationModel.hideView(SettingsView.id, animation: vm.backwardAnimation())
                }) {
                    HStack {
                        Image(systemName: vm.backChevron).scaledFont(.body, weight: .semibold)
                        Text("Calculation & Location").scaledFont(.body, weight: .bold)
                        Spacer()
                    }
                    .padding(.vertical, 5).padding(.horizontal, 8)
                    .liquidHover(isHeaderHovering)
                }.buttonStyle(.plain).padding(.horizontal, 5).padding(.top, 2).onHover { hovering in isHeaderHovering = hovering }
                
                Rectangle()
                    .fill(Color("DividerColor"))
                    .frame(height: 0.5)
                    .padding(.horizontal, 12)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Group {
                            Text("Mosque Timetable").scaledFont(.caption).foregroundColor(Color("SecondaryTextColor"))
                            if vm.useMawaqitSchedule, let mosque = vm.mawaqitMosque {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text(String(format: NSLocalizedString("mawaqit_ready", comment: ""), mosque.name))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    Spacer()
                                }
                                .scaledFont(.caption2)
                                HStack {
                                    Button("Refresh") { refreshMosqueSchedule() }.buttonStyle(.bordered)
                                    Spacer(minLength: 4)
                                    Button("Use Calculated Times Instead") { vm.disableMosqueSchedule() }.buttonStyle(.bordered)
                                }
                            }
                            TextField(NSLocalizedString("Search for a mosque...", comment: ""), text: $mosqueQuery)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: mosqueQuery) { newValue in scheduleMosqueSearch(newValue) }
                            if isDownloadingMosque {
                                HStack(spacing: 6) {
                                    ProgressView().controlSize(.mini)
                                    Text("Downloading...")
                                        .scaledFont(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            if mosqueDownloadFailed {
                                Text("Couldn't reach mawaqit.net.")
                                    .scaledFont(.caption2)
                                    .foregroundColor(.red)
                            }
                            ForEach(mosqueResults) { result in
                                Button { downloadMosque(result) } label: {
                                    HStack {
                                        Text(result.label)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                        Spacer()
                                        Image(systemName: "arrow.down.circle")
                                            .foregroundColor(.secondary)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .disabled(isDownloadingMosque)
                            }
                        }
                        Group {
                            Text("Calculation").scaledFont(.caption).foregroundColor(Color("SecondaryTextColor"))
                            HStack { Text("Method").scaledFont(.subheadline); Spacer(); ScaledMenuPicker(selection: $vm.method, options: SajdaCalculationMethod.allCases, maxWidth: 150) { $0.name } }
                            HStack { Text("Time Correction").scaledFont(.subheadline); Spacer(); Button("Adjust") { navigationModel.showView(Self.id, animation: vm.forwardAnimation()) { PrayerTimeCorrectionView() } }.buttonStyle(.bordered) }
                            StyledToggle(label: "Hanafi Madhhab (for Asr)", isOn: $vm.useHanafiMadhhab)
                            HStack { Text("High-Latitude Rule").scaledFont(.subheadline); Spacer(); ScaledMenuPicker(selection: $vm.highLatitudeRuleSetting, options: HighLatitudeRuleSetting.allCases, maxWidth: 150) { $0.displayName } }
                            if let caption = vm.highLatitudeRuleCaption {
                                Text(caption)
                                    .scaledFont(.caption2)
                                    .foregroundColor(Color("SecondaryTextColor"))
                            }
                            if let description = vm.highLatitudeRuleDescription {
                                Text(description)
                                    .scaledFont(.caption2)
                                    .foregroundColor(Color("SecondaryTextColor"))
                            }
                        }
                        Rectangle().fill(Color("DividerColor")).frame(height: 0.5)
                        Group {
                            Text("Location").scaledFont(.caption).foregroundColor(Color("SecondaryTextColor"))
                            HStack(spacing: 6) {
                                Image(systemName: vm.isUsingManualLocation ? "pencil.circle.fill" : "location.circle.fill")
                                    .foregroundColor(.secondary)

                                Text(vm.isUsingManualLocation ? "\(NSLocalizedString("Manual:", comment: "")) \(vm.locationStatusText)" : "\(NSLocalizedString("Automatic:", comment: "")) \(vm.locationStatusText)")
                                    .lineLimit(1)
                                    .truncationMode(.tail)

                                Spacer(minLength: 4)

                                if !vm.isUsingManualLocation {
                                    LocationRefreshButton(
                                        action: vm.refetchAutomaticLocation,
                                        isDisabled: vm.isRequestingLocation,
                                        isRefreshing: vm.isRequestingLocation
                                    )
                                }
                            }
                            HStack { Button("Change Manual Location") { navigationModel.showView(Self.id, animation: vm.forwardAnimation()) { ManualLocationView(isModal: false) } }.buttonStyle(.bordered); Spacer(); if vm.isUsingManualLocation { Button("Use Automatic") { vm.switchToAutomaticLocation() }.buttonStyle(.bordered) } }
                        }
                    }
                    .controlSize(.small)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .scrollIndicators(.hidden)
            }
            .padding(.vertical, 8)
            .frame(width: viewWidth)
        }
    }
}
