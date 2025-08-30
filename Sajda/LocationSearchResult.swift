// MARK: - BUAT FILE BARU: Sajda/LocationSearchResult.swift
// Salin dan tempel SELURUH kode ini ke dalam file baru.

import Foundation
import CoreLocation // Diperlukan untuk CLLocationCoordinate2D

struct LocationSearchResult: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let country: String
    let coordinates: CLLocationCoordinate2D

    static func == (lhs: LocationSearchResult, rhs: LocationSearchResult) -> Bool {
        return lhs.id == rhs.id
    }
}
