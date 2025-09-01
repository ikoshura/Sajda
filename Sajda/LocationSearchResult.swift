// MARK: - GANTI SELURUH FILE: Sajda/LocationSearchResult.swift

import Foundation
import CoreLocation

struct LocationSearchResult: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let country: String
    let coordinates: CLLocationCoordinate2D

    // Memberitahu Swift cara menentukan keunikan: berdasarkan nama dan negara.
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(country)
    }

    // Memberitahu Swift cara membandingkan dua hasil lokasi.
    static func == (lhs: LocationSearchResult, rhs: LocationSearchResult) -> Bool {
        return lhs.name == rhs.name && lhs.country == rhs.country
    }
}
