// MARK: - GANTI FILE: Sajda/MenuBarTextMode.swift (DENGAN LOKALISASI)

import Foundation
import SwiftUI

enum MenuBarTextMode: String, CaseIterable, Identifiable {
    case countdown = "Countdown"
    case exactTime = "Exact Time"
    case hidden = "Icon Only"
    var id: Self { self }

    // Properti baru untuk menampilkan versi yang sudah diterjemahkan
    var localized: LocalizedStringKey {
        return LocalizedStringKey(self.rawValue)
    }
}
