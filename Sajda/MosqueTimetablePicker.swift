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

    @State private var mosqueQuery = ""
    @State private var mosqueResults: [MosqueSearchResult] = []
    @State private var isDownloadingMosque = false
    @State private var mosqueDownloadFailed = false
    @State private var mosqueSearchTask: Task<Void, Never>?
    @State private var hoveringResultSlug: String?
    @State private var hoveringHeartSlug: String?

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
            // The results live in their own capped ScrollView: without one the
            // list grew the panel until the last hits fell off the bottom of
            // the window and the long labels (Villeneuve-la-Garenne & co.)
            // could never be read in full.
            if !mosqueResults.isEmpty {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(mosqueResults) { result in
                            mosqueResultRow(result)
                        }
                    }
                }
                // Tall enough for ~4 rows, short enough to stay a search
                // dropdown rather than take over the page.
                .frame(maxHeight: Self.resultsMaxHeight)
            }
        }
    }

    /// Cap on the results dropdown's height, in points.
    private static let resultsMaxHeight: CGFloat = 132

    private func mosqueResultRow(_ result: MosqueSearchResult) -> some View {
        // Same lock-style treatment as the city results: the download row's
        // hover spans the full line (under the heart); the heart sits on top
        // with its own pill. While the heart is hovered the row pill is
        // suppressed, so only the heart highlights. No refresh button here
        // either — see the location row for why an overlaid control needs a
        // greedy `Color.clear` spacer to hold its slot.
        ZStack(alignment: .trailing) {
            Button { downloadMosque(result) } label: {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(result.label)
                        // Two lines instead of one: a name plus its locality
                        // regularly runs past the panel width, and truncating
                        // mid-address ("Villeneuve-la-Gare…") makes two
                        // similarly named mosques impossible to tell apart.
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4).padding(.horizontal, 6)
                // Reserve room for the overlaid heart so the label and the
                // download arrow never slide underneath it.
                .padding(.trailing, 30)
                .contentShape(Rectangle())
                .liquidHover(hoveringResultSlug == result.slug && hoveringHeartSlug == nil)
            }
            .buttonStyle(.plain)
            .disabled(isDownloadingMosque)
            .onHover { isHovering in hoveringResultSlug = isHovering ? result.slug : nil }
            // Heart toggles the favorite without downloading: favouriting
            // prefetches the calendar in the background so tapping it (here
            // or on the main screen) switches instantly.
            Button { vm.toggleMosqueFavorite(slug: result.slug, label: result.label) } label: {
                Image(systemName: vm.isMosqueFavorite(slug: result.slug) ? "heart.fill" : "heart")
                    .foregroundColor(vm.isMosqueFavorite(slug: result.slug) ? vm.favoriteColor : .secondary)
                    .padding(.vertical, 4).padding(.horizontal, 6)
                    .contentShape(Rectangle())
                    .liquidHover(hoveringHeartSlug == result.slug)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .disabled(isDownloadingMosque)
            .onHover { isHovering in hoveringHeartSlug = isHovering ? result.slug : nil }
            .help(Text(NSLocalizedString(vm.isMosqueFavorite(slug: result.slug) ? "Remove from Favorites" : "Add to Favorites", comment: "")))
        }
    }
}