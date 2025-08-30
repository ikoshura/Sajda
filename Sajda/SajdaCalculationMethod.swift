// MARK: - GANTI FILE: Sajda/SajdaCalculationMethod.swift (VERSI FINAL & DIPERBAIKI)
// Memperbaiki sintaks untuk mengambil parameter standar dan membuat parameter kustom.

import Foundation
import Adhan

struct SajdaCalculationMethod: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let params: CalculationParameters

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

    static func == (lhs: SajdaCalculationMethod, rhs: SajdaCalculationMethod) -> Bool {
        lhs.name == rhs.name
    }

    // --- PERBAIKAN UTAMA DI SINI ---
    // Menggunakan sintaks yang benar untuk mengambil parameter standar dan membuat parameter kustom.
    static var allCases: [SajdaCalculationMethod] {
        let methods: [SajdaCalculationMethod] = [
            // Cara yang benar untuk mengambil parameter dari enum CalculationMethod bawaan Adhan
            SajdaCalculationMethod(name: "Muslim World League", params: CalculationMethod.muslimWorldLeague.params),
            SajdaCalculationMethod(name: "Egyptian General Authority", params: CalculationMethod.egyptian.params),
            SajdaCalculationMethod(name: "University of Islamic Sciences, Karachi", params: CalculationMethod.karachi.params),
            SajdaCalculationMethod(name: "Umm al-Qura University, Makkah", params: CalculationMethod.ummAlQura.params),
            SajdaCalculationMethod(name: "Dubai", params: CalculationMethod.dubai.params),
            SajdaCalculationMethod(name: "Moonsighting Committee", params: CalculationMethod.moonsightingCommittee.params),
            SajdaCalculationMethod(name: "ISNA (North America)", params: CalculationMethod.northAmerica.params),
            SajdaCalculationMethod(name: "Kuwait", params: CalculationMethod.kuwait.params),
            SajdaCalculationMethod(name: "Qatar", params: CalculationMethod.qatar.params),
            SajdaCalculationMethod(name: "Singapore", params: CalculationMethod.singapore.params),
            SajdaCalculationMethod(name: "Tehran", params: CalculationMethod.tehran.params),
            
            // Cara yang benar untuk membuat parameter kustom dengan initializer dan nilai Double
            SajdaCalculationMethod(name: "Diyanet (Turkey)", params: CalculationParameters(fajrAngle: 18.0, ishaAngle: 17.0)),
            SajdaCalculationMethod(name: "Algeria", params: CalculationParameters(fajrAngle: 18.0, ishaAngle: 17.0)),
            SajdaCalculationMethod(name: "France (12°)", params: CalculationParameters(fajrAngle: 12.0, ishaAngle: 12.0)),
            SajdaCalculationMethod(name: "France (18°)", params: CalculationParameters(fajrAngle: 18.0, ishaAngle: 18.0)),
            SajdaCalculationMethod(name: "Germany", params: CalculationParameters(fajrAngle: 18.0, ishaAngle: 16.5)),
            SajdaCalculationMethod(name: "Malaysia (JAKIM)", params: CalculationParameters(fajrAngle: 20.0, ishaAngle: 18.0)),
            SajdaCalculationMethod(name: "Indonesia (Kemenag)", params: CalculationParameters(fajrAngle: 20.0, ishaAngle: 18.0)),
            SajdaCalculationMethod(name: "Russia", params: CalculationParameters(fajrAngle: 16.0, ishaAngle: 15.0)),
            SajdaCalculationMethod(name: "Tunisia", params: CalculationParameters(fajrAngle: 18.0, ishaAngle: 18.0)),
        ]
        return methods.sorted { $0.name < $1.name }
    }
}
