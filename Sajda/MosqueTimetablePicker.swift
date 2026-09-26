// MARK: - Sajda/MosqueTimetablePicker.swift
//
// Mosque-timetable (Mawaqit) search + activation, shared by Settings
// (Calculation & Location) and the welcome onboarding screen.

import SwiftUI

/// Searches mawaqit.net for a mosque, downloads its yearly calendar, and
/// activates it via `vm.activateMosqueSchedule(_:)`. Fully self-contained:
/// owns the query/results/download state so both call sites stay thin.
struct MosqueTimetablePicker: View {
    @EnvironmentObject var vm: PrayerTimeViewModel

    /// Settings shows the fallback iqama-gap stepper under the active
    /// mosque; onboarding hides it to keep the welcome screen compact.
    var showIqamaDelay = true

    @State private var mosqueQuery = ""
    @State private var mosqueResults: [MosqueSearchResult] = []
    @State private var isDownloadingMosque = false
    @State private var mosqueDownloadFailed = false
    @State private var mosqueSearchTask: Task<Void, Never>?
    @State private var hoveringResultSlug: String?
    @State private var hoveringStarSlug: String?

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
        VStack(alignment: .leading, spacing: 8) {
            if vm.useMawaqitSchedule, let mosque = vm.mawaqitMosque {
                // The timetable text itself carries the check (see
                // `mawaqit_ready`), so there is no separate icon.
                Text(String(format: NSLocalizedString("mawaqit_ready", comment: ""), mosque.name))
                    .scaledFont(.caption2)
                    .lineLimit(1)
                    .truncationMode(.tail)
                HStack {
                    Button("Refresh") { refreshMosqueSchedule() }.buttonStyle(.bordered)
                    Spacer(minLength: 4)
                    Button("Use Calculated Times Instead") { vm.disableMosqueSchedule() }.buttonStyle(.bordered)
                }
                if showIqamaDelay {
                    // Fallback iqama gap — used when the mosque
                    // doesn't publish iqama times. Default +8.
                    HStack {
                        Text("Iqama Delay").scaledFont(.subheadline)
                        Spacer()
                        SajdaStepper(value: Binding(get: { Double(vm.iqamaDelayMinutes) }, set: { vm.iqamaDelayMinutes = Int($0) }), range: 0...60)
                    }
                }
            }
            // Chrome is drawn by the app (see `SajdaSearchField`):
            // the native rounded bezel is what used to blink
            // black during page transitions in this panel.
            SajdaSearchField(placeholder: "Search for a mosque...", text: $mosqueQuery)
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
                // Same lock-style treatment as the city results: the download
                // row's hover spans the full line (under the star); the star
                // sits on top with its own pill. While the star is hovered
                // the row pill is suppressed.
                ZStack(alignment: .trailing) {
                    Button { downloadMosque(result) } label: {
                        HStack {
                            Text(result.label)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer()
                            Image(systemName: "arrow.down.circle")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4).padding(.horizontal, 6)
                        // Reserve room for the overlaid star so the label and
                        // download arrow never slide underneath it.
                        .padding(.trailing, 30)
                        .contentShape(Rectangle())
                        .liquidHover(hoveringResultSlug == result.slug && hoveringStarSlug == nil)
                    }
                    .buttonStyle(.plain)
                    .disabled(isDownloadingMosque)
                    .onHover { isHovering in hoveringResultSlug = isHovering ? result.slug : nil }
                    // Star toggles the favorite without downloading: starring
                    // prefetches the calendar in the background so tapping it
                    // (here or on the main screen) switches instantly.
                    Button { vm.toggleMosqueFavorite(slug: result.slug, label: result.label) } label: {
                        Image(systemName: vm.isMosqueFavorite(slug: result.slug) ? "star.fill" : "star")
                            .foregroundColor(vm.isMosqueFavorite(slug: result.slug) ? vm.selectedHighlightColor : .secondary)
                            .padding(.vertical, 4).padding(.horizontal, 6)
                            .contentShape(Rectangle())
                            .liquidHover(hoveringStarSlug == result.slug)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .disabled(isDownloadingMosque)
                    .onHover { isHovering in hoveringStarSlug = isHovering ? result.slug : nil }
                    .help(Text(NSLocalizedString(vm.isMosqueFavorite(slug: result.slug) ? "Remove from Favorites" : "Add to Favorites", comment: "")))
                }
            }
        }
    }
}
