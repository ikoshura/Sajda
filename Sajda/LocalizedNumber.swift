// MARK: - Sajda/LocalizedNumber.swift
//
// One place for the two number chores that come with rendering digits in the
// user's own numbering system:
//
//   * printing — `String(format:)` without a locale always prints ASCII
//     digits, so an Arabic panel showed "24" and "+8" next to text that was
//     otherwise Eastern Arabic (٠١٢٣٤٥٦٧٨٩). Passing the locale fixes the
//     output, and this wrapper keeps every call site doing it the same way.
//   * reading — once a field *displays* ٨ the user can also type ٨, so the
//     editable steppers have to parse it back (`Double("٨")` is nil).

import Foundation
/// Digits as the active language writes them.
enum LocalizedNumber {
    /// `value` rendered with `locale`'s numbering system ("10" / "١٠").
    static func string(_ value: Int, locale: Locale) -> String {
        String(format: "%d", locale: locale, value)
    }

    /// Signed form used by the correction steppers ("+8" / "+٨").
    static func signedString(_ value: Double, locale: Locale) -> String {
        String(format: "%+.0f", locale: locale, value)
    }

    /// Unsigned whole number ("8" / "٨").
    static func wholeString(_ value: Double, locale: Locale) -> String {
        String(format: "%.0f", locale: locale, value)
    }

    /// `value` with exactly `fractionDigits` decimals ("30.5" / "٣٠٫٥").
    static func fixedString(_ value: Double, locale: Locale, fractionDigits: Int) -> String {
        String(format: "%.\(fractionDigits)f", locale: locale, value)
    }

    /// Parses a number typed in *any* numbering system.
    /// Normalises Arabic-Indic (٠-٩) and Extended Arabic-Indic (۰-۹) digits,
    /// the Arabic decimal separator (٫) and thousands separator (٬), plus the
    /// bidi marks formatters can put around a sign, then reads it as ASCII —
    /// so a locale-formatted field stays editable.
    static func value(from text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let direct = Double(trimmed) { return direct }

        var normalized = ""
        normalized.reserveCapacity(trimmed.count)
        for character in trimmed {
            switch character {
            case "٠", "۰": normalized.append("0")
            case "١", "۱": normalized.append("1")
            case "٢", "۲": normalized.append("2")
            case "٣", "۳": normalized.append("3")
            case "٤", "۴": normalized.append("4")
            case "٥", "۵": normalized.append("5")
            case "٦", "۶": normalized.append("6")
            case "٧", "۷": normalized.append("7")
            case "٨", "۸": normalized.append("8")
            case "٩", "۹": normalized.append("9")
            case "٫": normalized.append(".")
            case "٬", ",", " ": continue
            // Arabic Letter Mark / RLM / LRM that locale-aware formatters put
            // around a sign. Harmless to drop, and they would break `Double`.
            case "؜", "‏", "‎": continue
            case "−", "–": normalized.append("-")
            default:
                normalized.append(character)
            }
        }
        return Double(normalized)
    }
}
