// MARK: - BUAT FILE BARU: Sajda/MenuBarTextMode.swift
// Salin dan tempel SELURUH kode ini ke dalam file baru.

import Foundation

enum MenuBarTextMode: String, CaseIterable, Identifiable {
    case countdown = "Countdown"
    case exactTime = "Exact Time"
    case hidden = "Icon Only"
    var id: Self { self }
}
