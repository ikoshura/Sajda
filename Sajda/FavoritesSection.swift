// MARK: - Sajda/FavoritesSection.swift
//
// The location list that unfolds under the location row on the main panel:
// "Use Automatic Location", then the saved favourites — cities and mosque
// timetables — then one row into Settings → Calculation & Location.
//
// That shape is @iMacLion's suggestion (issue #23), taken up in 4.4.13: this
// used to carry the two inline search accordions as well, so the dropdown the
// user opened to *switch* somewhere also held a search UI. Searching, starring
// and browsing live on the Location settings page; the panel's job is to switch
// between the places already saved and then get out of the way. Tapping a
// favourite switches to it and folds the list, leaving the schedule on screen
// (his words: "instantly switch to it, close the dropdown").
//
// Removing a favourite is still one tap from here — that is an undo, not a
// browse, so it stays.

import SwiftUI

struct FavoritesSection: View {
    @EnvironmentObject var vm: PrayerTimeViewModel

    /// Called after a location switch from this list has been requested, so the
    /// owner can fold it — Automatic included, because the caption row above is
    /// where its progress and its failures are reported. Deliberately *not*
    /// called while a mosque timetable is still downloading: that row's spinner
    /// is the only feedback the download has, and folding would take it off
    /// screen. See `FavoritePlaceStore.activateFavorite(_:)`, which reports
    /// which it was.
    ///
    /// Folding is the owner's business, curve included: the panel folds on
    /// `.sajdaAccordion` (see `MainView.collapseLocationAfterPick`).
    let onLocationPicked: () -> Void

    /// Opens Settings → Calculation & Location. The owner collapses this list
    /// first, so the panel does not resize through the push (the same reason
    /// the Settings and About buttons fold it — see
    /// `MainView.collapseLocationForNavigation`).
    let onOpenLocationSettings: () -> Void

    @State private var hoveringFavoriteID: String?
    @State private var isAutomaticHovering = false
    @State private var isLocationSettingsHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            automaticRow
            if !vm.favoritePlaces.isEmpty {
                ForEach(vm.favoritePlaces) { favorite in
                    favoriteRow(favorite)
                }
                // Divider between the saved favourites and the way into Settings.
                Rectangle()
                    .fill(Color("DividerColor"))
                    .frame(height: 0.5)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
            }
            // Always shown, favourites or not: with nothing saved yet it is the
            // only way to start saving, which is all this list can do when empty.
            locationSettingsRow
        }
        .padding(.vertical, 2)
        .clipped()
    }

    /// The way into Settings → Calculation & Location, where searching, starring
    /// and browsing live.
    ///
    /// Not an accordion: it navigates, so it carries the panel's forward chevron
    /// instead of one that flips — the same trailing symbol the sub-page rows use
    /// in Settings, so it reads as "goes somewhere" rather than "opens here".
    /// Same row metrics as every other row here (16pt icon slot, 20pt trailing
    /// slot), so the column lines up with the hearts above it.
    private var locationSettingsRow: some View {
        Button(action: onOpenLocationSettings) {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .scaledFont(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 16)
                Text(NSLocalizedString("Location Settings", comment: ""))
                    .scaledFont(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                Image(systemName: vm.forwardChevron)
                    .scaledFont(.caption, weight: .semibold)
                    .foregroundColor(.secondary)
                    .frame(width: 20)
            }
            // Padding inside the label: the button covers the whole hover pill.
            .padding(.vertical, 5).padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .liquidHover(isLocationSettingsHovering)
        .onHover { hovering in isLocationSettingsHovering = hovering }
    }

    /// One-tap return to system location (also exits timetable mode —
    /// same safe ordering as the Settings button, so the flip can't crash).
    /// The Button's label owns the row padding + trailing slot so the hit
    /// area is exactly the hover pill (no dead strips at the pill's edges).
    private var automaticRow: some View {
        let isActive = !vm.isUsingManualLocation && !vm.useMawaqitSchedule
        // Folds with every other pick: the caption row above is where
        // "Finding your location…" and any failure to find it are reported, so
        // there is nothing left to watch down here.
        return Button(action: { vm.switchToAutomaticLocation(); onLocationPicked() }) {
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

    private func favoriteRow(_ favorite: FavoritePlace) -> some View {
        let isActive = vm.isFavoriteActive(favorite)
        let isLoading = vm.favoriteMosqueLoadingSlug == favorite.slug && favorite.kind == .mosque
        // The row Button's label owns the padding + full-width content
        // (including a reserved 20pt slot for the heart), so the hit area is
        // exactly the hover pill — no dead strips at the pill's edges and no
        // dead column around the heart. The heart overlays that slot as its
        // own button, at the same x it had as an HStack sibling.
        return Button(action: {
            Task { @MainActor in
                // Folds the list only when the switch has actually landed, so a
                // mosque still downloading keeps its row — and its spinner —
                // on screen (`activateFavorite` returns false for that).
                if vm.activateFavorite(favorite) { onLocationPicked() }
            }
        }) {
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
