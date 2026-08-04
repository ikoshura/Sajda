// MARK: - Sajda/HighLatitudeRuleSetting.swift

import Foundation
import Adhan

/// User-facing wrapper around Adhan's HighLatitudeRule with a "Recommended" option
/// that maps to nil (let Adhan decide based on location).
enum HighLatitudeRuleSetting: String, CaseIterable, Identifiable {
    case recommended
    case middleOfTheNight
    case seventhOfTheNight
    case twilightAngle

    var id: String { rawValue }

    /// The corresponding Adhan rule, or nil when "Recommended" is selected
    /// (nil tells Adhan to use its own `recommended(for:)` logic).
    var adhanRule: HighLatitudeRule? {
        switch self {
        case .recommended: return nil
        case .middleOfTheNight: return .middleOfTheNight
        case .seventhOfTheNight: return .seventhOfTheNight
        case .twilightAngle: return .twilightAngle
        }
    }

    /// Inverse mapping for displaying the effective rule.
    init?(adhanRule: HighLatitudeRule) {
        switch adhanRule {
        case .middleOfTheNight: self = .middleOfTheNight
        case .seventhOfTheNight: self = .seventhOfTheNight
        case .twilightAngle: self = .twilightAngle
        }
    }

    // MARK: - Localized Display

    var displayName: String {
        switch self {
        case .recommended:
            return NSLocalizedString("Recommended", comment: "High-latitude rule picker option")
        case .middleOfTheNight:
            return NSLocalizedString("Middle of the Night", comment: "High-latitude rule picker option")
        case .seventhOfTheNight:
            return NSLocalizedString("Seventh of the Night", comment: "High-latitude rule picker option")
        case .twilightAngle:
            return NSLocalizedString("Twilight Angle", comment: "High-latitude rule picker option")
        }
    }

    /// Short explanation of what the rule does, shown under the picker.
    var description: String {
        switch self {
        case .recommended:
            return NSLocalizedString("Uses the rule recommended for your location's latitude.", comment: "High-latitude rule description")
        case .middleOfTheNight:
            return NSLocalizedString("Fajr and Isha are limited to the middle of the night.", comment: "High-latitude rule description")
        case .seventhOfTheNight:
            return NSLocalizedString("Fajr and Isha are limited to the first and last seventh of the night.", comment: "High-latitude rule description")
        case .twilightAngle:
            return NSLocalizedString("The night is divided by the Fajr/Isha angles; times are computed from a proportional part of the night.", comment: "High-latitude rule description")
        }
    }
}
