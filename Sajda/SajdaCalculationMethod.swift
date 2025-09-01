// MARK: - Sajda/SajdaCalculationMethod.swift

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

    static var allCases: [SajdaCalculationMethod] {
        // --- Custom Parameters ---
        var diyanet = CalculationMethod.other.params
        diyanet.fajrAngle = 18.0
        diyanet.ishaAngle = 17.0

        var algeria = CalculationMethod.other.params
        algeria.fajrAngle = 18.0
        algeria.ishaAngle = 17.0

        var france12 = CalculationMethod.other.params
        france12.fajrAngle = 12.0
        france12.ishaAngle = 12.0

        var france18 = CalculationMethod.other.params
        france18.fajrAngle = 18.0
        france18.ishaAngle = 18.0

        var germany = CalculationMethod.other.params
        germany.fajrAngle = 18.0
        germany.ishaAngle = 16.5

        var malaysia = CalculationMethod.other.params
        malaysia.fajrAngle = 20.0
        malaysia.ishaAngle = 18.0

        var indonesia = CalculationMethod.other.params
        indonesia.fajrAngle = 20.0
        indonesia.ishaAngle = 18.0

        var russia = CalculationMethod.other.params
        russia.fajrAngle = 16.0
        russia.ishaAngle = 15.0

        var tunisia = CalculationMethod.other.params
        tunisia.fajrAngle = 18.0
        tunisia.ishaAngle = 18.0

        // --- Built-in + Custom ---
        let methods: [SajdaCalculationMethod] = [
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

            // --- Custom Methods ---
            SajdaCalculationMethod(name: "Diyanet (Turkey)", params: diyanet),
            SajdaCalculationMethod(name: "Algeria", params: algeria),
            SajdaCalculationMethod(name: "France (12°)", params: france12),
            SajdaCalculationMethod(name: "France (18°)", params: france18),
            SajdaCalculationMethod(name: "Germany", params: germany),
            SajdaCalculationMethod(name: "Malaysia (JAKIM)", params: malaysia),
            SajdaCalculationMethod(name: "Indonesia (Kemenag)", params: indonesia),
            SajdaCalculationMethod(name: "Russia", params: russia),
            SajdaCalculationMethod(name: "Tunisia", params: tunisia),
        ]
        return methods.sorted { $0.name < $1.name }
    }
}
