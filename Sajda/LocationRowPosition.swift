// MARK: - Sajda/LocationRowPosition.swift
//
// Posisi baris lokasi (nama masjid / kota) di panel utama.

import Foundation
import SwiftUI

/// Letak baris lokasi di panel utama. Tiga pilihan karena trade-off-nya nyata:
/// di atas garis pemisah baris ini menjadi "kepala" panel, di bawahnya baris ini
/// menjadi keterangan isi panel, dan di bawah daftar shalat baris ini menjadi
/// penutup. Semua état tersimpan lewat `PrayerTimeViewModel.locationRowPosition`
/// (@AppStorage "locationRowPosition") — nilai String, jadi enum ini harus tetap
/// RawRepresentable dengan String dan CaseIterable agar bisa dipakai
/// ScaledMenuPicker.
enum LocationRowPosition: String, CaseIterable, Identifiable {
    /// Di atas garis pemisah, tepat di bawah judul "Sajda".
    case top = "Top"
    /// Di bawah garis pemisah, di atas kartu hitung mundur dan daftar shalat.
    case middle = "Below Divider"
    /// Di bawah daftar shalat, dengan pemisah sendiri di atasnya.
    case bottom = "Below Prayer Times"

    var id: Self { self }

    /// Label dropdown yang sudah diterjemahkan.
    var localized: LocalizedStringKey {
        return LocalizedStringKey(self.rawValue)
    }

    /// Posisi paling bawah memakai pemisah tambahan supaya tidak menempel pada
    /// waktu shalat terakhir — lihat `MainView`.
    var needsOwnDivider: Bool { self == .bottom }
}
