// MARK: - BUAT FILE BARU: Sajda/AdhanSound.swift
// Salin dan tempel SELURUH kode ini ke dalam file baru.

import Foundation

enum AdhanSound: String, CaseIterable, Identifiable {
    case none = "None"
    case defaultBeep = "Default Beep"
    case custom = "Custom Sound"
    var id: Self { self }
}
