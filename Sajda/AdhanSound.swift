import Foundation

enum AdhanType: String, CaseIterable, Identifiable, Codable {
    case none
    case defaultBeep
    case fajrAzan1
    case fajrAzan2
    case standardAzan1
    case standardAzan2
    case standardAzan3
    case custom

    var id: String { rawValue }

    var bundleFileName: String? {
        switch self {
        case .fajrAzan1: return "Mishary_Rashid_al_Afasy_Fajr_Adhan"
        case .fajrAzan2: return "Doha_Qatar_Fajr_Adhan"
        case .standardAzan1: return "Ahmed_al_Imadi_Adhan"
        case .standardAzan2: return "Majed_al_Hamathani_Adhan"
        case .standardAzan3: return "Nasser_al_Qatami_Adhan"
        default: return nil
        }
    }

    /// Muezzin name for display alongside the localized label.
    var muezzinName: String {
        switch self {
        case .fajrAzan1: return "Mishary Rashid al Afasy"
        case .fajrAzan2: return "Doha Qatar — Fajr"
        case .standardAzan1: return "Ahmed al Imadi"
        case .standardAzan2: return "Majed al Hamathani"
        case .standardAzan3: return "Nasser al Qatami"
        default: return ""
        }
    }

    var displayName: String {
        NSLocalizedString(rawValue, comment: "")
    }

    var isAzan: Bool {
        switch self {
        case .fajrAzan1, .fajrAzan2, .standardAzan1, .standardAzan2, .standardAzan3:
            return true
        default:
            return false
        }
    }

    static let sunnahPrayers = ["Tahajud", "Dhuha"]

    static func availableOptions(for prayerName: String) -> [AdhanType] {
        if sunnahPrayers.contains(prayerName) {
            return [.none, .defaultBeep, .custom]
        }
        return allCases
    }
}

struct PrayerSoundConfig: Codable, Equatable {
    var adhanType: AdhanType = .defaultBeep
    var customFilePath: String = ""
}
