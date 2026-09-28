// MARK: - Sajda/FavoritesSection.swift
//
// Favorites rows for the Location page: up to 5 saved cities + mosque
// timetables, then the two search rows. Tapping a favorite switches straight
// to it; the "Automatic" row switches back to system location via
// `switchToAutomaticLocation`.
//
// The search rows are accordions: tapping one reveals its search UI inline —
// a city field with its results, or the mosque timetable picker — instead of
// popping this page and pushing the search page. That pop-then-push was what
// flickered (both pages blended mid-transition while the panel resized and the
// search field re-resolved its chrome), so nothing here navigates any more.
// `openSearch` starts `nil` every time the page is (re)created, so the
// accordions always open shut.

import SwiftUI

struct FavoritesSection: View {
    @EnvironmentObject var vm: PrayerTimeViewModel

    /// Bumped by the owner whenever this section should forget its own state.
    ///
    /// This section used to live inside an `if` that unmounted it on collapse,
    /// which reset `openSearch` for free. It no longer does: `MainView` keeps
    /// it permanently in the tree and collapses it by animating its height,
    /// because an unmount/mount transition stranded a ghost copy of the rows
    /// over the prayer list while the panel resized. So the reset the unmount
    /// used to provide is driven from outside through this counter —
    /// otherwise reopening the accordion would restore whatever search the user
    /// had open last time.
    ///
    /// A counter rather than a plain `Bool` on purpose: the owner folds the
    /// searches at the *start* of a collapse, and a second collapse with no
    /// reopen in between must fold them again, which a `Bool` edge (only
    /// meaningful on change) would swallow.
    let collapseToken: Int

    /// Which inline search is open; `nil` = both shut. Single-open like the
    /// Settings accordions, so opening one closes the other.
    private enum OpenSearch: Equatable {
        case city
        case mosque
    }

