// MARK: - Favorite places (PrayerTimeViewModel extension)

import CoreLocation
import SwiftUI

extension PrayerTimeViewModel {
    /// Colour of a *filled* favorite marker. Fixed red on purpose: a heart is
    /// the universal "saved" glyph, and tinting it with the user's highlight
    /// colour (which can be any custom colour) made the filled state read as
    /// "this row is selected" instead of "this is in your favorites". The
    /// hollow state stays `.secondary` at each call site.
    var favoriteColor: Color { .red }

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

    /// True when the currently active source is already starred — drives the
    /// empty-state row's trailing star on the main screen. City matching is
    /// by coordinates (not name/country) so a favorite saved from search —
    /// which carries a country string — still matches the manual source.
    var isCurrentSelectionFavorite: Bool {
        if useCustomTimetable {
            guard let id = activeTimetableId else { return false }
            return favoritePlaces.contains { $0.kind == .timetable && $0.timetableId == id }
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

    /// Stars whatever is currently active (manual city or timetable) into
    /// favorites from the main screen's empty state.
    func starCurrentSelection() {
        if useCustomTimetable, let timetable = customTimetable {
            let place = FavoritePlace.timetable(timetable, subtitle: Self.timetableFavoriteSubtitle(timetable))
            guard !favoritePlaces.contains(where: { $0.id == place.id }) else { return }
            addFavorite(place)
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

    /// Short printable summary used as a timetable favorite's subtitle.
    static func timetableFavoriteSubtitle(_ timetable: CustomTimetable) -> String {
        let days = timetable.calendar.reduce(0) { $0 + $1.count }
        var parts = ["\(days) days"]
        if timetable.iqamaCalendar != nil { parts.append("iqama") }
        if let jumua = timetable.jumuahSessions, !jumua.isEmpty { parts.append("jumua") }
        return parts.joined(separator: " · ")
    }

    /// Stars or unstars a library timetable by id. Adding keeps the newest at
    /// the end, like cities.
    func toggleTimetableFavorite(_ timetable: CustomTimetable) {
        let place = FavoritePlace.timetable(timetable, subtitle: Self.timetableFavoriteSubtitle(timetable))
        if favoritePlaces.contains(where: { $0.id == place.id }) {
            removeFavorite(id: place.id)
        } else {
            addFavorite(place)
        }
    }

    func isTimetableFavorite(id: String) -> Bool {
        favoritePlaces.contains { $0.kind == .timetable && $0.timetableId == id }
    }

    /// Drops favorites whose timetable no longer exists in the library.
    /// Called after a delete so the panel never offers a dead switch.
    func pruneMissingTimetableFavorites() {
        let known = Set(CustomTimetableStore.loadAll().map(\.id))
        let current = favoritePlaces.filter {
            $0.kind != .timetable || ($0.timetableId.map { known.contains($0) } ?? false)
        }
        if current.count != favoritePlaces.count {
            favoritePlaces = current
            FavoritePlace.save(current)
        }
    }

    /// True when this favorite is the currently active time source.
    func isFavoriteActive(_ favorite: FavoritePlace) -> Bool {
        switch favorite.kind {
        case .city:
            guard isUsingManualLocation, !useCustomTimetable else { return false }
            if let lat = favorite.latitude, let lon = favorite.longitude,
               let current = currentCoordinatesForFavorites {
                return abs(current.latitude - lat) < 0.0001 && abs(current.longitude - lon) < 0.0001
            }
            return locationStatusText == favorite.name
        case .timetable:
            guard useCustomTimetable, let id = favorite.timetableId else { return false }
            if let active = customTimetable, active.id == id { return true }
            return CustomTimetableStore.timetable(id: activeTimetableId)?.id == id
        case .mosque:
            // Mosque favorites were removed with the timetable import change.
            return false
        }
    }

    /// Activates a favourite, and reports whether the switch landed *now*.
    @discardableResult
    func activateFavorite(_ favorite: FavoritePlace) -> Bool {
        switch favorite.kind {
        case .city:
            guard let lat = favorite.latitude, let lon = favorite.longitude else { return false }
            setManualLocation(
                city: favorite.name,
                coordinates: CLLocationCoordinate2D(latitude: lat, longitude: lon)
            )
            return true
        case .timetable:
            guard let id = favorite.timetableId,
                  let timetable = CustomTimetableStore.timetable(id: id) else { return false }
            customTimetable = timetable
            activeTimetableId = id
            useCustomTimetable = true
            return true
        case .mosque:
            return false
        }
    }
}

