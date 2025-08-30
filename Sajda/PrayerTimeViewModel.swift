// MARK: - GANTI FILE: Sajda/PrayerTimeViewModel.swift (VERSI FINAL & LENGKAP)

import Foundation
import Combine
import Adhan
import CoreLocation
import SwiftUI
import AppKit

class PrayerTimeViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    // MARK: - Published Properties for UI
    @Published var menuTitle: String = "Sajda"
    @Published var todayTimes: [String: Date] = [:]
    @Published var nextPrayerName: String = ""
    @Published var countdown: String = "--:--"
    @Published var locationStatusText: String = "Preparing prayer schedule..."
    @Published var authorizationStatus: CLAuthorizationStatus
    
    // MARK: - User Settings (Persisted with @AppStorage)
    @AppStorage("showSunnahPrayers") var showSunnahPrayers: Bool = false { didSet { updatePrayerTimes() } }
    @AppStorage("useAccentColor") var useAccentColor: Bool = true
    @AppStorage("isNotificationsEnabled") var isNotificationsEnabled: Bool = true { didSet { updateNotifications() } }
    @AppStorage("useCompactLayout") var useCompactLayout: Bool = false
    @AppStorage("use24HourFormat") var use24HourFormat: Bool = false { didSet { updatePrayerTimes() } }
    @AppStorage("useHanafiMadhhab") var useHanafiMadhhab: Bool = false { didSet { updatePrayerTimes() } }
    @AppStorage("isUsingManualLocation") var isUsingManualLocation: Bool = false
    
    // Time Corrections
    @AppStorage("fajrCorrection") var fajrCorrection: Double = 0 { didSet { updatePrayerTimes() } }
    @AppStorage("dhuhrCorrection") var dhuhrCorrection: Double = 0 { didSet { updatePrayerTimes() } }
    @AppStorage("asrCorrection") var asrCorrection: Double = 0 { didSet { updatePrayerTimes() } }
    @AppStorage("maghribCorrection") var maghribCorrection: Double = 0 { didSet { updatePrayerTimes() } }
    @AppStorage("ishaCorrection") var ishaCorrection: Double = 0 { didSet { updatePrayerTimes() } }
    
    // Notification Sound Settings
    @AppStorage("adhanSound") var adhanSound: AdhanSound = .defaultBeep { didSet { updateNotifications() } }
    @AppStorage("customAdhanSoundPath") var customAdhanSoundPath: String = "" { didSet { updateNotifications() } }

    // MARK: - @Published Properties with Custom Persistence
    @Published var menuBarTextMode: MenuBarTextMode {
        didSet {
            UserDefaults.standard.set(menuBarTextMode.rawValue, forKey: "menuBarTextMode")
            updateMenuTitle()
        }
    }

    @Published var method: SajdaCalculationMethod {
        didSet {
            UserDefaults.standard.set(method.name, forKey: "calculationMethodName")
            updatePrayerTimes()
        }
    }
    
    // MARK: - Private Properties
    private var currentCoordinates: CLLocationCoordinate2D?
    private var searchCancellable: AnyCancellable?
    private let locMgr = CLLocationManager()
    private var timer: Timer?
    private var adhanPlayer: NSSound?

    // MARK: - Initializer
    override init() {
        // Load persisted settings
        let savedMethodName = UserDefaults.standard.string(forKey: "calculationMethodName")
        self.method = SajdaCalculationMethod.allCases.first { $0.name == savedMethodName } ?? SajdaCalculationMethod.allCases.first { $0.name == "Muslim World League" }!
        
        let savedTextMode = UserDefaults.standard.string(forKey: "menuBarTextMode")
        self.menuBarTextMode = MenuBarTextMode(rawValue: savedTextMode ?? "") ?? .countdown
        
        self.authorizationStatus = locMgr.authorizationStatus
        
        super.init()
        
        locMgr.delegate = self
        startLocationProcess()
        startTimer()
    }
    
    // MARK: - Location Search (Nominatim)
    func searchLocation(query: String, completion: @escaping ([LocationSearchResult]) -> Void) {
        searchCancellable?.cancel()
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            completion([])
            return
        }
        
        var components = URLComponents(string: "https://nominatim.openstreetmap.org/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "addressdetails", value: "1"),
            URLQueryItem(name: "accept-language", value: "en"),
            URLQueryItem(name: "limit", value: "10")
        ]
        
        guard let url = components.url else { completion([]); return }
        var request = URLRequest(url: url)
        request.setValue("Sajda Prayer Times App/1.0", forHTTPHeaderField: "User-Agent")

        searchCancellable = URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: [NominatimResult].self, decoder: JSONDecoder())
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .sink { results in
                let searchResults = results.compactMap { result -> LocationSearchResult? in
                    guard let lat = Double(result.lat), let lon = Double(result.lon) else { return nil }
                    let city = result.address.city ?? result.address.town ?? result.address.village ?? result.address.state ?? ""
                    let country = result.address.country ?? ""
                    guard !city.isEmpty, !country.isEmpty else { return nil }
                    return LocationSearchResult(name: city, country: country, coordinates: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                }.unique(by: \.name)
                completion(searchResults)
            }
    }
    
    private struct NominatimResult: Codable {
        let lat: String, lon: String
        let address: NominatimAddress
    }

    private struct NominatimAddress: Codable {
        let city: String?, town: String?, village: String?, state: String?, country: String?
    }
    
    // MARK: - Location Management
    func setManualLocation(city: String, coordinates: CLLocationCoordinate2D) {
        let manualLocationData: [String: Any] = ["name": city, "latitude": coordinates.latitude, "longitude": coordinates.longitude]
        UserDefaults.standard.set(manualLocationData, forKey: "manualLocationData")
        isUsingManualLocation = true
        currentCoordinates = coordinates
        locationStatusText = city
        authorizationStatus = .authorized
        updatePrayerTimes()
    }
    
    func startLocationProcess() {
        if isUsingManualLocation, let manualData = loadManualLocation() {
            currentCoordinates = manualData.coordinates
            locationStatusText = manualData.name
            DispatchQueue.main.async { self.updatePrayerTimes() }
        } else {
            handleAuthorizationStatus(status: locMgr.authorizationStatus)
        }
    }

    private func loadManualLocation() -> (name: String, coordinates: CLLocationCoordinate2D)? {
        guard let data = UserDefaults.standard.dictionary(forKey: "manualLocationData"),
              let name = data["name"] as? String,
              let lat = data["latitude"] as? CLLocationDegrees,
              let lon = data["longitude"] as? CLLocationDegrees else { return nil }
        return (name, CLLocationCoordinate2D(latitude: lat, longitude: lon))
    }
    
    func switchToAutomaticLocation() {
        isUsingManualLocation = false
        UserDefaults.standard.removeObject(forKey: "manualLocationData")
        locationStatusText = "Switching to automatic..."
        todayTimes = [:]
        currentCoordinates = nil
        handleAuthorizationStatus(status: locMgr.authorizationStatus)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard !isUsingManualLocation, let location = locs.last else { return }
        currentCoordinates = location.coordinate
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
            DispatchQueue.main.async {
                self.locationStatusText = placemarks?.first?.locality ?? "Unknown Location"
                self.updatePrayerTimes()
            }
        }
    }
    
    // MARK: - Prayer Time Calculation
    func updatePrayerTimes() {
        guard let coord = currentCoordinates else { return }
        let cal = Calendar(identifier: .gregorian)
        var params = method.params
        params.madhab = self.useHanafiMadhhab ? .hanafi : .shafi
        let today = Date()
        
        let todayDC = cal.dateComponents([.year, .month, .day], from: today)
        guard let prayersToday = PrayerTimes(coordinates: Coordinates(latitude: coord.latitude, longitude: coord.longitude), date: todayDC, calculationParameters: params),
              let tomorrowDate = cal.date(byAdding: .day, value: 1, to: today),
              let prayersTomorrow = PrayerTimes(coordinates: Coordinates(latitude: coord.latitude, longitude: coord.longitude), date: cal.dateComponents([.year, .month, .day], from: tomorrowDate), calculationParameters: params) else { return }
        
        let correctedFajr = prayersToday.fajr.addingTimeInterval(fajrCorrection * 60)
        let correctedDhuhr = prayersToday.dhuhr.addingTimeInterval(dhuhrCorrection * 60)
        let correctedAsr = prayersToday.asr.addingTimeInterval(asrCorrection * 60)
        let correctedMaghrib = prayersToday.maghrib.addingTimeInterval(maghribCorrection * 60)
        let correctedIsha = prayersToday.isha.addingTimeInterval(ishaCorrection * 60)
        let correctedFajrTomorrow = prayersTomorrow.fajr.addingTimeInterval(fajrCorrection * 60)
        
        var allPrayerTimes: [(name: String, time: Date)] = [
            ("Fajr", correctedFajr), ("Dhuhr", correctedDhuhr), ("Asr", correctedAsr),
            ("Maghrib", correctedMaghrib), ("Isha", correctedIsha)
        ]
        
        if showSunnahPrayers {
            let nightDuration = correctedFajrTomorrow.timeIntervalSince(correctedIsha)
            let lastThirdOfNightStart = correctedIsha.addingTimeInterval(nightDuration * (2/3.0))
            allPrayerTimes.append(("Tahajud", lastThirdOfNightStart))
            
            let dhuhaTime = prayersToday.sunrise.addingTimeInterval(20 * 60)
            allPrayerTimes.append(("Dhuha", dhuhaTime))
        }
        
        allPrayerTimes.sort { $0.time < $1.time }
        let nextPrayer = allPrayerTimes.first { $0.time > today }
        
        DispatchQueue.main.async {
            self.todayTimes = Dictionary(uniqueKeysWithValues: allPrayerTimes.map { ($0.name, $0.time) })
            if let nextPrayer = nextPrayer { self.nextPrayerName = nextPrayer.name } else { self.recalculateForTomorrow(); return }
            self.updateCountdown()
            self.updateNotifications()
        }
    }
    
    private func recalculateForTomorrow() {
        guard let coord = currentCoordinates else { return }
        let cal = Calendar(identifier: .gregorian)
        var params = method.params
        params.madhab = useHanafiMadhhab ? .hanafi : .shafi
        guard let tomorrowDate = cal.date(byAdding: .day, value: 1, to: Date()),
              let prayersTomorrow = PrayerTimes(coordinates: Coordinates(latitude: coord.latitude, longitude: coord.longitude), date: cal.dateComponents([.year, .month, .day], from: tomorrowDate), calculationParameters: params) else { return }

        DispatchQueue.main.async {
            self.nextPrayerName = "Fajr"
            self.updatePrayerTimes()
        }
    }

    // MARK: - UI Updates & Notifications
    private func updateCountdown() {
        guard !nextPrayerName.isEmpty, let nextDate = todayTimes[nextPrayerName] else {
            countdown = "--:--"; updateMenuTitle(); return
        }
        let diff = Int(nextDate.timeIntervalSince(Date()))
        if diff > 0 {
            let h = diff / 3600; let m = (diff % 3600) / 60
            countdown = h > 0 ? String(format: "%dh %dm", h, m + 1) : String(format: "%dm", m + 1)
        } else {
            countdown = "Now"
            if adhanSound == .custom, let soundPath = customAdhanSoundPath.removingPercentEncoding, let soundURL = URL(string: soundPath), FileManager.default.fileExists(atPath: soundURL.path) {
                adhanPlayer = NSSound(contentsOf: soundURL, byReference: true)
                adhanPlayer?.play()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.updatePrayerTimes() }
        }
        updateMenuTitle()
    }
    
    func updateMenuTitle() {
        var textToShow = ""; if !isPrayerDataAvailable { textToShow = "Sajda" }
        else {
            switch menuBarTextMode {
            case .hidden: textToShow = ""
            case .countdown: textToShow = "\(nextPrayerName) in \(countdown)"
            case .exactTime: if let nextDate = todayTimes[nextPrayerName] { textToShow = "\(nextPrayerName) at \(dateFormatter.string(from: nextDate))" } else { textToShow = "Sajda" }
            }
        }
        self.menuTitle = textToShow
    }

    private func updateNotifications() {
        guard isNotificationsEnabled, !todayTimes.isEmpty else { NotificationManager.cancelNotifications(); return }
        NotificationManager.requestPermission()
        let prayerOrder = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
        NotificationManager.scheduleNotifications(for: todayTimes, prayerOrder: prayerOrder, adhanSound: self.adhanSound, customSoundPath: self.customAdhanSoundPath)
    }

    // MARK: - User Actions
    func selectCustomAdhanSound() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = [.audio]
        if openPanel.runModal() == .OK {
            self.customAdhanSoundPath = openPanel.url?.absoluteString ?? ""
        }
    }
    
    // MARK: - Helpers & Delegate Methods
    var isPrayerDataAvailable: Bool { !todayTimes.isEmpty }
    func startTimer() { timer?.invalidate(); timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.updateCountdown() } }
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter(); formatter.timeStyle = .short
        formatter.locale = use24HourFormat ? Locale(identifier: "en_GB") : Locale(identifier: "en_US")
        return formatter
    }
    
    private func handleAuthorizationStatus(status: CLAuthorizationStatus) {
        self.authorizationStatus = status
        switch status {
        case .authorized: locationStatusText = "Fetching location..."; locMgr.requestLocation()
        case .denied, .restricted: locationStatusText = "Location access denied."; todayTimes = [:]
        case .notDetermined: locMgr.requestWhenInUseAuthorization()
        @unknown default: break
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if !isUsingManualLocation { handleAuthorizationStatus(status: manager.authorizationStatus) }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.locationStatusText = "Unable to determine location."
    }
    
    func requestLocationPermission() { if authorizationStatus == .notDetermined { locMgr.requestWhenInUseAuthorization() } }
    
    func openLocationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") else { return }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Extensions
extension Sequence {
    func unique<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        var set = Set<T>()
        return filter { set.insert($0[keyPath: keyPath]).inserted }
    }
}
