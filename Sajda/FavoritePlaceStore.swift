// MARK: - Favorite places (PrayerTimeViewModel extension)

import CoreLocation

extension PrayerTimeViewModel {
    /// Adds `place`, dropping the oldest when already at `maxCount`.
    func addFavorite(_ place: FavoritePlace) {
        var current = favoritePlaces
        current.removeAll { $0.id == place.id }
        while current.count >= FavoritePlace.maxCount {
            current.removeFirst()
        }
        current.append(place)
        favoritePlaces = current
        FavoritePlace.save(current)
        hasEverSavedFavorite = true
    }

    func removeFavorite(id: String) {
        let current = favoritePlaces.filter { $0.id != id }
        favoritePlaces = current
        FavoritePlace.save(current)
    }

    func isCityFavorite(_ result: LocationSearchResult) -> Bool {
        let id = FavoritePlace.city(name: result.name, country: result.country, coordinates: result.coordinates).id
        return favoritePlaces.contains { $0.id == id }
    }

    func toggleCityFavorite(_ result: LocationSearchResult) {
        let place = FavoritePlace.city(name: result.name, country: result.country, coordinates: result.coordinates)
        if favoritePlaces.contains(where: { $0.id == place.id }) {
            removeFavorite(id: place.id)
        } else {
            addFavorite(place)
        }
    }

    func isMosqueFavorite(slug: String) -> Bool {
        favoritePlaces.contains { $0.kind == .mosque && $0.slug == slug }
    }

    /// True when the currently active source is already starred — drives the
    /// empty-state row's trailing star on the main screen. City matching is
    /// by coordinates (not name/country) so a favorite saved from search —
    /// which carries a country string — still matches the manual source.
    var isCurrentSelectionFavorite: Bool {
        if useMawaqitSchedule {
            guard let slug = mawaqitMosque?.slug ?? MawaqitService.load()?.slug else { return false }
            return favoritePlaces.contains { $0.kind == .mosque && $0.slug == slug }
        }
        if isUsingManualLocation, let coords = currentCoordinatesForFavorites {
            return favoritePlaces.contains {
                $0.kind == .city && $0.latitude != nil && $0.longitude != nil
                && abs($0.latitude! - coords.latitude) < 0.0001
                && abs($0.longitude! - coords.longitude) < 0.0001
            }
        }
        return false
    }

    /// Stars whatever is currently active (manual city or mosque timetable)
    /// into favorites from the main screen's empty state.
    func starCurrentSelection() {
        if useMawaqitSchedule {
            let slug = mawaqitMosque?.slug ?? MawaqitService.load()?.slug
            let label = mawaqitMosque?.name ?? MawaqitService.load()?.name ?? panelLocationCaption
            guard let slug else { return }
            guard !isMosqueFavorite(slug: slug) else { return }
            toggleMosqueFavorite(slug: slug, label: label)
        } else if isUsingManualLocation, let coords = currentCoordinatesForFavorites {
            // Country isn't shown on the caption, so reuse the favorite's
            // stored country when these coordinates were starred before
            // (keeps toggle-off working); otherwise the caption is the name.
            let existing = favoritePlaces.first {
                $0.kind == .city && $0.latitude != nil && $0.longitude != nil
                && abs($0.latitude! - coords.latitude) < 0.0001
                && abs($0.longitude! - coords.longitude) < 0.0001
            }
            let probe = LocationSearchResult(
                name: existing?.name ?? locationStatusText,
                country: existing?.subtitle ?? "",
                coordinates: coords
            )
            guard !isCityFavorite(probe) else { return }
            toggleCityFavorite(probe)
        }
    }

    /// Stars a mosque search hit. Kicks off a background calendar download so
    /// the favorite switches instantly (and offline) later.
    func toggleMosqueFavorite(slug: String, label: String) {
        let place = FavoritePlace.mosque(slug: slug, label: label)
        if favoritePlaces.contains(where: { $0.id == place.id }) {
            removeFavorite(id: place.id)
        } else {
            addFavorite(place)
            ensureMosqueCached(slug: slug)
        }
    }

    /// True when this favorite is the currently active time source.
    /// Side-effect free: never assigns `mawaqitMosque` here (doing so while
    /// SwiftUI is reading the row would publish during a view update and can
    /// crash). Falls back to a disk read without storing.
    func isFavoriteActive(_ favorite: FavoritePlace) -> Bool {
        switch favorite.kind {
        case .city:
            guard isUsingManualLocation, !useMawaqitSchedule else { return false }
            if let lat = favorite.latitude, let lon = favorite.longitude,
               let current = currentCoordinatesForFavorites {
                return abs(current.latitude - lat) < 0.0001 && abs(current.longitude - lon) < 0.0001
            }
            return locationStatusText == favorite.name
        case .mosque:
            guard useMawaqitSchedule else { return false }
            if let mosque = mawaqitMosque {
                return mosque.slug == favorite.slug
            }
            return MawaqitService.load()?.slug == favorite.slug
        }
    }

    /// Switches to a favorite. City switches are synchronous (same safe
    /// ordering as `setManualLocation`: coordinates first, timetable mode off
    /// last, so no intermediate state can crash). Mosque switches use the
    /// per-slug offline cache when present and download otherwise — always
    /// activating on the main thread like the Settings flow does.
    /// The `favoriteMosqueLoadingSlug` guard is the hidden mode-switch
    /// workaround: only one mosque download runs at a time, and the row is
    /// disabled while it runs, so tapping city ↔ mosque (or two mosques) in
    /// quick succession can't interleave two mode flips and crash.
    @MainActor
    func activateFavorite(_ favorite: FavoritePlace) {
        switch favorite.kind {
        case .city:
            // City taps always win: cancel any pending mosque download first,
            // so mosque → city feels instant and can never interleave two
            // mode flips. The stale download's guard below then drops it.
            favoriteMosqueLoadingSlug = nil
            guard let lat = favorite.latitude, let lon = favorite.longitude else { return }
            setManualLocation(
                city: favorite.name,
                coordinates: CLLocationCoordinate2D(latitude: lat, longitude: lon)
            )
        case .mosque:
            guard let slug = favorite.slug else { return }
            // Same mosque already active: nothing to do.
            if useMawaqitSchedule, mawaqitMosque?.slug == slug { return }
            // A different mosque is still downloading: ignore, don't stack.
            guard favoriteMosqueLoadingSlug == nil else { return }
            if let cached = MawaqitService.load(slug: slug) {
                activateMosqueSchedule(cached)
                return
            }
            favoriteMosqueLoadingSlug = slug
            Task { @MainActor in
                defer { self.favoriteMosqueLoadingSlug = nil }
                do {
                    let mosque = try await MawaqitService.fetchCalendar(slug: slug)
                    // User may have tapped a city while this downloaded: only
                    // activate when this favorite is still the pending one.
                    guard self.favoriteMosqueLoadingSlug == slug else { return }
                    try? MawaqitService.saveToCache(mosque)
                    self.activateMosqueSchedule(mosque)
                } catch {
                    NSLog("Favorite mosque download failed: %@", error.localizedDescription)
                }
            }
        }
    }

    /// Downloads a mosque calendar into the per-slug offline cache without
    /// activating it, so a starred mosque is ready when tapped.
    func ensureMosqueCached(slug: String) {
        if MawaqitService.load(slug: slug) != nil { return }
        Task {
            do {
                let mosque = try await MawaqitService.fetchCalendar(slug: slug)
                try? MawaqitService.saveToCache(mosque)
            } catch {
                NSLog("Favorite mosque prefetch failed: %@", error.localizedDescription)
            }
        }
    }
}

