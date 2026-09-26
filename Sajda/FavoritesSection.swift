// MARK: - Sajda/FavoritesSection.swift
//
// Main-screen favorites: up to 5 saved cities + mosque timetables.
// The accordion chevron lives on the location caption line in MainView
// (trailing edge, same row) — this view only renders the expanded rows.
// Tapping a row switches straight to it; the "Automatic" row switches back
// to system location via `switchToAutomaticLocation`.

import SwiftUI
import NavigationStack

struct FavoritesSection: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    @EnvironmentObject var navigationModel: NavigationModel

    @State private var hoveringFavoriteID: String?
    @State private var isAutomaticHovering = false
    @State private var isCityHovering = false
    @State private var isMosqueHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
                automaticRow
                if vm.favoritePlaces.isEmpty {
                    // No favorites yet: direct shortcuts to the two search
                    // pages (same rows, same hover, just no star column),
                    // so starring can start from here.
                    citySearchRow
                    mosqueSearchRow
                } else {
                    ForEach(vm.favoritePlaces) { favorite in
                        favoriteRow(favorite)
                    }
                    // Divider between saved favorites and the two search
                    // shortcuts below them.
                    Rectangle()
                        .fill(Color("DividerColor"))
                        .frame(height: 0.5)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                    citySearchRow
                    mosqueSearchRow
                }
            }
            .padding(.vertical, 2)
            .clipped()
    }

    /// One-tap return to system location (also exits timetable mode —
    /// same safe ordering as the Settings button, so the flip can't crash).
    /// Outer HStack (not the Button) owns the padding + hover so the
    /// highlight pill is exactly the same size as every favorite row.
    private var automaticRow: some View {
        let isActive = !vm.isUsingManualLocation && !vm.useMawaqitSchedule
        return HStack(spacing: 0) {
            Button(action: { vm.switchToAutomaticLocation() }) {
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
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // Fixed trailing slot: the checkmark sits at the exact x the
            // stars use on the rows below.
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
        .liquidHover(isAutomaticHovering)
        .onHover { hovering in
            isAutomaticHovering = hovering
        }
    }

    /// Shortcuts shown when no favorites exist yet: jump straight to the
    /// city or mosque search, where the star beside a result saves it.
    /// Same row metrics + chevron as the favorite rows so hover pills and
    /// trailing symbols line up exactly.
    private var citySearchRow: some View {
        Button(action: {
            // This row renders inside FavoritesView, which is itself the
            // active alternative view of ContentView.id — a second
            // showView on the same id trips NavigationStack's
            // 'replacing showing navigation view' fatalError. Pop the
            // favorites page first (synchronous, no animation), then push
            // the search exactly like the old main-screen flow did.
            navigationModel.hideView(ContentView.id, animation: nil)
            navigationModel.showView(ContentView.id, animation: vm.forwardAnimation()) { ManualLocationView(isModal: true) }
        }) {
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
                Image(systemName: vm.forwardChevron)
                    .scaledFont(.caption, weight: .bold)
                    .foregroundColor(.secondary)
                    .frame(width: 20)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 5).padding(.horizontal, 8)
        .liquidHover(isCityHovering)
        .onHover { hovering in isCityHovering = hovering }
    }

    private var mosqueSearchRow: some View {
        Button(action: {
            // Same double-push guard as citySearchRow: pop FavoritesView
            // off ContentView.id before pushing the mosque search.
            navigationModel.hideView(ContentView.id, animation: nil)
            navigationModel.showView(ContentView.id, animation: vm.forwardAnimation()) { MosqueSearchView() }
        }) {
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
                Image(systemName: vm.forwardChevron)
                    .scaledFont(.caption, weight: .bold)
                    .foregroundColor(.secondary)
                    .frame(width: 20)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 5).padding(.horizontal, 8)
        .liquidHover(isMosqueHovering)
        .onHover { hovering in isMosqueHovering = hovering }
    }

    private func favoriteRow(_ favorite: FavoritePlace) -> some View {
        let isActive = vm.isFavoriteActive(favorite)
        let isLoading = vm.favoriteMosqueLoadingSlug == favorite.slug && favorite.kind == .mosque
        return HStack(spacing: 0) {
            Button(action: { Task { @MainActor in vm.activateFavorite(favorite) } }) {
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
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            // Star removes from favorites; same fixed 20pt slot as the
            // checkmarks, so every trailing symbol shares one x.
            Button(action: { vm.removeFavorite(id: favorite.id) }) {
                Image(systemName: "star.fill")
                    .scaledFont(.caption)
                    .foregroundColor(vm.selectedHighlightColor)
                    .frame(width: 20)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help(Text(NSLocalizedString("Remove from Favorites", comment: "")))
        }
        .padding(.vertical, 5).padding(.horizontal, 8)
        .liquidHover(hoveringFavoriteID == favorite.id)
        .onHover { hovering in
            hoveringFavoriteID = hovering ? favorite.id : nil
        }
    }
}
