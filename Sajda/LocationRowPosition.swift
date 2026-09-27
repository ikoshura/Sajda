// MARK: - Sajda/LocationRowPosition.swift
//
// Posisi baris lokasi (nama masjid / kota) di panel utama.

import Foundation
import SwiftUI

/// Letak jeda iqama ("+8") relatif terhadap waktu shalat di panel utama.
/// Tiga pilihan, bukan sekadar on/off: sisi kiri menyisakan kolom waktu tetap
/// menempel tepi kanan, sisi kanan membacanya sebagai satu rangkaian waktu
/// ("13:53 +8"), dan "None" mematikan tampilannya sama sekali.
///
/// RawRepresentable dengan String + CaseIterable supaya bisa dipakai
/// ScaledMenuPicker, dan supaya nilai yang tidak dikenal (versi app yang lebih
/// baru, atau prefs yang rusak) jatuh ke `rawValue` fallback di
/// `PrayerTimeViewModel.iqamaDelayPosition` alih-alih membuat panel gagal.
enum IqamaDelayPosition: String, CaseIterable, Identifiable {
    /// Tidak ditampilkan sama sekali.
    case none = "None"
    /// Di kiri waktu shalat, tepat di setelah tombol mute.
    case leading = "Left"
    /// Di kanan waktu shalat, di tepi baris.
    case trailing = "Right"

    var id: Self { self }

    /// Label dropdown yang sudah diterjemahkan.
    var localized: LocalizedStringKey {
        LocalizedStringKey(self.rawValue)
    }
}

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

    /// Kunci lokalisasi untuk label picker — "Top" / "Middle" / "Bottom".
    ///
    /// Dipisah dari `rawValue` dengan sengaja: `rawValue` adalah nilai yang
    /// disimpan di UserDefaults, jadi menamainya ulang akan mengembalikan
    /// pengguna lama ke posisi default. Label picker boleh berubah tanpa
    /// menyentuh nilai yang tersimpan.
    var labelKey: String {
        switch self {
        case .top: return "Top"
        case .middle: return "Middle"
        case .bottom: return "Bottom"
        }
    }

    /// Label picker yang sudah diterjemahkan.
    var localized: LocalizedStringKey { LocalizedStringKey(labelKey) }

    /// Posisi paling bawah memakai pemisah tambahan supaya tidak menempel pada
    /// waktu shalat terakhir — lihat `MainView`.
    var needsOwnDivider: Bool { self == .bottom }
}

/// Bentuk ikon mute per-variasi di panel utama. Empat pilihan karena ketiga
/// glyph yang ada punya tradeoff nyata, dan sebagian pengguna tidak suka adegan
/// ikon di baris shalat sama sekali.
///
/// "Halo" (default) — cincin + titik, sesuai acuan modern. Paling netral dan
/// paling kecil, tapi tidak langsung terbaca sebagai "suara".
/// "Bell" — gambar paling langsung untuk adhan, dan paling tegas; juga yang
/// paling berebut perhatian dengan waktu shalat di sebelahnya.
/// "Speaker" — sama dengan ikon di halaman Adhan Sound, jadi keduanya konsisten
/// satu bahasa ikon.
/// "None" — tidak ada kontrol sama sekali. Barisnya bukan tombol yang tidak
/// terlihat: tidak bisa diklik, difokus, atau diumumkan, jadi panelnya benar-
/// benar hanya jam. Mute masih bisa diubah dari halaman Adhan Sound.
///
/// RawRepresentable dengan String + CaseIterable supaya bisa dipakai
/// ScaledMenuPicker, dan supaya nilai yang tidak dikenal (versi app yang lebih
/// baru, atau prefs yang rusak) jatuh ke `rawValue` fallback di
/// `PrayerTimeViewModel.muteIconStyle` alih-alih membuat panel gagal.
enum MuteIconStyle: String, CaseIterable, Identifiable {
    /// Cincin + titik — ikon mute bawaan.
    case halo = "Halo"
    /// Lonceng: adhan berbunyi, dan tidak bisu.
    case bell = "Bell"
    /// Speaker: sama persis dengan ikon di halaman Adhan Sound.
    case speaker = "Speaker"
    /// Tidak ada ikon sama sekali; barisnya tetap bisa diklik.
    case none = "None"

    var id: Self { self }

    /// Kunci lokalisasi untuk label picker.
    var labelKey: String {
        switch self {
        case .halo: return "Halo"
        case .bell: return "Bell"
        case .speaker: return "Speaker"
        case .none: return "None"
        }
    }

    /// Label picker yang sudah diterjemahkan.
    var localized: LocalizedStringKey { LocalizedStringKey(labelKey) }

    /// Whether the style is drawn as an outline rather than a filled glyph.
    /// Only the halo is: a stroked ring and dot need a stroke colour, while the
    /// bell and speaker are filled SF Symbols. `.none` draws nothing at all.
    var isOutlined: Bool { self == .halo }
}
