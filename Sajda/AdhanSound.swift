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
        case .fajrAzan1: return "adhan_fajr_1"
        case .fajrAzan2: return "adhan_fajr_2"
        case .standardAzan1: return "adhan_standard_1"
        case .standardAzan2: return "adhan_standard_2"
        case .standardAzan3: return "adhan_standard_3"
        default: return nil
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
