// MARK: - GANTI SELURUH FILE: PrayerTimeViewModel.swift (KODE LENGKAP & PERBAIKAN STARTUP)

import Foundation
import Combine
import Adhan
import CoreLocation
import SwiftUI
import AppKit

@propertyWrapper
struct FlexibleDouble: Codable, Equatable, Hashable {
    var wrappedValue: Double
    init(wrappedValue: Double) { self.wrappedValue = wrappedValue }
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let doubleValue = try? container.decode(Double.self) {
            wrappedValue = doubleValue
        } else if let stringValue = try? container.decode(String.self), let doubleValue = Double(stringValue) {
            wrappedValue = doubleValue
        } else {
            throw DecodingError.typeMismatch(Double.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected Double or String representing Double"))
        }
    }
}

class PrayerTimeViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var menuTitle: NSAttributedString = NSAttributedString(string: "Sajda Pro")
    @Published var todayTimes: [String: Date] = [:]
    @Published var nextPrayerName: String = ""
    @Published var countdown: String = "--:--"
    @Published var locationStatusText: String = "Preparing prayer schedule..."
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var locationSearchQuery: String = ""
    @Published var locationSearchResults: [LocationSearchResult] = []
    @Published var isLocationSearching: Bool = false
    @Published var locationInfoText: String = ""
    @Published var isPrayerImminent: Bool = false
    @Published var isRequestingLocation: Bool = false

    private let languageManager = LanguageManager()
    private var automaticLocationCache: (name: String, coordinates: CLLocationCoordinate2D)?
    private var tomorrowFajrTime: Date?

    @AppStorage("useMinimalMenuBarText") var useMinimalMenuBarText: Bool = false { didSet { updateAndDisplayTimes() } }
    @AppStorage("showSunnahPrayers") var showSunnahPrayers: Bool = false { didSet { updatePrayerTimes() } }
    @AppStorage("useAccentColor") var useAccentColor: Bool = true
    @AppStorage("isNotificationsEnabled") var isNotificationsEnabled: Bool = true { didSet { updateNotifications() } }
    @AppStorage("useCompactLayout") var useCompactLayout: Bool = false
    @AppStorage("use24HourFormat") var use24HourFormat: Bool = false { didSet { updateAndDisplayTimes() } }
    @AppStorage("useHanafiMadhhab") var useHanafiMadhhab: Bool = false { didSet { updatePrayerTimes() } }
    @AppStorage("isUsingManualLocation") var isUsingManualLocation: Bool = false
    @AppStorage("fajrCorrection") var fajrCorrection: Double = 0 { didSet { updatePrayerTimes() } }
    @AppStorage("dhuhrCorrection") var dhuhrCorrection: Double = 0 { didSet { updatePrayerTimes() } }
    @AppStorage("asrCorrection") var asrCorrection: Double = 0 { didSet { updatePrayerTimes() } }
    @AppStorage("maghribCorrection") var maghribCorrection: Double = 0 { didSet { updatePrayerTimes() } }
    @AppStorage("ishaCorrection") var ishaCorrection: Double = 0 { didSet { updatePrayerTimes() } }
    @AppStorage("adhanSound") var adhanSound: AdhanSound = .defaultBeep { didSet { updateNotifications() } }
    @AppStorage("customAdhanSoundPath") var customAdhanSoundPath: String = "" { didSet { updateNotifications() } }

    @Published var menuBarTextMode: MenuBarTextMode {
        didSet {
            UserDefaults.standard.set(menuBarTextMode.rawValue, forKey: "menuBarTextMode")
            if menuBarTextMode == .hidden { useMinimalMenuBarText = false }
            updateMenuTitle()
        }
    }
    
    @Published var method: SajdaCalculationMethod { didSet { UserDefaults.standard.set(method.name, forKey: "calculationMethodName"); updatePrayerTimes() } }
    private var currentCoordinates: CLLocationCoordinate2D?
    private var cancellables = Set<AnyCancellable>()
    private let locMgr = CLLocationManager()
    private var timer: Timer?
    private var adhanPlayer: NSSound?
    private var locationTimeZone: TimeZone = .current
    private var locationDisplayTimer: Timer?

    override init() {
        let savedMethodName = UserDefaults.standard.string(forKey: "calculationMethodName") ?? "Muslim World League"
        self.method = SajdaCalculationMethod.allCases.first { $0.name == savedMethodName } ?? .allCases[0]
        let savedTextMode = UserDefaults.standard.string(forKey: "menuBarTextMode")
        self.menuBarTextMode = MenuBarTextMode(rawValue: savedTextMode ?? "") ?? .countdown
        self.authorizationStatus = locMgr.authorizationStatus
        super.init()
        locMgr.delegate = self
        startTimer()
        setupSearchPublisher()
    }
    
    private struct NominatimResult: Codable, Hashable {
        @FlexibleDouble var lat: Double; @FlexibleDouble var lon: Double
        let display_name: String; let address: NominatimAddress
    }

    private struct NominatimAddress: Codable, Hashable {
        let city: String?, town: String?, village: String?, state: String?, county: String?, country: String?
    }
    
    private func setupSearchPublisher() { $locationSearchQuery.debounce(for: .milliseconds(400), scheduler: RunLoop.main).removeDuplicates().handleEvents(receiveOutput: { [weak self] query in let trimmedQuery = query.trimmingCharacters(in: .whitespaces); self?.isLocationSearching = !trimmedQuery.isEmpty; if trimmedQuery.isEmpty { self?.locationSearchResults = [] } }).flatMap { [weak self] query -> AnyPublisher<[LocationSearchResult], Never> in guard let self = self else { return Just([]).eraseToAnyPublisher() }; let trimmedQuery = query.trimmingCharacters(in: .whitespaces); guard !trimmedQuery.isEmpty else { return Just([]).eraseToAnyPublisher() }; if let coordResult = self.parseCoordinates(from: trimmedQuery) { return Just([coordResult]).eraseToAnyPublisher() }; var components = URLComponents(string: "https://nominatim.openstreetmap.org/search")!; components.queryItems = [URLQueryItem(name: "q", value: trimmedQuery), URLQueryItem(name: "format", value: "json"), URLQueryItem(name: "addressdetails", value: "1"), URLQueryItem(name: "accept-language", value: "en"), URLQueryItem(name: "limit", value: "15")]; guard let url = components.url else { return Just([]).eraseToAnyPublisher() }; var request = URLRequest(url: url); request.setValue("Sajda Pro Prayer Times App/1.0", forHTTPHeaderField: "User-Agent"); return URLSession.shared.dataTaskPublisher(for: request).map(\.data).decode(type: [NominatimResult].self, decoder: JSONDecoder()).catch { error -> Just<[NominatimResult]> in print("🔴 DECODING ERROR: \(error)"); return Just([]) }.map { results -> [LocationSearchResult] in results.unique(by: \.display_name).compactMap { result -> LocationSearchResult? in let name = result.address.city ?? result.address.town ?? result.address.village ?? result.address.county ?? result.address.state ?? ""; let country = result.address.country ?? ""; guard !country.isEmpty else { return nil }; let finalName = name.isEmpty ? result.display_name.components(separatedBy: ",")[0] : name; return LocationSearchResult(name: finalName, country: country, coordinates: CLLocationCoordinate2D(latitude: result.lat, longitude: result.lon)) } }.eraseToAnyPublisher() }.receive(on: DispatchQueue.main).sink { [weak self] results in self?.isLocationSearching = false; self?.locationSearchResults = results }.store(in: &cancellables) }
    private func parseCoordinates(from string: String) -> LocationSearchResult? { let cleaned = string.replacingOccurrences(of: " ", with: ""); let components = cleaned.split(separator: ",").compactMap { Double($0) }; guard components.count == 2, let lat = components.first, let lon = components.last, (lat >= -90 && lat <= 90) && (lon >= -180 && lon <= 180) else { return nil }; return LocationSearchResult(name: "Custom Coordinate", country: String(format: "%.4f, %.4f", lat, lon), coordinates: CLLocationCoordinate2D(latitude: lat, longitude: lon)) }
    func setManualLocation(city: String, coordinates: CLLocationCoordinate2D) { let location = CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude); self.locationTimeZone = TimeZoneLocate.timeZoneWithLocation(location); var locationNameToSave = city; if city == "Custom Coordinate" { let geocoder = CLGeocoder(); geocoder.reverseGeocodeLocation(location) { (placemarks, _) in if let placemark = placemarks?.first, let cityName = placemark.locality { locationNameToSave = cityName; self.locationStatusText = cityName; let manualData: [String: Any] = ["name": locationNameToSave, "latitude": coordinates.latitude, "longitude": coordinates.longitude]; UserDefaults.standard.set(manualData, forKey: "manualLocationData") } else { self.locationStatusText = String(format: "Coord: %.2f, %.2f", coordinates.latitude, coordinates.longitude) } } } else { self.locationStatusText = city }; let manualLocationData: [String: Any] = ["name": locationNameToSave, "latitude": coordinates.latitude, "longitude": coordinates.longitude]; UserDefaults.standard.set(manualLocationData, forKey: "manualLocationData"); isUsingManualLocation = true; currentCoordinates = coordinates; authorizationStatus = .authorized; locationSearchQuery = ""; locationSearchResults = []; updateAndDisplayTimes() }
    
    func startLocationProcess() {
        if isUsingManualLocation, let manualData = loadManualLocation() {
            currentCoordinates = manualData.coordinates
            locationStatusText = manualData.name
            let location = CLLocation(latitude: manualData.coordinates.latitude, longitude: manualData.coordinates.longitude)
            self.locationTimeZone = TimeZoneLocate.timeZoneWithLocation(location)
            self.authorizationStatus = .authorized
            DispatchQueue.main.async {
                self.updateAndDisplayTimes()
            }
        } else {
            self.locationTimeZone = .current
            handleAuthorizationStatus(status: locMgr.authorizationStatus)
        }
    }
    
    private func loadManualLocation() -> (name: String, coordinates: CLLocationCoordinate2D)? { guard let data = UserDefaults.standard.dictionary(forKey: "manualLocationData"), let name = data["name"] as? String, let lat = data["latitude"] as? CLLocationDegrees, let lon = data["longitude"] as? CLLocationDegrees else { return nil }; return (name, CLLocationCoordinate2D(latitude: lat, longitude: lon)) }
    func switchToAutomaticLocation() { isUsingManualLocation = false; UserDefaults.standard.removeObject(forKey: "manualLocationData"); if let cache = automaticLocationCache { currentCoordinates = cache.coordinates; locationStatusText = cache.name; updateAndDisplayTimes() } else { handleAuthorizationStatus(status: locMgr.authorizationStatus) } }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locs: [CLLocation]) { guard let location = locs.last else { return }; let geocoder = CLGeocoder(); geocoder.reverseGeocodeLocation(location) { (placemarks, _) in DispatchQueue.main.async { guard let locality = placemarks?.first?.locality else { self.isRequestingLocation = false; return }; self.automaticLocationCache = (name: locality, coordinates: location.coordinate); if !self.isUsingManualLocation { self.currentCoordinates = location.coordinate; self.locationStatusText = locality; self.updateAndDisplayTimes() }; if self.isRequestingLocation { self.isRequestingLocation = false } } } }
    private func updateAndDisplayTimes() { updatePrayerTimes(); if isUsingManualLocation { startLocationDisplayTimer() } else { stopLocationDisplayTimer() } }
    
    func updatePrayerTimes() {
        guard let coord = currentCoordinates else { return }
        var locationCalendar = Calendar(identifier: .gregorian); locationCalendar.timeZone = self.locationTimeZone
        let todayInLocation = locationCalendar.dateComponents([.year, .month, .day], from: Date())
        let tomorrowInLocation = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let tomorrowDC = locationCalendar.dateComponents([.year, .month, .day], from: tomorrowInLocation)
        var params = method.params; params.madhab = self.useHanafiMadhhab ? .hanafi : .shafi
        guard let prayersToday = PrayerTimes(coordinates: Coordinates(latitude: coord.latitude, longitude: coord.longitude), date: todayInLocation, calculationParameters: params),
              let prayersTomorrow = PrayerTimes(coordinates: Coordinates(latitude: coord.latitude, longitude: coord.longitude), date: tomorrowDC, calculationParameters: params) else { return }
        
        let correctedFajr = prayersToday.fajr.addingTimeInterval(fajrCorrection * 60)
        let correctedDhuhr = prayersToday.dhuhr.addingTimeInterval(dhuhrCorrection * 60)
        let correctedAsr = prayersToday.asr.addingTimeInterval(asrCorrection * 60)
        let correctedMaghrib = prayersToday.maghrib.addingTimeInterval(maghribCorrection * 60)
        let correctedIsha = prayersToday.isha.addingTimeInterval(ishaCorrection * 60)
        
        var allPrayerTimes: [(name: String, time: Date)] = [("Fajr", correctedFajr), ("Dhuhr", correctedDhuhr), ("Asr", correctedAsr), ("Maghrib", correctedMaghrib), ("Isha", correctedIsha)]
        
        if showSunnahPrayers {
            let correctedFajrTomorrow = prayersTomorrow.fajr.addingTimeInterval(fajrCorrection * 60)
            let nightDuration = correctedFajrTomorrow.timeIntervalSince(correctedIsha)
            let lastThirdOfNightStart = correctedIsha.addingTimeInterval(nightDuration * (2/3.0))
            allPrayerTimes.append(("Tahajud", lastThirdOfNightStart))
            
            let dhuhaTime = prayersToday.sunrise.addingTimeInterval(20 * 60)
            allPrayerTimes.append(("Dhuha", dhuhaTime))
        }
        
        let correctedFajrTomorrow = prayersTomorrow.fajr.addingTimeInterval(fajrCorrection * 60)
        
        DispatchQueue.main.async {
            self.todayTimes = Dictionary(uniqueKeysWithValues: allPrayerTimes.map { ($0.name, $0.time) })
            self.tomorrowFajrTime = correctedFajrTomorrow
            self.updateNextPrayer()
            self.updateNotifications()
        }
    }
    
    private func updateNextPrayer() {
        let now = Date()
        var potentialPrayers = todayTimes.map { (key: $0.key, value: $0.value) }
        if let fajrTomorrow = tomorrowFajrTime {
            potentialPrayers.append((key: "Fajr", value: fajrTomorrow))
        }
        let allSortedPrayers = potentialPrayers.sorted { $0.value < $1.value }
        let listToSearch: [(key: String, value: Date)]
        if showSunnahPrayers {
            listToSearch = allSortedPrayers
        } else {
            listToSearch = allSortedPrayers.filter { $0.key != "Tahajud" && $0.key != "Dhuha" }
        }
        
        if let nextPrayer = listToSearch.first(where: { $0.value > now }) {
            self.nextPrayerName = nextPrayer.key
        } else {
            if let firstPrayerOfNextCycle = listToSearch.first {
                self.nextPrayerName = firstPrayerOfNextCycle.key
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    self?.updatePrayerTimes()
                }
            }
        }
        updateCountdown()
    }
    
    private func updateCountdown() {
        var nextPrayerDate: Date?
        if nextPrayerName == "Fajr" && todayTimes["Fajr"] ?? Date() < Date() {
            nextPrayerDate = tomorrowFajrTime
        } else {
            nextPrayerDate = todayTimes[nextPrayerName]
        }
        
        guard let nextDate = nextPrayerDate else {
            countdown = "--:--"; updateMenuTitle(); return
        }
        
        let diff = Int(nextDate.timeIntervalSince(Date()))
        isPrayerImminent = (diff <= 600 && diff > 0)
        
        if diff > 0 {
            let h = diff / 3600
            let m = (diff % 3600) / 60
            let numberFormatter = NumberFormatter()
            numberFormatter.locale = Locale(identifier: languageManager.language)
            let formattedM = numberFormatter.string(from: NSNumber(value: m + 1)) ?? "\(m + 1)"
            if h > 0 {
                let formattedH = numberFormatter.string(from: NSNumber(value: h)) ?? "\(h)"
                countdown = "\(formattedH)h \(formattedM)m"
            } else {
                countdown = "\(formattedM)m"
            }
        } else {
            countdown = "Now"
            if adhanSound == .custom, let soundPath = customAdhanSoundPath.removingPercentEncoding, let soundURL = URL(string: soundPath), FileManager.default.fileExists(atPath: soundURL.path) {
                adhanPlayer = NSSound(contentsOf: soundURL, byReference: true)
                adhanPlayer?.play()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.updateNextPrayer() }
        }
        updateMenuTitle()
    }
    
    func updateMenuTitle() { guard isPrayerDataAvailable else { self.menuTitle = NSAttributedString(string: "Sajda Pro"); return }; var textToShow = ""; let localizedPrayerName = NSLocalizedString(nextPrayerName, comment: ""); switch menuBarTextMode { case .hidden: textToShow = ""; case .countdown: if useMinimalMenuBarText { textToShow = "\(localizedPrayerName) -\(countdown)" } else { textToShow = String(format: NSLocalizedString("prayer_in_countdown", comment: ""), localizedPrayerName, countdown) }; case .exactTime: var nextPrayerDate: Date?; if nextPrayerName == "Fajr" && todayTimes["Fajr"] ?? Date() < Date() { nextPrayerDate = tomorrowFajrTime } else { nextPrayerDate = todayTimes[nextPrayerName] }; guard let nextDate = nextPrayerDate else { textToShow = "Sajda Pro"; break }; if useMinimalMenuBarText { textToShow = "\(localizedPrayerName) \(dateFormatter.string(from: nextDate))" } else { textToShow = String(format: NSLocalizedString("prayer_at_time", comment: ""), localizedPrayerName, dateFormatter.string(from: nextDate)) } }; let attributes: [NSAttributedString.Key: Any] = isPrayerImminent ? [.foregroundColor: NSColor.systemRed] : [:]; self.menuTitle = NSAttributedString(string: textToShow, attributes: attributes) }
    
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeZone = self.locationTimeZone
        formatter.locale = Locale(identifier: languageManager.language)
        if useMinimalMenuBarText {
            formatter.dateFormat = use24HourFormat ? "H.mm" : "h.mm"
        } else {
            formatter.timeStyle = .short
        }
        return formatter
    }
    
    private func startLocationDisplayTimer() { stopLocationDisplayTimer(); locationDisplayTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in guard let self = self else { return }; let timeFormatter = DateFormatter(); timeFormatter.timeZone = self.locationTimeZone; timeFormatter.timeStyle = .medium; let tzName = self.locationTimeZone.identifier; let currentTime = timeFormatter.string(from: Date()); self.locationInfoText = "Timezone: \(tzName) | Current Time: \(currentTime)" } }
    private func stopLocationDisplayTimer() { locationDisplayTimer?.invalidate(); locationDisplayTimer = nil; locationInfoText = "" }
    
    private func updateNotifications() {
        guard isNotificationsEnabled, !todayTimes.isEmpty else {
            NotificationManager.cancelNotifications()
            return
        }
        NotificationManager.requestPermission()
        var prayersToNotify = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
        if showSunnahPrayers {
            if todayTimes.keys.contains("Tahajud") { prayersToNotify.append("Tahajud") }
            if todayTimes.keys.contains("Dhuha") { prayersToNotify.append("Dhuha") }
        }
        NotificationManager.scheduleNotifications(for: todayTimes, prayerOrder: prayersToNotify, adhanSound: self.adhanSound, customSoundPath: self.customAdhanSoundPath)
    }
    
    func selectCustomAdhanSound() { let openPanel = NSOpenPanel(); openPanel.canChooseFiles = true; openPanel.canChooseDirectories = false; openPanel.allowsMultipleSelection = false; openPanel.allowedContentTypes = [.audio]; if openPanel.runModal() == .OK { self.customAdhanSoundPath = openPanel.url?.absoluteString ?? "" } }
    var isPrayerDataAvailable: Bool { !todayTimes.isEmpty }
    func startTimer() { timer?.invalidate(); timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.updateCountdown() } }
    private func handleAuthorizationStatus(status: CLAuthorizationStatus) { self.authorizationStatus = status; switch status { case .authorized: if automaticLocationCache == nil { locationStatusText = "Fetching Location..." }; locMgr.requestLocation(); case .denied, .restricted: locationStatusText = "Location access denied."; isRequestingLocation = false; todayTimes = [:]; case .notDetermined: isRequestingLocation = false; locationStatusText = "Location access needed"; @unknown default: isRequestingLocation = false; break } }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { if !isUsingManualLocation { handleAuthorizationStatus(status: manager.authorizationStatus) } }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { isRequestingLocation = false; self.locationStatusText = "Unable to determine location." }
    func requestLocationPermission() { if authorizationStatus == .notDetermined { isRequestingLocation = true; DispatchQueue.main.async { self.locMgr.requestWhenInUseAuthorization() } } }
    func openLocationSettings() { guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") else { return }; NSWorkspace.shared.open(url) }
}

extension Sequence {
    func unique<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        var set = Set<T>()
        return filter { set.insert($0[keyPath: keyPath]).inserted }
    }
}
