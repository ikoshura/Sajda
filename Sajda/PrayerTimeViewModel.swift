// Ganti seluruh kode di PrayerTimeViewModel.swift dengan ini

import Foundation
import Combine
import Adhan
import CoreLocation
import SwiftUI

// FIX: Enum sekarang diisi dengan case yang benar
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

// FIX: Enum sekarang diisi dengan case yang benar
enum TimeFormat: String, CaseIterable, Identifiable {
    case h12 = "12-Hour"
    case h24 = "24-Hour"
    var id: Self { self }
}

class PrayerTimeViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var menuTitle: String = "Sajda"
    @Published var todayTimes: [String: Date] = [:]
    @Published var nextPrayerName: String = ""
    @Published var countdown: String = "--:--"
    
    @Published var isNotificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(isNotificationsEnabled, forKey: "isNotificationsEnabled"); if isNotificationsEnabled { NotificationManager.requestPermission(); schedulePrayerNotifications() } else { NotificationManager.cancelNotifications() } }
    }
    @Published var isMonochrome: Bool { didSet { UserDefaults.standard.set(isMonochrome, forKey: "isMonochrome") } }
    @Published var menuBarStyle: MenuBarStyle { didSet { UserDefaults.standard.set(menuBarStyle.rawValue, forKey: "menuBarStyle"); updateMenuTitle() } }
    @Published var timeFormat: TimeFormat { didSet { UserDefaults.standard.set(timeFormat.rawValue, forKey: "timeFormat"); updateMenuTitle() } }
    
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var timeZoneIdentifier: String = ""
    @Published var method: CalculationMethod = .karachi
    @Published var madhhab: Madhab = .shafi
    @Published var manualLocation: CLLocationCoordinate2D?
    private let locMgr = CLLocationManager()
    private var timer: Timer?

    override init() {
        self.isNotificationsEnabled = UserDefaults.standard.bool(forKey: "isNotificationsEnabled")
        self.isMonochrome = UserDefaults.standard.bool(forKey: "isMonochrome")
        let savedStyle = UserDefaults.standard.string(forKey: "menuBarStyle"); self.menuBarStyle = MenuBarStyle(rawValue: savedStyle ?? "") ?? .countdown
        let savedFormat = UserDefaults.standard.string(forKey: "timeFormat"); self.timeFormat = TimeFormat(rawValue: savedFormat ?? "") ?? .h12
        self.authorizationStatus = locMgr.authorizationStatus
        super.init()
        locMgr.delegate = self
        handleAuthorizationStatus(status: locMgr.authorizationStatus)
        startTimer()
        updateMenuTitle()
    }
    
    private func schedulePrayerNotifications() {
        guard isNotificationsEnabled, !todayTimes.isEmpty else { return }
        let prayerOrder = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
        NotificationManager.scheduleNotifications(for: todayTimes, prayerOrder: prayerOrder)
    }

    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = timeFormat == .h12 ? Locale(identifier: "en_US") : Locale(identifier: "en_GB")
        return formatter
    }

    private func handleAuthorizationStatus(status: CLAuthorizationStatus) {
        self.authorizationStatus = status
        switch status {
        case .authorized: locMgr.requestLocation(); timeZoneIdentifier = "Fetching location..."
        case .denied, .restricted: timeZoneIdentifier = "Location access has been denied."; menuTitle = "Location needed"
        case .notDetermined: timeZoneIdentifier = "Please grant location access."; menuTitle = "Location needed"
        @unknown default: break
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { handleAuthorizationStatus(status: manager.authorizationStatus) }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        if let location = locs.last {
            manualLocation = location.coordinate
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
                DispatchQueue.main.async {
                    if let error = error { print("Geocoder error: \(error.localizedDescription)"); self.timeZoneIdentifier = "Error: Cannot get timezone."; return }
                    if let timezone = placemarks?.first?.timeZone { self.timeZoneIdentifier = timezone.identifier } else { self.timeZoneIdentifier = TimeZone.current.identifier }
                    self.updatePrayerTimes()
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to get location: \(error.localizedDescription)")
        DispatchQueue.main.async { self.timeZoneIdentifier = "Failed to get location."; self.menuTitle = "Location Error" }
    }
    
    func requestLocationPermission() { if authorizationStatus == .notDetermined { locMgr.requestWhenInUseAuthorization() } }
    
    func updatePrayerTimes() {
        guard let coord = manualLocation else { return }
        let cal = Calendar(identifier: .gregorian); let dc = cal.dateComponents([.year, .month, .day], from: Date()); var params = method.params; params.madhab = self.madhhab
        if let prayers = PrayerTimes(coordinates: Coordinates(latitude: coord.latitude, longitude: coord.longitude), date: dc, calculationParameters: params) {
            let names = ["Fajr": prayers.fajr, "Dhuhr": prayers.dhuhr, "Asr": prayers.asr, "Maghrib": prayers.maghrib, "Isha": prayers.isha]
            DispatchQueue.main.async {
                self.todayTimes = names
                if let next = prayers.nextPrayer() { self.nextPrayerName = "\(next)".capitalized } else { self.nextPrayerName = "Done" }
                self.updateCountdown()
                self.schedulePrayerNotifications()
            }
        }
    }
    
    func startTimer() { timer?.invalidate(); timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.updateCountdown() } }
    
    func stopTimer() { timer?.invalidate() }
    
    func requestLocationUpdate() { if locMgr.authorizationStatus == .authorized { locMgr.requestLocation() } }

    private func updateCountdown() {
        guard !nextPrayerName.isEmpty, nextPrayerName != "Done", let nextDate = todayTimes[nextPrayerName] else {
            countdown = "--:--"
            updateMenuTitle()
            return
        }
        
        let diff = Int(nextDate.timeIntervalSince(Date()))
        if diff > 0 {
            let h = diff / 3600; let m = (diff % 3600) / 60
            if h > 0 { countdown = String(format: "%dh %dm", h, m + 1) } else { countdown = String(format: "%dm", m + 1) }
        } else {
            countdown = "Now"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.updatePrayerTimes() }
        }
        updateMenuTitle()
    }

    private func updateMenuTitle() {
        var textToShow = ""
        if todayTimes.isEmpty {
            textToShow = "Sajda"
        } else {
            switch menuBarStyle {
            case .iconOnly:
                textToShow = ""
            case .countdown, .countdownTextOnly:
                if nextPrayerName.isEmpty || nextPrayerName == "Done" { textToShow = "Prayers done" } else { textToShow = "\(nextPrayerName) in \(countdown)" }
            case .exactTime, .exactTimeTextOnly:
                if !nextPrayerName.isEmpty, nextPrayerName != "Done", let nextDate = todayTimes[nextPrayerName] { textToShow = "\(nextPrayerName) at \(dateFormatter.string(from: nextDate))" } else { textToShow = "Prayers done" }
            }
        }
        
        // Perbarui properti dan panggil controller
        self.menuTitle = textToShow
        PopoverController.shared.updateStatusItemTitle(with: textToShow, showIcon: menuBarStyle.showsIcon)
    }
}
