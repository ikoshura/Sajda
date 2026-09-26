import Foundation
import CoreLocation

/// One saved favorite: either a calculated city location or a Mawaqit mosque
/// timetable. Stored as JSON in UserDefaults (`favoritePlaces`), capped at
/// `FavoritePlace.maxCount`.
struct FavoritePlace: Codable, Identifiable, Hashable {
    enum Kind: String, Codable {
        case city
        case mosque
    }

    static let maxCount = 5
    static let storeKey = "favoritePlaces"

    /// Stable id: `city:<lat>,<lon>` or `mosque:<slug>`.
    let id: String
    let kind: Kind
    /// Display name: city name or mosque name/label.
    let name: String
    /// Subtitle: country for cities, locality detail for mosques.
    let subtitle: String
    // City payload.
    let latitude: Double?
    let longitude: Double?
    // Mosque payload.
    let slug: String?

    static func city(name: String, country: String, coordinates: CLLocationCoordinate2D) -> FavoritePlace {
        FavoritePlace(
            id: "city:\(coordinates.latitude),\(coordinates.longitude)",
            kind: .city,
            name: name,
            subtitle: country,
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
            slug: nil
        )
    }

    static func mosque(slug: String, label: String) -> FavoritePlace {
        FavoritePlace(
            id: "mosque:\(slug)",
            kind: .mosque,
            name: label,
            subtitle: "",
            latitude: nil,
            longitude: nil,
            slug: slug
        )
    }

    static func load() -> [FavoritePlace] {
        guard let data = UserDefaults.standard.data(forKey: storeKey) else { return [] }
        return (try? JSONDecoder().decode([FavoritePlace].self, from: data)) ?? []
    }

    static func save(_ favorites: [FavoritePlace]) {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }
}
