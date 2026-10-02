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
    @Environment(\.locale) private var locale
    @State private var hoveringResultSlug: String?
    @State private var hoveringHeartSlug: String?
    /// Zero-based index of the visible slice of `mosqueResults`. Paging
    /// replaces scrolling: the panel sizes itself to its content, so a
    /// `ScrollView` in the results is offered an unbounded height and blows
    /// the panel up (see the results list below). A page keeps the height
    /// fixed no matter how many hits came back.
    @State private var resultsPage = 0
    @State private var isPagingBack = false
    @State private var isPagingForward = false
    /// The query the currently held `mosqueResults` belong to. Mawaqit's search
    /// endpoint serves a fixed 10 hits on one page and reports no total, so
    /// this is deliberately a single request: walking server pages looked like
    /// an endless list, because the endpoint happily answers page after page
    /// of loosely-related mosques and never signals where relevance ends.
    /// The count line below the list is what tells the user the search is wide.
    @State private var loadedQuery = ""

    /// Debounced keyword search (350 ms) against Mawaqit's public endpoint.
    @MainActor
    private func scheduleMosqueSearch(_ text: String) {
        mosqueSearchTask?.cancel()
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Every keystroke re-searches, so every keystroke returns to page 0 —
        // otherwise a narrowed query could leave you stranded on an empty
        // page with no way to see the top hits.
        resultsPage = 0
        loadedQuery = query
        guard query.count >= 2 else {
            mosqueResults = []
            return
        }
        mosqueSearchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            do {
                let hits = try await MawaqitService.searchMosques(matching: query)
                // Drop the response if the user kept typing while it was in
                // flight — otherwise a slow "gran" would land on top of the
                // "grande" results that were requested after it.
                guard !Task.isCancelled, query == loadedQuery else { return }
                mosqueResults = hits
            } catch {
                guard !Task.isCancelled, query == loadedQuery else { return }
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
                resultsPage = 0
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
        downloadMosque(MosqueSearchResult(slug: slug, label: slug, name: slug, locality: ""))
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
            SajdaSearchField(placeholder: "Search for a mosque...", text: $mosqueQuery, accent: vm.selectedHighlightColor)
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
            // Paged, and deliberately NOT a ScrollView. The panel is a
            // fixed-size hosting view that resizes itself to its content's
            // ideal size, and a ScrollView inside it is offered an unbounded
            // height: the panel balloons, the rows are spread down a
            // window-height column, and the hits themselves are laid out past
            // the bottom of the window where nothing can be seen or clicked.
            // A fixed page of rows keeps the panel exactly as tall as one page
            // however many hits came back, and the pager below walks the rest.
            ForEach(pageResults) { result in
                mosqueResultRow(result)
            }
            // One line saying how wide the search is. The endpoint hands back
            // 10 hits on its single page and no total, so this is the only
            // signal that the box is being asked something broad — the honest
            // fix for a list that can't show everything.
            if mosqueResults.count > Self.resultsLimit {
                // Deliberately short, fixed, and identical on every page. An
                // earlier version counted the rows on screen ("Showing 1 of
                // 10" on the last page, "3 of 10" on a full one), which
                // changed as you paged and read as results going missing. The
                // one thing worth saying is the real constraint: the endpoint
                // returns at most 10 hits for a word and reports no total, so
                // this is the top of the list, not all of it.
                Text(NSLocalizedString("Top 10 matches — refine to narrow down.", comment: ""))
                    .scaledFont(.caption2)
                    .foregroundColor(Color("SecondaryTextColor"))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if pageCount > 1 {
                resultsPager
            }
        }
    }

    /// Hits shown on one page. Five keeps the panel a comfortable height on a
    /// broad search while still paging Mawaqit's single 10-hit page into two
    /// even pages. (Three was tried and made the chevrons tedious.) Names and
    /// addresses wrap onto as many lines as they need (see `mosqueResultRow`),
    /// so a row can still be two or three lines tall.
    private static let resultsLimit = 5

    /// Pages the hits occupy. Fixed by the one request above, so this is just
    /// arithmetic — no server walk, no "is there more" guessing.
    private var pageCount: Int {
        max(1, (mosqueResults.count + Self.resultsLimit - 1) / Self.resultsLimit)
    }

    /// The clamped current page, used by both the visible slice and the
    /// readout so they can never disagree.
    private var currentPage: Int {
        min(max(resultsPage, 0), pageCount - 1)
    }

    /// The slice of hits visible on the current page.
    private var pageResults: [MosqueSearchResult] {
        guard !mosqueResults.isEmpty else { return [] }
        let start = currentPage * Self.resultsLimit
        return Array(mosqueResults[start..<min(start + Self.resultsLimit, mosqueResults.count)])
    }

    /// "Page 1 of 2" readout between the two chevrons. Page-based rather than
    /// item-based ("1–5 of 10") on purpose: with a fixed five rows per page, an
    /// item range reads as a result total the user has to mentally divide, and
    /// the count line underneath already carries the total.
    private var pageIndicatorText: String {
        // Locale's own digits ("1" / "١"): `String(format:)` without a locale
        // always prints ASCII.
        String(
            format: NSLocalizedString("Page %d of %d", comment: ""),
            locale: locale,
            currentPage + 1, pageCount
        )
    }

    /// Previous/next chevrons flanking the position readout. Both buttons keep
    /// a fixed 22pt slot and stay enabled at the ends (just dimmed) so the
    /// row never changes width as the user pages, which would make the panel
    /// resize under the pointer.
    private var resultsPager: some View {
        HStack(spacing: 4) {
            pagerButton(forward: false)
            Spacer(minLength: 0)
            Text(pageIndicatorText)
                .scaledFont(.caption2)
                .foregroundColor(Color("SecondaryTextColor"))
                .monospacedDigit()
                .lineLimit(1)
            Spacer(minLength: 0)
            pagerButton(forward: true)
        }
        .padding(.top, 2)
    }

    private func pagerButton(forward: Bool) -> some View {
        // Page boundaries are the only thing that dims a chevron — the button
        // itself stays live, so a click at either end is a deliberate no-op
        // rather than a dead hit area.
        let isAtEdge = forward ? currentPage >= pageCount - 1 : currentPage <= 0
        let isHovering = forward ? isPagingForward : isPagingBack
        return Button {
            guard !isAtEdge else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                resultsPage = forward ? currentPage + 1 : currentPage - 1
            }
        } label: {
            Image(systemName: forward ? "chevron.right" : "chevron.left")
                .scaledFont(.caption, weight: .semibold)
                // Active chevron uses the contrast-safe accent: a pale custom
                // pick vanishes as a thin glyph on the panel while staying
                // clickable (#24). Disabled ends stay dimmed secondary, with
                // a minimum alpha so the "left arrow on page 1" affordance
                // never fully disappears either.
                .foregroundColor(isAtEdge ? Color("SecondaryTextColor").opacity(0.6) : vm.legibleInteractiveAccent)
                // Full-height hit area: the glyph is a fraction of the row, so
                // without this only the little chevron itself is clickable.
                .frame(width: 22, height: 18)
                .contentShape(Rectangle())
                .liquidHover(isHovering && !isAtEdge)
        }
        .buttonStyle(.plain)
        // Separate hover branches rather than a ternary assignment: the
        // compiler can't type-check `(Void, Void)` tuples here.
        .onHover { hovering in
            if forward {
                isPagingForward = hovering
            } else {
                isPagingBack = hovering
            }
        }
        .help(Text(NSLocalizedString(forward ? "Next results" : "Previous results", comment: "")))
    }

    private func mosqueResultRow(_ result: MosqueSearchResult) -> some View {
        // Same lock-style treatment as the city results: the download row's
        // hover spans the full line (under the heart); the heart sits on top
        // with its own pill. While the heart is hovered the row pill is
        // suppressed, so only the heart highlights. No refresh button here
        // either — see the location row for why an overlaid control needs a
        // greedy `Color.clear` spacer to hold its slot.
        ZStack(alignment: .trailing) {
            Button { downloadMosque(result) } label: {
                // Centred, not `.firstTextBaseline`: labels wrap to two lines,
                // and a baseline-aligned arrow sat on the first line while the
                // overlaid heart stayed centred, so the two trailing glyphs
                // were at different heights on every wrapped row.
                HStack(alignment: .center, spacing: 6) {
                    // Name and locality as two independently-wrapped blocks.
                    // Fused into the single `label` string they shared one
                    // font size and one 2-line budget, so a long name ate both
                    // lines and the address ended in "…47300…" — the mosque's
                    // name is what tells two nearby mosques apart, so it must
                    // never be the part that gets cut.
                    VStack(alignment: .leading, spacing: 1) {
                        Text(result.name)
                            // Unbounded lines: the panel sizes itself to its
                            // content, so a taller row is fine, whereas a
                            // clipped name is not.
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        if !result.locality.isEmpty {
                            Text(result.locality)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .foregroundColor(Color("SecondaryTextColor"))
                        }
                    }
                    .multilineTextAlignment(.leading)
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
            // Full text on hover, always. Wrapping fixes the panel width, but a
            // genuinely enormous name can still out-run it, and this is the
            // last resort that guarantees the full address is readable.
            .help(Text(result.label))
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