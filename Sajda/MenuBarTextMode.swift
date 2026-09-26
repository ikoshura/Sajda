// MARK: - GANTI FILE: Sajda/MenuBarTextMode.swift (DENGAN LOKALISASI)

import Foundation
import SwiftUI

enum MenuBarTextMode: String, CaseIterable, Identifiable {
    case countdown = "Countdown"
    case exactTime = "Exact Time"
    case hidden = "Icon Only"
    case iconCountdown = "Icon + Countdown"
    case iconExactTime = "Icon + Exact Time"
    var id: Self { self }

    // Properti baru untuk menampilkan versi yang sudah diterjemahkan
    var localized: LocalizedStringKey {
        return LocalizedStringKey(self.rawValue)
    }

    /// True for the modes whose text is a countdown — the only ones whose
    /// content changes second by second, so the only ones "Show Seconds" can
    /// affect.
    var isCountdown: Bool { self == .countdown || self == .iconCountdown }
}
