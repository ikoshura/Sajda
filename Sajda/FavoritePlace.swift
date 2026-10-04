import Foundation
import CoreLocation

/// One saved favorite: a calculated city location or an imported timetable.
/// Stored as JSON in UserDefaults (`favoritePlaces`), capped at
/// `FavoritePlace.maxCount`.
struct FavoritePlace: Codable, Identifiable, Hashable {
    enum Kind: String, Codable {
        case city
        case mosque
        case timetable
    }

    static let maxCount = 5
    static let storeKey = "favoritePlaces"

    /// Memberwise initializer, spelled out because the custom `init(from:)`
    /// below suppresses Swift's synthesized one.
    init(id: String, kind: Kind, name: String, subtitle: String,
         latitude: Double?, longitude: Double?, timetableId: String?, slug: String?) {
        self.id = id
        self.kind = kind
        self.name = name
        self.subtitle = subtitle
        self.latitude = latitude
        self.longitude = longitude
        self.timetableId = timetableId
        self.slug = slug
    }

    /// Stable id: `city:<lat>,<lon>`, `timetable:<timetableId>`, or the legacy
    /// `mosque:<slug>`.
    let id: String
    let kind: Kind
    /// Display name: city, mosque label, or timetable name.
    let name: String
    /// Subtitle: country for cities; detail (days/iqama/jumua) for timetables.
    let subtitle: String
    // City payload.
    let latitude: Double?
    let longitude: Double?
    // Timetable payload (nil for cities; slug doubles for legacy mosques).
    let timetableId: String?
    // Legacy mosque payload.
    let slug: String?

    static func city(name: String, country: String, coordinates: CLLocationCoordinate2D) -> FavoritePlace {
        FavoritePlace(id: "city:\(coordinates.latitude),\(coordinates.longitude)",
                      kind: .city, name: name, subtitle: country,
                      latitude: coordinates.latitude, longitude: coordinates.longitude,
                      timetableId: nil, slug: nil)
    }

    static func timetable(_ timetable: CustomTimetable, subtitle: String) -> FavoritePlace {
        FavoritePlace(id: "timetable:\(timetable.id)", kind: .timetable, name: timetable.name,
                      subtitle: subtitle, latitude: nil, longitude: nil,
                      timetableId: timetable.id, slug: nil)
    }

    static func mosque(slug: String, label: String) -> FavoritePlace {
        FavoritePlace(id: "mosque:\(slug)", kind: .mosque, name: label, subtitle: "",
                      latitude: nil, longitude: nil, timetableId: nil, slug: slug)
    }

    /// Decodes old favorites that predate the `timetableId` field: missing
    /// keys decode as nil instead of failing the whole list.
    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try box.decode(String.self, forKey: .id)
        self.kind = try box.decode(Kind.self, forKey: .kind)
        self.name = try box.decode(String.self, forKey: .name)
        self.subtitle = (try? box.decode(String.self, forKey: .subtitle)) ?? ""
        self.latitude = try? box.decodeIfPresent(Double.self, forKey: .latitude)
        self.longitude = try? box.decodeIfPresent(Double.self, forKey: .longitude)
        self.timetableId = try? box.decodeIfPresent(String.self, forKey: .timetableId)
        self.slug = try? box.decodeIfPresent(String.self, forKey: .slug)
    }

    static func load() -> [FavoritePlace] {
        guard let data = UserDefaults.standard.data(forKey: storeKey) else { return [] }
        let places = (try? JSONDecoder().decode([FavoritePlace].self, from: data)) ?? []
        // Legacy mosque favorites no longer resolve to anything: drop them,
        // keep cities and timetables.
        return places.filter { $0.kind == .city || $0.kind == .timetable }
    }

    static func save(_ favorites: [FavoritePlace]) {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }
}
