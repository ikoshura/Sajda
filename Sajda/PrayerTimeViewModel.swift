// MARK: - GANTI SELURUH FILE: PrayerTimeViewModel.swift

import Foundation
import Combine
import Adhan
import CoreLocation
import SwiftUI
import AppKit
import NavigationStack
import OSLog

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
    @Published var locationStatusText: String = NSLocalizedString("Preparing prayer schedule...", comment: "")
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var locationSearchQuery: String = ""
    @Published var locationSearchResults: [LocationSearchResult] = []
    @Published var isLocationSearching: Bool = false
    @Published var locationInfoText: String = ""
    @Published var isPrayerImminent: Bool = false
    @Published var isRequestingLocation: Bool = false
    @Published var isAdhanPlaying: Bool = false
    @Published var activeAdhanPrayerName: String = ""

    private let languageManager = LanguageManager()
    private let logger = Logger(subsystem: "com.madda.Sajda", category: "Location")
    private var automaticLocationCache: (name: String, coordinates: CLLocationCoordinate2D)?
    private var tomorrowFajrTime: Date?

    @AppStorage("animationType") var animationType: AnimationType = .fade
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
    @AppStorage("adhanSound") var adhanSound: String = "Default Beep" { didSet { updateNotifications() } }
    @AppStorage("customAdhanSoundPath") var customAdhanSoundPath: String = "" { didSet { updateNotifications() } }
    @AppStorage("prayerSoundConfigs") var prayerSoundConfigsJSON: String = "{}" { didSet { updateNotifications() } }

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
    private var locationTimeZone: TimeZone = .current
    private var locationDisplayTimer: Timer?
    private var dailyRescheduleTimer: Timer?
    private var lastCalculationDate: Date?
    private var locationRequestTimeoutTask: DispatchWorkItem?
    private var locationProgressUpdateTask: DispatchWorkItem?
    private var isAutomaticLocationUpdateActive = false
    private var preserveExistingAutomaticLocationOnFailure = false
    private var manualLocationFallbackForAutomaticSwitch: (name: String, coordinates: CLLocationCoordinate2D)?
    private let automaticLocationProgressDelay: TimeInterval = 12
    private let automaticLocationTimeout: TimeInterval = 45
    private let maximumCachedLocationAge: TimeInterval = 15 * 60


    override init() {
        let savedMethodName = UserDefaults.standard.string(forKey: "calculationMethodName") ?? "Muslim World League"
        self.method = SajdaCalculationMethod.allCases.first { $0.name == savedMethodName } ?? .allCases[0]
        let savedTextMode = UserDefaults.standard.string(forKey: "menuBarTextMode")
        self.menuBarTextMode = MenuBarTextMode(rawValue: savedTextMode ?? "") ?? .countdown
        self.authorizationStatus = locMgr.authorizationStatus
        super.init()
        migratePrayerSoundConfigs()
        locMgr.delegate = self
        locMgr.desiredAccuracy = kCLLocationAccuracyKilometer
        locMgr.distanceFilter = kCLDistanceFilterNone
        logger.info("Location manager configured. Services enabled: \(CLLocationManager.locationServicesEnabled(), privacy: .public). Initial authorization: \(self.authorizationDescription(self.locMgr.authorizationStatus), privacy: .public). Desired accuracy: \(self.locMgr.desiredAccuracy, privacy: .public)m")
        startTimer()
        setupSearchPublisher()
        setupAdhanObservers()
    }

    private func migratePrayerSoundConfigs() {
        guard prayerSoundConfigsJSON == "{}", adhanSound != "Default Beep" else { return }
        let allPrayers = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha", "Tahajud", "Dhuha"]
        var configs: [String: PrayerSoundConfig] = [:]
        let newType: AdhanType
        switch adhanSound {
        case "None": newType = .none
        case "Custom Sound": newType = .custom
        default: newType = .defaultBeep
        }
        for prayer in allPrayers {
            configs[prayer] = PrayerSoundConfig(adhanType: newType, customFilePath: customAdhanSoundPath)
        }
        prayerSoundConfigs = configs
    }

    func forwardAnimation() -> NavigationAnimation? {
        switch animationType {
        case .none: return nil
        case .fade: return .sajdaCrossfade
        case .slide: return .push
        }
    }

    func backwardAnimation() -> NavigationAnimation? {
        switch animationType {
        case .none: return nil
        case .fade: return .sajdaCrossfade
        case .slide: return .pop
        }
    }

    private struct NominatimResult: Codable, Hashable {
        @FlexibleDouble var lat: Double; @FlexibleDouble var lon: Double
        let display_name: String; let address: NominatimAddress
    }

    private struct NominatimAddress: Codable, Hashable {
        let city: String?, town: String?, village: String?, state: String?, county: String?, country: String?
    }

    private func setupSearchPublisher() {
        $locationSearchQuery
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .removeDuplicates()
            .handleEvents(receiveOutput: { [weak self] query in
                let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
                self?.isLocationSearching = !trimmedQuery.isEmpty
                if trimmedQuery.isEmpty { self?.locationSearchResults = [] }
            })
            .flatMap { [weak self] query -> AnyPublisher<[LocationSearchResult], Never> in
                guard let self = self else { return Just([]).eraseToAnyPublisher() }
                let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
                guard !trimmedQuery.isEmpty else { return Just([]).eraseToAnyPublisher() }

                if let coordResult = self.parseCoordinates(from: trimmedQuery) {
                    return Just([coordResult]).eraseToAnyPublisher()
                }

                var components = URLComponents(string: "https://nominatim.openstreetmap.org/search")!
                components.queryItems = [
                    URLQueryItem(name: "q", value: trimmedQuery),
                    URLQueryItem(name: "format", value: "json"),
                    URLQueryItem(name: "addressdetails", value: "1"),
                    URLQueryItem(name: "accept-language", value: "en"),
                    URLQueryItem(name: "limit", value: "20")
                ]
                guard let url = components.url else { return Just([]).eraseToAnyPublisher() }
                var request = URLRequest(url: url)
                request.setValue("Sajda Pro Prayer Times App/1.0", forHTTPHeaderField: "User-Agent")

                return URLSession.shared.dataTaskPublisher(for: request)
                    .map(\.data)
                    .decode(type: [NominatimResult].self, decoder: JSONDecoder())
                    .catch { error -> Just<[NominatimResult]> in
                        print("🔴 DECODING ERROR: \(error)")
                        return Just([])
                    }
                    .map { results -> [LocationSearchResult] in
                        let mappedResults = results.compactMap { result -> LocationSearchResult? in
                            let name = result.address.city ?? result.address.town ?? result.address.village ?? result.address.county ?? result.address.state ?? ""
                            let country = result.address.country ?? ""
                            guard !country.isEmpty else { return nil }
                            let finalName = name.isEmpty ? result.display_name.components(separatedBy: ",")[0] : name
                            return LocationSearchResult(name: finalName, country: country, coordinates: CLLocationCoordinate2D(latitude: result.lat, longitude: result.lon))
                        }
                        let uniqueResults = Array(Set(mappedResults))
                        return uniqueResults.sorted { $0.name < $1.name }
                    }
                    .eraseToAnyPublisher()
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] results in
                self?.isLocationSearching = false
                self?.locationSearchResults = results
            }
            .store(in: &cancellables)
    }

    private func parseCoordinates(from string: String) -> LocationSearchResult? { let cleaned = string.replacingOccurrences(of: " ", with: ""); let components = cleaned.split(separator: ",").compactMap { Double($0) }; guard components.count == 2, let lat = components.first, let lon = components.last, (lat >= -90 && lat <= 90) && (lon >= -180 && lon <= 180) else { return nil }; return LocationSearchResult(name: "Custom Coordinate", country: String(format: "%.4f, %.4f", lat, lon), coordinates: CLLocationCoordinate2D(latitude: lat, longitude: lon)) }
    func setManualLocation(city: String, coordinates: CLLocationCoordinate2D) {
        completeLocationRequest()
        logger.info("Setting manual location. City: \(city, privacy: .public). Authorization remains: \(self.authorizationDescription(self.locMgr.authorizationStatus), privacy: .public)")

        let location = CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
        self.locationTimeZone = TimeZoneLocate.timeZoneWithLocation(location)
        var locationNameToSave = city

        if city == "Custom Coordinate" {
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
                DispatchQueue.main.async {
                    if let error {
                        self.logger.error("Manual coordinate reverse geocode failed: \(error.localizedDescription, privacy: .public)")
                    }

                    if let placemark = placemarks?.first, let cityName = placemark.locality {
                        locationNameToSave = cityName
                        self.locationStatusText = cityName
                        let manualData: [String: Any] = ["name": locationNameToSave, "latitude": coordinates.latitude, "longitude": coordinates.longitude]
                        UserDefaults.standard.set(manualData, forKey: "manualLocationData")
                    } else {
                        self.locationStatusText = String(format: "Coord: %.2f, %.2f", coordinates.latitude, coordinates.longitude)
                    }
                }
            }
        } else {
            self.locationStatusText = city
        }

        let manualLocationData: [String: Any] = ["name": locationNameToSave, "latitude": coordinates.latitude, "longitude": coordinates.longitude]
        UserDefaults.standard.set(manualLocationData, forKey: "manualLocationData")
        isUsingManualLocation = true
        currentCoordinates = coordinates
        authorizationStatus = locMgr.authorizationStatus
        locationSearchQuery = ""
        locationSearchResults = []
        updateAndDisplayTimes()
    }

    func startLocationProcess() {
        logger.info("Starting location process. Manual location enabled: \(self.isUsingManualLocation, privacy: .public)")

        if isUsingManualLocation, let manualData = loadManualLocation() {
            currentCoordinates = manualData.coordinates
            locationStatusText = manualData.name
            let location = CLLocation(latitude: manualData.coordinates.latitude, longitude: manualData.coordinates.longitude)
            self.locationTimeZone = TimeZoneLocate.timeZoneWithLocation(location)
            self.authorizationStatus = locMgr.authorizationStatus
            DispatchQueue.main.async {
                self.updateAndDisplayTimes()
            }
        } else if let automaticData = loadAutomaticLocation() {
            logger.info("Loaded saved automatic location while refreshing provider in the background. Name: \(automaticData.name, privacy: .public)")
            currentCoordinates = automaticData.coordinates
            locationStatusText = automaticData.name
            let location = CLLocation(latitude: automaticData.coordinates.latitude, longitude: automaticData.coordinates.longitude)
            self.locationTimeZone = TimeZoneLocate.timeZoneWithLocation(location)
            self.authorizationStatus = locMgr.authorizationStatus
            DispatchQueue.main.async {
                self.updateAndDisplayTimes()
                self.requestAutomaticLocation(
                    allowCachedLocation: false,
                    preserveExistingLocationOnFailure: true
                )
            }
        } else {
            self.locationTimeZone = .current
            handleAuthorizationStatus(status: locMgr.authorizationStatus)
        }
    }

    private func loadManualLocation() -> (name: String, coordinates: CLLocationCoordinate2D)? { guard let data = UserDefaults.standard.dictionary(forKey: "manualLocationData"), let name = data["name"] as? String, let lat = data["latitude"] as? CLLocationDegrees, let lon = data["longitude"] as? CLLocationDegrees else { return nil }; return (name, CLLocationCoordinate2D(latitude: lat, longitude: lon)) }
    private func loadAutomaticLocation() -> (name: String, coordinates: CLLocationCoordinate2D)? { guard let data = UserDefaults.standard.dictionary(forKey: "automaticLocationData"), let name = data["name"] as? String, let lat = data["latitude"] as? CLLocationDegrees, let lon = data["longitude"] as? CLLocationDegrees else { return nil }; return (name, CLLocationCoordinate2D(latitude: lat, longitude: lon)) }
    private func saveAutomaticLocation(name: String, coordinates: CLLocationCoordinate2D) {
        let data: [String: Any] = ["name": name, "latitude": coordinates.latitude, "longitude": coordinates.longitude]
        UserDefaults.standard.set(data, forKey: "automaticLocationData")
    }

    func switchToAutomaticLocation() {
        completeLocationRequest()
        logger.info("Switching from manual location to automatic location.")

        manualLocationFallbackForAutomaticSwitch = loadManualLocation()
        isUsingManualLocation = false

        currentCoordinates = nil
        todayTimes = [:]
        tomorrowFajrTime = nil
        lastCalculationDate = nil
        locationInfoText = ""
        locationTimeZone = .current
        locationStatusText = NSLocalizedString("Finding your location...", comment: "")

        if let cache = automaticLocationCache {
            UserDefaults.standard.removeObject(forKey: "manualLocationData")
            manualLocationFallbackForAutomaticSwitch = nil
            currentCoordinates = cache.coordinates
            locationStatusText = cache.name
            let location = CLLocation(latitude: cache.coordinates.latitude, longitude: cache.coordinates.longitude)
            locationTimeZone = TimeZoneLocate.timeZoneWithLocation(location)
            updateAndDisplayTimes()
        } else {
            handleAuthorizationStatus(status: locMgr.authorizationStatus)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        let sortedLocations = locs.sorted(by: { $0.timestamp > $1.timestamp })
        logger.info("CoreLocation delivered \(locs.count, privacy: .public) location update candidate(s).")

        for location in sortedLocations.prefix(3) {
            logger.info("CoreLocation candidate. Age: \(abs(location.timestamp.timeIntervalSinceNow), privacy: .public)s. Accuracy: \(location.horizontalAccuracy, privacy: .public)m. Coordinates: \(self.coordinateDescription(location.coordinate), privacy: .private)")
        }

        guard let location = sortedLocations.first(where: { $0.horizontalAccuracy >= 0 }) else {
            logger.warning("CoreLocation returned no usable coordinates.")
            return
        }

        handleAutomaticLocation(location, source: "live")
    }

    private func handleAutomaticLocation(_ location: CLLocation, source: String) {
        completeLocationRequest()
        preserveExistingAutomaticLocationOnFailure = false
        manualLocationFallbackForAutomaticSwitch = nil
        UserDefaults.standard.removeObject(forKey: "manualLocationData")

        let coordinates = location.coordinate
        let fallbackName = String(format: "Coord: %.2f, %.2f", coordinates.latitude, coordinates.longitude)
        locationTimeZone = TimeZoneLocate.timeZoneWithLocation(location)
        automaticLocationCache = (name: fallbackName, coordinates: coordinates)
        saveAutomaticLocation(name: fallbackName, coordinates: coordinates)
        logger.info("Accepted \(source, privacy: .public) location. Accuracy: \(location.horizontalAccuracy, privacy: .public)m")

        if !isUsingManualLocation {
            currentCoordinates = coordinates
            locationStatusText = "Current Location"
            updateAndDisplayTimes()
        }

        reverseGeocodeAutomaticLocation(location, fallbackName: fallbackName, coordinates: coordinates)
    }

    private func reverseGeocodeAutomaticLocation(_ location: CLLocation, fallbackName: String, coordinates: CLLocationCoordinate2D) {
        logger.info("Starting reverse geocode for automatic location.")

        CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                guard let self else { return }

                if let error {
                    self.logger.error("Reverse geocode failed: \(error.localizedDescription, privacy: .public)")
                }

                let placemark = placemarks?.first
                let locationName = placemark?.locality ?? placemark?.name ?? fallbackName
                self.automaticLocationCache = (name: locationName, coordinates: coordinates)
                self.saveAutomaticLocation(name: locationName, coordinates: coordinates)
                self.logger.info("Reverse geocode resolved automatic location name: \(locationName, privacy: .public)")

                if !self.isUsingManualLocation {
                    self.locationStatusText = locationName
                }
            }
        }
    }
    private func updateAndDisplayTimes() { updatePrayerTimes() }

    func updatePrayerTimes() {
        guard let coord = currentCoordinates else { return }

        // Reset played prayers when day changes or prayer times are recalculated
        if let lastDate = lastCalculationDate,
           !Calendar.current.isDate(lastDate, inSameDayAs: Date()) {
            AdhanAudioPlayer.shared.resetPlayedPrayers()
        }

        lastCalculationDate = Date()

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
                countdown = String(format: NSLocalizedString("countdown_hm", comment: ""), formattedH, formattedM)
            } else {
                countdown = String(format: NSLocalizedString("countdown_m", comment: ""), formattedM)
            }
        } else {
            countdown = NSLocalizedString("Now", comment: "")
            let config = soundConfig(for: nextPrayerName)
            AdhanAudioPlayer.shared.play(adhanType: config.adhanType, customFilePath: config.customFilePath, prayerName: nextPrayerName)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.updateNextPrayer() }
        }
        updateMenuTitle()
    }

    func updateMenuTitle() { guard isPrayerDataAvailable else { self.menuTitle = NSAttributedString(string: "Sajda Pro"); return }; var textToShow = ""; let localizedPrayerName = NSLocalizedString(nextPrayerName, comment: ""); switch menuBarTextMode { case .hidden: textToShow = ""; case .countdown: if useMinimalMenuBarText { textToShow = String(format: NSLocalizedString("prayer_minimal_countdown", comment: ""), localizedPrayerName, countdown) } else { textToShow = String(format: NSLocalizedString("prayer_in_countdown", comment: ""), localizedPrayerName, countdown) }; case .exactTime: var nextPrayerDate: Date?; if nextPrayerName == "Fajr" && todayTimes["Fajr"] ?? Date() < Date() { nextPrayerDate = tomorrowFajrTime } else { nextPrayerDate = todayTimes[nextPrayerName] }; guard let nextDate = nextPrayerDate else { textToShow = "Sajda Pro"; break }; if useMinimalMenuBarText { textToShow = String(format: NSLocalizedString("prayer_minimal_exact", comment: ""), localizedPrayerName, dateFormatter.string(from: nextDate)) } else { textToShow = String(format: NSLocalizedString("prayer_at_time", comment: ""), localizedPrayerName, dateFormatter.string(from: nextDate)) } }; let attributes: [NSAttributedString.Key: Any] = isPrayerImminent ? [.foregroundColor: NSColor.systemRed] : [:]; self.menuTitle = NSAttributedString(string: textToShow, attributes: attributes) }

    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeZone = self.locationTimeZone
        formatter.locale = Locale(identifier: languageManager.language)
        if use24HourFormat {
            formatter.dateFormat = "HH:mm"
        } else if useMinimalMenuBarText {
            formatter.dateFormat = "h:mm"
        } else {
            formatter.timeStyle = .short
        }
        return formatter
    }

    private func startLocationDisplayTimer() { stopLocationDisplayTimer(); locationDisplayTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in guard let self = self else { return }; let timeFormatter = DateFormatter(); timeFormatter.timeZone = self.locationTimeZone; timeFormatter.timeStyle = .medium; let tzName = self.locationTimeZone.identifier; let currentTime = timeFormatter.string(from: Date()); self.locationInfoText = "Timezone: \(tzName) | Current Time: \(currentTime)" } }
    private func stopLocationDisplayTimer() { locationDisplayTimer?.invalidate(); locationDisplayTimer = nil; locationInfoText = "" }

    private func updateNotifications() {
        dailyRescheduleTimer?.invalidate()
        dailyRescheduleTimer = nil

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
        NotificationManager.scheduleNotifications(for: todayTimes, prayerOrder: prayersToNotify, prayerConfigs: prayerSoundConfigs)
        scheduleNextDayReschedule()
    }

    private func scheduleNextDayReschedule() {
        dailyRescheduleTimer?.invalidate()
        let now = Date()
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now),
              let midnight = Calendar.current.date(bySettingHour: 0, minute: 1, second: 0, of: tomorrow) else { return }
        let interval = midnight.timeIntervalSince(now)
        guard interval > 0 else { return }
        dailyRescheduleTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.updatePrayerTimes()
        }
    }

    func selectCustomAdhanSound() { let openPanel = NSOpenPanel(); openPanel.canChooseFiles = true; openPanel.canChooseDirectories = false; openPanel.allowsMultipleSelection = false; openPanel.allowedContentTypes = [.audio]; if openPanel.runModal() == .OK { self.customAdhanSoundPath = openPanel.url?.absoluteString ?? "" } }

    var prayerSoundConfigs: [String: PrayerSoundConfig] {
        get {
            guard let data = prayerSoundConfigsJSON.data(using: .utf8),
                  let dict = try? JSONDecoder().decode([String: PrayerSoundConfig].self, from: data)
            else { return [:] }
            return dict
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            prayerSoundConfigsJSON = String(data: data, encoding: .utf8) ?? "{}"
        }
    }

    func soundConfig(for prayerName: String) -> PrayerSoundConfig {
        prayerSoundConfigs[prayerName] ?? PrayerSoundConfig()
    }

    func stopAdhan() {
        AdhanAudioPlayer.shared.stop()
    }

    private func setupAdhanObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleAdhanDidStart(_:)), name: .adhanDidStart, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAdhanDidStop(_:)), name: .adhanDidStop, object: nil)
    }

    @objc private func handleAdhanDidStart(_ notification: Notification) {
        let prayer = notification.userInfo?["prayerName"] as? String ?? ""
        DispatchQueue.main.async {
            self.isAdhanPlaying = true
            self.activeAdhanPrayerName = prayer
        }
    }

    @objc private func handleAdhanDidStop(_ notification: Notification) {
        DispatchQueue.main.async {
            self.isAdhanPlaying = false
            self.activeAdhanPrayerName = ""
        }
    }

    func setSoundConfig(_ config: PrayerSoundConfig, for prayerName: String) {
        var configs = prayerSoundConfigs
        configs[prayerName] = config
        prayerSoundConfigs = configs
    }
    var isPrayerDataAvailable: Bool { !todayTimes.isEmpty }
    var isRTL: Bool { languageManager.language == "ar" }
    var backChevron: String { isRTL ? "chevron.right" : "chevron.left" }
    var forwardChevron: String { isRTL ? "chevron.left" : "chevron.right" }
    var forwardArrow: String { isRTL ? "arrow.left" : "arrow.right" }

    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            if let lastDate = self.lastCalculationDate,
               !Calendar.current.isDate(lastDate, inSameDayAs: Date()) {
                self.updatePrayerTimes()
            } else {
                self.updateCountdown()
            }
        }
    }

    private func handleAuthorizationStatus(status: CLAuthorizationStatus) {
        self.authorizationStatus = status
        logger.info("Location authorization changed to \(self.authorizationDescription(status), privacy: .public)")

        switch status {
        case .authorized, .authorizedAlways:
            requestAutomaticLocation()
        case .denied, .restricted:
            failAutomaticLocation(NSLocalizedString("Location access denied.", comment: ""))
        case .notDetermined:
            if isRequestingLocation || isAutomaticLocationUpdateActive {
                locationStatusText = NSLocalizedString("Requesting Permission...", comment: "")
                logger.info("Location authorization is still not determined while a prompt/update request is active; keeping the request alive.")
                return
            }
            completeLocationRequest()
            locationStatusText = NSLocalizedString("Location access needed", comment: "")
        @unknown default:
            failAutomaticLocation(NSLocalizedString("Unsupported location permission state.", comment: ""))
        }
    }

    func refetchAutomaticLocation() {
        logger.info("User requested automatic location refresh.")
        let shouldPreserveExistingLocation = currentCoordinates != nil && isPrayerDataAvailable

        completeLocationRequest()

        isUsingManualLocation = false
        UserDefaults.standard.removeObject(forKey: "manualLocationData")
        manualLocationFallbackForAutomaticSwitch = nil

        if !shouldPreserveExistingLocation {
            currentCoordinates = nil
            todayTimes = [:]
            tomorrowFajrTime = nil
            lastCalculationDate = nil
            locationInfoText = ""
            locationTimeZone = .current
            locationStatusText = NSLocalizedString("Refreshing location...", comment: "")
        }

        authorizationStatus = locMgr.authorizationStatus

        switch locMgr.authorizationStatus {
        case .authorized, .authorizedAlways:
            requestAutomaticLocation(
                allowCachedLocation: false,
                preserveExistingLocationOnFailure: shouldPreserveExistingLocation
            )
        case .notDetermined:
            requestLocationPermission()
        case .denied, .restricted:
            failAutomaticLocation(NSLocalizedString("Location access denied.", comment: ""), preserveExistingLocation: shouldPreserveExistingLocation)
        @unknown default:
            failAutomaticLocation(NSLocalizedString("Unsupported location permission state.", comment: ""), preserveExistingLocation: shouldPreserveExistingLocation)
        }
    }

    private func requestAutomaticLocation(
        allowCachedLocation: Bool = true,
        preserveExistingLocationOnFailure: Bool = false
    ) {
        guard !isUsingManualLocation else { return }

        preserveExistingAutomaticLocationOnFailure = preserveExistingLocationOnFailure

        let servicesEnabled = CLLocationManager.locationServicesEnabled()
        logger.info("Automatic location requested. Services enabled: \(servicesEnabled, privacy: .public). Authorization: \(self.authorizationDescription(self.locMgr.authorizationStatus), privacy: .public). Existing coordinates available: \(self.currentCoordinates != nil, privacy: .public)")

        guard servicesEnabled else {
            failAutomaticLocation(
                NSLocalizedString("Location Services are off. Enable Location Services in System Settings or set location manually.", comment: ""),
                preserveExistingLocation: preserveExistingLocationOnFailure
            )
            return
        }

        if isAutomaticLocationUpdateActive {
            preserveExistingAutomaticLocationOnFailure = preserveExistingAutomaticLocationOnFailure || preserveExistingLocationOnFailure
            logger.info("Automatic CoreLocation request is already active; keeping existing update and timeout.")
            return
        }

        if allowCachedLocation,
           let cachedLocation = locMgr.location,
           cachedLocation.horizontalAccuracy >= 0,
           abs(cachedLocation.timestamp.timeIntervalSinceNow) <= maximumCachedLocationAge {
            logger.info("Using cached CoreLocation location. Age: \(abs(cachedLocation.timestamp.timeIntervalSinceNow), privacy: .public)s")
            handleAutomaticLocation(cachedLocation, source: "cached")
            return
        }

        if let cachedLocation = locMgr.location {
            logger.info("Ignoring cached CoreLocation location. Allow cached: \(allowCachedLocation, privacy: .public). Age: \(abs(cachedLocation.timestamp.timeIntervalSinceNow), privacy: .public)s. Accuracy: \(cachedLocation.horizontalAccuracy, privacy: .public)m")
        } else {
            logger.info("No cached CoreLocation location is available.")
        }

        if currentCoordinates == nil {
            locationStatusText = NSLocalizedString("Finding your location...", comment: "")
        }
        isRequestingLocation = true

        isAutomaticLocationUpdateActive = true

        locationRequestTimeoutTask?.cancel()
        let timeoutTask = DispatchWorkItem { [weak self] in
            guard let self, !self.isUsingManualLocation, self.isAutomaticLocationUpdateActive else { return }

            self.logger.error("Automatic location timed out after \(self.automaticLocationTimeout, privacy: .public)s before CoreLocation returned a usable coordinate.")
            self.failAutomaticLocation(
                NSLocalizedString("Location request timed out. Set location manually or check Wi-Fi and Location Services.", comment: ""),
                preserveExistingLocation: preserveExistingLocationOnFailure
            )
        }

        locationRequestTimeoutTask = timeoutTask
        let progressTask = DispatchWorkItem { [weak self] in
            guard let self, !self.isUsingManualLocation, self.isAutomaticLocationUpdateActive else { return }
            if self.currentCoordinates == nil {
                self.locationStatusText = NSLocalizedString("Still finding your location...", comment: "")
            }
            self.logger.warning("Automatic location is still pending after \(self.automaticLocationProgressDelay, privacy: .public)s; keeping CoreLocation active until hard timeout.")
        }
        locationProgressUpdateTask = progressTask

        logger.info("Scheduling automatic CoreLocation progress notice in \(self.automaticLocationProgressDelay, privacy: .public)s and timeout in \(self.automaticLocationTimeout, privacy: .public)s.")
        DispatchQueue.main.asyncAfter(deadline: .now() + automaticLocationProgressDelay, execute: progressTask)
        DispatchQueue.main.asyncAfter(deadline: .now() + automaticLocationTimeout, execute: timeoutTask)

        logger.info("Starting continuous CoreLocation updates.")
        locMgr.startUpdatingLocation()
    }

    private func failAutomaticLocation(_ message: String, preserveExistingLocation: Bool = false) {
        completeLocationRequest()

        guard !isUsingManualLocation else { return }

        if let fallback = manualLocationFallbackForAutomaticSwitch {
            logger.error("Automatic location failed while switching from manual mode; restoring manual location \(fallback.name, privacy: .public).")
            manualLocationFallbackForAutomaticSwitch = nil
            preserveExistingAutomaticLocationOnFailure = false
            isUsingManualLocation = true
            currentCoordinates = fallback.coordinates
            locationStatusText = fallback.name
            let location = CLLocation(latitude: fallback.coordinates.latitude, longitude: fallback.coordinates.longitude)
            locationTimeZone = TimeZoneLocate.timeZoneWithLocation(location)
            updateAndDisplayTimes()
            return
        }

        if !preserveExistingLocation {
            currentCoordinates = nil
            todayTimes = [:]
            tomorrowFajrTime = nil
            lastCalculationDate = nil
            locationStatusText = message
        }

        preserveExistingAutomaticLocationOnFailure = false

        logger.error("\(message, privacy: .public). Services enabled: \(CLLocationManager.locationServicesEnabled(), privacy: .public). Authorization: \(self.authorizationDescription(self.locMgr.authorizationStatus), privacy: .public)")
    }

    private func completeLocationRequest() {
        locationProgressUpdateTask?.cancel()
        locationProgressUpdateTask = nil
        locationRequestTimeoutTask?.cancel()
        locationRequestTimeoutTask = nil
        if isAutomaticLocationUpdateActive {
            logger.info("Stopping continuous CoreLocation updates.")
            locMgr.stopUpdatingLocation()
            isAutomaticLocationUpdateActive = false
        }
        isRequestingLocation = false
    }

    private func authorizationDescription(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorizedAlways: return "authorizedAlways"
        case .authorized: return "authorized"
        @unknown default: return "unknown"
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        logger.info("CoreLocation delegate authorization callback. New status: \(self.authorizationDescription(manager.authorizationStatus), privacy: .public). Services enabled: \(CLLocationManager.locationServicesEnabled(), privacy: .public)")

        if !isUsingManualLocation {
            handleAuthorizationStatus(status: manager.authorizationStatus)
        }
    }

    // --- PERBAIKAN TYPO DI SINI ---
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let nsError = error as NSError
        logger.error("CoreLocation failed. Domain: \(nsError.domain, privacy: .public). Code: \(nsError.code, privacy: .public). Description: \(error.localizedDescription, privacy: .public). Active updates: \(self.isAutomaticLocationUpdateActive, privacy: .public)")

        if let clError = error as? CLError, clError.code == .locationUnknown {
            if isAutomaticLocationUpdateActive {
                if currentCoordinates == nil {
                    locationStatusText = NSLocalizedString("Still finding your location...", comment: "")
                }
                logger.warning("CoreLocation location is temporarily unknown; continuing continuous updates until timeout.")
                return
            }
        }

        let shouldPreserveExistingLocation = preserveExistingAutomaticLocationOnFailure
        completeLocationRequest()

        if !isUsingManualLocation {
            failAutomaticLocation(
                NSLocalizedString("Unable to determine location. Try setting it manually.", comment: ""),
                preserveExistingLocation: shouldPreserveExistingLocation
            )
        }
    }

    func requestLocationPermission() {
        if authorizationStatus == .notDetermined {
            isRequestingLocation = true
            locationStatusText = NSLocalizedString("Requesting Permission...", comment: "")
            logger.info("Requesting when-in-use location authorization and starting location updates to trigger the macOS prompt.")
            DispatchQueue.main.async {
                self.locMgr.requestWhenInUseAuthorization()
                self.requestAutomaticLocation(allowCachedLocation: false)
            }
        } else {
            handleAuthorizationStatus(status: locMgr.authorizationStatus)
        }
    }
    func openLocationSettings() { guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") else { return }; NSWorkspace.shared.open(url) }

    private func coordinateDescription(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
    }
}
