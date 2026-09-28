// MARK: - GANTI/BUAT FILE: Sajda/LanguageManager.swift

import SwiftUI

// Kelas ini akan menjadi satu-satunya sumber kebenaran untuk bahasa.
class LanguageManager: ObservableObject {
    /// Every language the app actually ships a `.lproj` for (see `Sajda/*.lproj`).
    ///
    /// The picker offers exactly these, because a code with no `.lproj` behind
    /// it cannot be rendered: SwiftUI resolves `Text("literal")` against the
    /// `.lproj` for the active locale, and when that lookup misses it falls
    /// back to the *system* language. That is how a Korean selection could end
    /// up showing Chinese (or a Chinese selection showing English) on a Mac
    /// whose system language differed from the picked one.
    static let supportedCodes = ["en", "ar", "id", "es", "fr", "de", "ja", "zh-Hans", "ko"]

    /// Native name for the picker — always drawn in the language's own script,
    /// so the list stays readable whichever language is currently active.
    static func displayName(for code: String) -> String {
        switch code {
        case "en": return "English"
        case "ar": return "العربية"
        case "id": return "Indonesia"
        case "es": return "Español"
        case "fr": return "Français"
        case "de": return "Deutsch"
        case "ja": return "日本語"
        case "zh-Hans": return "简体中文"
        case "ko": return "한국어"
        default: return code
        }
    }

    @AppStorage("selectedLanguage") var language: String = "en" {
        didSet {
            Bundle.setLanguage(language)
            objectWillChange.send()
        }
    }

    init() {
        // Heal a stored value we no longer ship (or a stray typo) before the
        // first render, so the picker and the pinned `.lproj` can never
        // disagree — an unknown code would otherwise quietly render English.
        if !Self.supportedCodes.contains(language) {
            language = "en"
        }
        Bundle.setLanguage(language)
    }
}

// View pembungkus ini akan menerapkan environment dan memaksa render ulang.
struct LanguageManagerView<Content: View>: View {
    @StateObject var manager: LanguageManager
    let content: Content

    init(manager: LanguageManager, @ViewBuilder content: () -> Content) {
        _manager = StateObject(wrappedValue: manager)
        self.content = content()
    }

    /// Arabic uses Eastern Arabic numerals (٠١٢٣٤٥٦٧٨٩) plus an Arabic
    /// locale so dates/times render natively. Other languages keep the
    /// default numbering system.
    private var effectiveLocale: Locale {
        // Guard the code before handing it to `Locale`: an unknown identifier
        // makes SwiftUI miss every `.lproj` and fall back to the *system*
        // language, which is the wrong-language render we are fixing here.
        guard LanguageManager.supportedCodes.contains(manager.language) else {
            return Locale(identifier: "en")
        }
        if manager.language == "ar" {
            return Locale(identifier: "ar_EG")
        }
        return Locale(identifier: manager.language)
    }

    var body: some View {
        content
            .environmentObject(manager)
            .environment(\.locale, effectiveLocale)
            .environment(\.layoutDirection, manager.language == "ar" ? .rightToLeft : .leftToRight)
            .id(manager.language) // Ini adalah kunci untuk memaksa render ulang!
    }
}

// Ekstensi untuk Bundle (tetap di file yang sama)
private enum BundleLanguageKey { static var key: UInt8 = 0 }
class AnyLanguageBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let path = objc_getAssociatedObject(self, &BundleLanguageKey.key) as? String,
              let bundle = Bundle(path: path) else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }
}
extension Bundle {
    static func setLanguage(_ language: String) {
        defer { object_setClass(Bundle.main, AnyLanguageBundle.self) }
        // Always pin an explicit .lproj — including English. Leaving the
        // "en" association nil used to fall through to the *system* language
        // there, so on a French system the `NSLocalizedString` surfaces (the
        // menu bar title among them) stayed French after switching the app
        // back to English.
        //
        // The English fallback matters for the same reason: when the requested
        // code has no `.lproj` (a language we stopped shipping, or a stale
        // stored value) a nil path hands the lookup back to `super`, which
        // resolves against the *system* language. That is exactly how picking
        // Korean on a Chinese system rendered Chinese. Missing languages must
        // degrade to English, never to whatever the Mac happens to be set to.
        let value = Bundle.main.path(forResource: language, ofType: "lproj")
            ?? Bundle.main.path(forResource: "en", ofType: "lproj")
        objc_setAssociatedObject(Bundle.main, &BundleLanguageKey.key, value, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
