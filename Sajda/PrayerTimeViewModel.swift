// Salin dan tempel seluruh kode ini ke dalam file PrayerTimeViewModel.swift

import Foundation
import Combine
import Adhan
import CoreLocation
import SwiftUI

// Enum untuk preferensi gaya menu bar
enum MenuBarStyle: String, CaseIterable, Identifiable {
    case countdown = "Countdown with Icon"
    case exactTime = "Exact Time with Icon"
    case iconOnly = "Icon Only"
    case countdownTextOnly = "Countdown (Text Only)"
    case exactTimeTextOnly = "Exact Time (Text Only)"
    
    var id: Self { self }
    
    var showsIcon: Bool {
        switch self {
        case .countdown, .exactTime, .iconOnly:
            return true
        case .countdownTextOnly, .exactTimeTextOnly:
            return false
        }
    }
}

// Enum untuk preferensi format waktu
enum TimeFormat: String, CaseIterable, Identifiable {
    case h12 = "12-Hour"
    case h24 = "24-Hour"
    var id: Self { self }
}

class PrayerTimeViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    // Properti untuk UI
    @Published var menuTitle: String = "Sajda"
    @Published var todayTimes: [String: Date] = [:]
    @Published var nextPrayerName: String = ""
    @Published var countdown: String = "--:--"
    
    // Properti untuk Pengaturan Pengguna
    @Published var isNotificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isNotificationsEnabled, forKey: "isNotificationsEnabled")
            if isNotificationsEnabled {
                NotificationManager.requestPermission()
                schedulePrayerNotifications()
            } else {
                NotificationManager.cancelNotifications()
            }
        }
    }
    @Published var isMonochrome: Bool {
        didSet {
            UserDefaults.standard.set(isMonochrome, forKey: "isMonochrome")
        }
    }
    @Published var menuBarStyle: MenuBarStyle {
        didSet {
            UserDefaults.standard.set(menuBarStyle.rawValue, forKey: "menuBarStyle")
            updateMenuTitle()
        }
    }
    @Published var timeFormat: TimeFormat {
        didSet {
            UserDefaults.standard.set(timeFormat.rawValue, forKey: "timeFormat")
            updateMenuTitle()
        }
    }
    @Published var method: CalculationMethod {
        didSet {
            UserDefaults.standard.set(method.rawValue, forKey: "calculationMethod")
            updatePrayerTimes()
        }
    }
    @Published var madhab: Madhab {
        didSet {
            UserDefaults.standard.set(madhab.rawValue, forKey: "madhab")
            updatePrayerTimes()
        }
    }
    
    // Properti untuk Core Location
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var timeZoneIdentifier: String = ""
    @Published var manualLocation: CLLocationCoordinate2D?
    
    private let locMgr = CLLocationManager()
    private var timer: Timer?

    override init() {
        // Muat semua pengaturan dari UserDefaults saat inisialisasi
        self.isNotificationsEnabled = UserDefaults.standard.bool(forKey: "isNotificationsEnabled")
        self.isMonochrome = UserDefaults.standard.bool(forKey: "isMonochrome")
        self.menuBarStyle = MenuBarStyle(rawValue: UserDefaults.standard.string(forKey: "menuBarStyle") ?? "") ?? .countdown
        self.timeFormat = TimeFormat(rawValue: UserDefaults.standard.string(forKey: "timeFormat") ?? "") ?? .h12
        self.method = CalculationMethod(rawValue: UserDefaults.standard.string(forKey: "calculationMethod") ?? "karachi") ?? .karachi
        self.madhab = Madhab(rawValue: UserDefaults.standard.integer(forKey: "madhab")) ?? .shafi
        self.authorizationStatus = locMgr.authorizationStatus
        
        super.init()
        
        locMgr.delegate = self
        handleAuthorizationStatus(status: locMgr.authorizationStatus)
        startTimer()
        updateMenuTitle()
    }
    
    // Formatter tanggal yang dinamis
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = timeFormat == .h12 ? Locale(identifier: "en_US") : Locale(identifier: "en_GB")
        return formatter
    }

    // Fungsi untuk menangani perubahan status izin lokasi
    private func handleAuthorizationStatus(status: CLAuthorizationStatus) {
        self.authorizationStatus = status
        switch status {
        case .authorized:
            locMgr.requestLocation()
            timeZoneIdentifier = "Fetching location..."
        case .denied, .restricted:
            timeZoneIdentifier = "Location access has been denied."
            menuTitle = "Location needed"
        case .notDetermined:
            timeZoneIdentifier = "Please grant location access."
            menuTitle = "Location needed"
        @unknown default:
            break
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        handleAuthorizationStatus(status: manager.authorizationStatus)
    }
    
    // Fungsi saat lokasi berhasil didapatkan
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        if let location = locs.last {
            manualLocation = location.coordinate
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Geocoder error: \(error.localizedDescription)")
                        self.timeZoneIdentifier = "Error: Cannot get timezone."
                        return
                    }
                    if let timezone = placemarks?.first?.timeZone {
                        self.timeZoneIdentifier = timezone.identifier
                    } else {
                        self.timeZoneIdentifier = TimeZone.current.identifier
                    }
                    self.updatePrayerTimes()
                }
            }
        }
    }
    
    // Fungsi saat lokasi gagal didapatkan
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to get location: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.timeZoneIdentifier = "Failed to get location."
            self.menuTitle = "Location Error"
        }
    }
    
    // Fungsi untuk meminta izin lokasi dari UI
    func requestLocationPermission() {
        if authorizationStatus == .notDetermined {
            locMgr.requestWhenInUseAuthorization()
        }
    }
    
    // Fungsi untuk memperbarui jadwal sholat
    func updatePrayerTimes() {
        guard let coord = manualLocation else { return }
        let cal = Calendar(identifier: .gregorian)
        let dc = cal.dateComponents([.year, .month, .day], from: Date())
        var params = method.params
        params.madhab = self.madhab
        
        if let prayers = PrayerTimes(coordinates: Coordinates(latitude: coord.latitude, longitude: coord.longitude), date: dc, calculationParameters: params) {
            let names = ["Fajr": prayers.fajr, "Dhuhr": prayers.dhuhr, "Asr": prayers.asr, "Maghrib": prayers.maghrib, "Isha": prayers.isha]
            DispatchQueue.main.async {
                self.todayTimes = names
                if let next = prayers.nextPrayer() {
                    self.nextPrayerName = "\(next)".capitalized
                } else {
                    self.nextPrayerName = "Done"
                }
                self.updateCountdown()
                self.schedulePrayerNotifications()
            }
        }
    }
    
    // Fungsi untuk menjadwalkan notifikasi
    private func schedulePrayerNotifications() {
        guard isNotificationsEnabled, !todayTimes.isEmpty else { return }
        let prayerOrder = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
        NotificationManager.scheduleNotifications(for: todayTimes, prayerOrder: prayerOrder)
    }
    
    // Fungsi untuk memulai dan menghentikan timer
    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateCountdown()
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
    }
    
    // Fungsi untuk me-refresh lokasi secara manual
    func requestLocationUpdate() {
        if locMgr.authorizationStatus == .authorized {
            locMgr.requestLocation()
        }
    }

    // Fungsi untuk menghitung mundur
    private func updateCountdown() {
        guard !nextPrayerName.isEmpty, nextPrayerName != "Done", let nextDate = todayTimes[nextPrayerName] else {
            countdown = "--:--"
            updateMenuTitle()
            return
        }
        
        let diff = Int(nextDate.timeIntervalSince(Date()))
        if diff > 0 {
            let h = diff / 3600
            let m = (diff % 3600) / 60
            
            if h > 0 {
                countdown = String(format: "%dh %dm", h, m + 1)
            } else {
                countdown = String(format: "%dm", m + 1)
            }
        } else {
            countdown = "Now"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.updatePrayerTimes()
            }
        }
        updateMenuTitle()
    }

    // Fungsi untuk memperbarui teks di menu bar
    private func updateMenuTitle() {
        if todayTimes.isEmpty {
            menuTitle = "Sajda"
            return
        }
        
        switch menuBarStyle {
        case .iconOnly:
            menuTitle = ""
        case .countdown, .countdownTextOnly:
            if nextPrayerName.isEmpty || nextPrayerName == "Done" {
                menuTitle = "Prayers done"
            } else {
                menuTitle = "\(nextPrayerName) in \(countdown)"
            }
        case .exactTime, .exactTimeTextOnly:
            if !nextPrayerName.isEmpty, nextPrayerName != "Done", let nextDate = todayTimes[nextPrayerName] {
                menuTitle = "\(nextPrayerName) at \(dateFormatter.string(from: nextDate))"
            } else {
                menuTitle = "Prayers done"
            }
        }
    }
}