    @State private var openSearch: OpenSearch?
    @State private var hoveringFavoriteID: String?
    @State private var isAutomaticHovering = false
    @State private var isCityHovering = false
    @State private var isMosqueHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            automaticRow
            if !vm.favoritePlaces.isEmpty {
                ForEach(vm.favoritePlaces) { favorite in
                    favoriteRow(favorite)
                }
                // Divider between saved favorites and the two search rows
                // below them.
                Rectangle()
                    .fill(Color("DividerColor"))
                    .frame(height: 0.5)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
            }
            // The search rows show in both states: with no favorites yet they
            // are the only way to start starring; with favorites they sit
            // under the divider.
            citySearchRow
            if openSearch == .city { citySearchContent }
            mosqueSearchRow
            if openSearch == .mosque { mosqueSearchContent }
        }
        .padding(.vertical, 2)
        .clipped()
        .onChange(of: collapseToken) { _, _ in
            // Mirrors the unmount this view no longer gets: fold the inline
            // searches and forget the pending query, so a reopen always
            // starts from a plain collapsed list. Animated on the same curve
            // as the height collapse that runs alongside it, otherwise the
            // searches would snap shut while the section is still sliding
            // closed. `fixedSize` inside `AccordionReveal` means the section
            // still reports its full natural height while this plays, so the
            // panel finishes the collapse with this one still in the tree.
            withAnimation(.sajdaAccordion) {
                openSearch = nil
            }
            if !vm.locationSearchQuery.isEmpty {
                vm.locationSearchQuery = ""
            }
        }
    }

    // MARK: - Inline searches

    /// Single-open toggle, animated on the accordion curve so the panel (and
    /// the menu window behind it) resizes in lockstep with the reveal — the
    /// same curve the Settings sections use.
    private func toggleSearch(_ target: OpenSearch) {
        withAnimation(.sajdaAccordion) {
            openSearch = (openSearch == target) ? nil : target
        }
        // Closing the city search forgets its query, exactly like leaving the
        // dedicated search page used to (its `onDisappear` reset).
        if openSearch != .city, !vm.locationSearchQuery.isEmpty {
            vm.locationSearchQuery = ""
        }
    }

    /// Inline city search: the same field + results the Set Location page
    /// shows, rendered under its row. Picking a result applies the
    /// coordinates and folds the accordion back up (the page flow popped the
    /// search page instead).
    private var citySearchContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Chrome drawn by the app (see `SajdaSearchField`) instead of the
            // native rounded bezel, which could blink black mid-transition.
            SajdaSearchField(placeholder: "Search for a city or paste coordinates...", text: $vm.locationSearchQuery, accent: vm.selectedHighlightColor)

            if vm.isLocationSearching {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            } else {
                LocationSearchResultsList { result in
                    vm.setManualLocation(city: result.name, coordinates: result.coordinates)
                    withAnimation(.sajdaAccordion) { openSearch = nil }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        // Fade in place, clipped, so the rows never travel outside the
        // section — a vertical slide here would fly the results up over the
        // favorite rows above, the same artifact the location accordion has
        // to avoid (see `locationFavoritesBlock`).
        .transition(.opacity)
        .clipped()
    }

    /// Inline mosque search: the same self-contained picker Settings embeds —
    /// it owns its query, results and download state, so nothing here has to.
    private var mosqueSearchContent: some View {
        MosqueTimetablePicker()
            .environmentObject(vm)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .transition(.opacity)
            .clipped()
    }

    /// One-tap return to system location (also exits timetable mode —
    /// same safe ordering as the Settings button, so the flip can't crash).
    /// The Button's label owns the row padding + trailing slot so the hit
    /// area is exactly the hover pill (no dead strips at the pill's edges).
    private var automaticRow: some View {
        let isActive = !vm.isUsingManualLocation && !vm.useMawaqitSchedule
        return Button(action: { vm.switchToAutomaticLocation() }) {
            HStack(spacing: 6) {
                Image(systemName: "location.circle.fill")
                    .scaledFont(.caption)
                    .foregroundColor(isActive ? vm.selectedHighlightColor : .secondary)
                    .frame(width: 16)
                Text(NSLocalizedString("Use Automatic Location", comment: ""))
                    .scaledFont(.subheadline, weight: isActive ? .semibold : .regular)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                // Fixed trailing slot: the checkmark sits at the exact x the
                // stars use on the rows below. Inside the label, so it is
                // clickable like the rest of the pill.
                if isActive {
                    Image(systemName: "checkmark")
                        .scaledFont(.caption, weight: .semibold)
                        .foregroundColor(vm.selectedHighlightColor)
                        .frame(width: 20)
                } else {
                    Color.clear.frame(width: 20)
                }
            }
            .padding(.vertical, 5).padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .liquidHover(isAutomaticHovering)
        .onHover { hovering in
            isAutomaticHovering = hovering
        }
    }

    /// City search accordion header: same row metrics + chevron as the
    /// favorite rows so hover pills and trailing symbols line up exactly.
    /// Expanded it points up (the `SettingsAccordion` convention).
    private var citySearchRow: some View {
        Button(action: { toggleSearch(.city) }) {
            HStack(spacing: 6) {
                Image(systemName: "mappin.circle")
                    .scaledFont(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 16)
                Text(NSLocalizedString("Search for a city…", comment: ""))
                    .scaledFont(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                Image(systemName: openSearch == .city ? "chevron.up" : vm.forwardChevron)
                    .scaledFont(.caption, weight: .semibold)
                    .foregroundColor(.secondary)
                    .frame(width: 20)
            }
            // Padding inside the label: the button covers the whole hover pill.
            .padding(.vertical, 5).padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .liquidHover(isCityHovering)
        .onHover { hovering in isCityHovering = hovering }
    }

    /// Mosque search accordion header, same shape as `citySearchRow` — its
    /// expanded content is the picker Settings uses.
    private var mosqueSearchRow: some View {
        Button(action: { toggleSearch(.mosque) }) {
            HStack(spacing: 6) {
                Image(systemName: "building.columns")
                    .scaledFont(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 16)
                Text(NSLocalizedString("Search for a mosque…", comment: ""))
                    .scaledFont(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                Image(systemName: openSearch == .mosque ? "chevron.up" : vm.forwardChevron)
                    .scaledFont(.caption, weight: .semibold)
                    .foregroundColor(.secondary)
                    .frame(width: 20)
            }
            // Padding inside the label: the button covers the whole hover pill.
            .padding(.vertical, 5).padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .liquidHover(isMosqueHovering)
        .onHover { hovering in isMosqueHovering = hovering }
    }

    private func favoriteRow(_ favorite: FavoritePlace) -> some View {
        let isActive = vm.isFavoriteActive(favorite)
        let isLoading = vm.favoriteMosqueLoadingSlug == favorite.slug && favorite.kind == .mosque
        // The row Button's label owns the padding + full-width content
        // (including a reserved 20pt slot for the heart), so the hit area is
        // exactly the hover pill — no dead strips at the pill's edges and no
        // dead column around the heart. The heart overlays that slot as its
        // own button, at the same x it had as an HStack sibling.
        return Button(action: { Task { @MainActor in vm.activateFavorite(favorite) } }) {
            HStack(spacing: 6) {
                Image(systemName: favorite.kind == .mosque ? "building.columns" : "mappin.circle")
                    .scaledFont(.caption)
                    .foregroundColor(isActive ? vm.selectedHighlightColor : .secondary)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(favorite.name)
                        .scaledFont(.subheadline, weight: isActive ? .semibold : .regular)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if !favorite.subtitle.isEmpty {
                        Text(favorite.subtitle)
                            .scaledFont(.caption2)
                            .foregroundColor(Color("SecondaryTextColor"))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                Spacer(minLength: 4)
                // Trailing symbols in one zero-spacing group so the
                // checkmark keeps the exact x it had next to the heart; the
                // heart overlay sits on the second (reserved) 20pt slot.
                HStack(spacing: 0) {
                    if isLoading {
                        ProgressView().controlSize(.mini)
                            .frame(width: 20)
                    } else if isActive {
                        Image(systemName: "checkmark")
                            .scaledFont(.caption, weight: .semibold)
                            .foregroundColor(vm.selectedHighlightColor)
                            .frame(width: 20)
                    } else {
                        // Invisible twin of the 20pt trailing slot: keeps the
                        // text column the same width (and the hover pill the
                        // same size) whether the row shows a checkmark or not.
                        Color.clear.frame(width: 20)
                    }
                    // Reserved slot underneath the heart overlay: preserves the
                    // checkmark's x, and the button's hit area extends under the
                    // bands of that column the heart glyph doesn't cover.
                    Color.clear.frame(width: 20)
                }
            }
            .padding(.vertical, 5).padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        // Filled heart removes from favorites; overlays the reserved trailing
        // slot so it stays a separate action without leaving dead hit zones.
        .overlay(alignment: .trailing) {
            Button(action: { vm.removeFavorite(id: favorite.id) }) {
                Image(systemName: "heart.fill")
                    .scaledFont(.caption)
                    .foregroundColor(vm.favoriteColor)
                    .frame(width: 20, height: 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help(Text(NSLocalizedString("Remove from Favorites", comment: "")))
            .padding(.trailing, 8)
        }
        .liquidHover(hoveringFavoriteID == favorite.id)
        .onHover { hovering in
            hoveringFavoriteID = hovering ? favorite.id : nil
        }
    }
}
