// MARK: - GANTI/BUAT FILE: Sajda/LanguageManager.swift

import SwiftUI

// Kelas ini akan menjadi satu-satunya sumber kebenaran untuk bahasa.
class LanguageManager: ObservableObject {
    @AppStorage("selectedLanguage") var language: String = "en" {
        didSet {
            Bundle.setLanguage(language)
            objectWillChange.send()
        }
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
        let value = language == "en" ? nil : Bundle.main.path(forResource: language, ofType: "lproj")
        objc_setAssociatedObject(Bundle.main, &BundleLanguageKey.key, value, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
