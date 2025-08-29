// Salin dan tempel SELURUH kode ini ke dalam file PrayerTimeViewModel.swift

import Foundation
import Combine
import Adhan
import CoreLocation
import SwiftUI
import MapKit

struct LocationSearchResult: Identifiable {
    let id = UUID()
    let name: String
    let country: String
    let coordinates: CLLocationCoordinate2D
}

enum MenuBarTextMode: String, CaseIterable, Identifiable {
    case countdown = "Countdown"
    case exactTime = "Exact Time"
    case hidden = "Icon Only"
    var id: Self { self }
}

class PrayerTimeViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var menuTitle: String = "Sajda"
    @Published var todayTimes: [String: Date] = [:]
    @Published var nextPrayerName: String = ""
    @Published var countdown: String = "--:--"
    @Published var locationStatusText: String = "Preparing prayer schedule..."
    
    @Published var showSunnahPrayers: Bool {
        didSet {
            UserDefaults.standard.set(showSunnahPrayers, forKey: "showSunnahPrayers")
            updatePrayerTimes()
        }
    }
    
    @Published var useAccentColor: Bool { didSet { UserDefaults.standard.set(useAccentColor, forKey: "useAccentColor") } }
    @Published var isNotificationsEnabled: Bool { didSet { UserDefaults.standard.set(isNotificationsEnabled, forKey: "isNotificationsEnabled"); updateNotifications() } }
    
    @Published var useCompactLayout: Bool { didSet { UserDefaults.standard.set(useCompactLayout, forKey: "useCompactLayout") } }
    @Published var use24HourFormat: Bool { didSet { UserDefaults.standard.set(use24HourFormat, forKey: "use24HourFormat"); updatePrayerTimes() } }
    @Published var useHanafiMadhhab: Bool { didSet { UserDefaults.standard.set(useHanafiMadhhab, forKey: "useHanafiMadhhab"); updatePrayerTimes() } }
    
    @Published var menuBarTextMode: MenuBarTextMode { didSet { UserDefaults.standard.set(menuBarTextMode.rawValue, forKey: "menuBarTextMode"); updateMenuTitle() } }
    @Published var method: CalculationMethod = .karachi { didSet { updatePrayerTimes() } }
    
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var isUsingManualLocation: Bool { didSet { UserDefaults.standard.set(isUsingManualLocation, forKey: "isUsingManualLocation") } }
    private var currentCoordinates: CLLocationCoordinate2D?
    
    private var searchCancellable: AnyCancellable?
    
    private let locMgr = CLLocationManager()
    private var timer: Timer?

    override init() {
        self.showSunnahPrayers = UserDefaults.standard.bool(forKey: "showSunnahPrayers")
        self.useAccentColor = UserDefaults.standard.bool(forKey: "useAccentColor")
        self.isNotificationsEnabled = UserDefaults.standard.bool(forKey: "isNotificationsEnabled")
        
        self.useCompactLayout = UserDefaults.standard.bool(forKey: "useCompactLayout")
        self.use24HourFormat = UserDefaults.standard.bool(forKey: "use24HourFormat")
        self.useHanafiMadhhab = UserDefaults.standard.bool(forKey: "useHanafiMadhhab")
        
        let savedTextMode = UserDefaults.standard.string(forKey: "menuBarTextMode"); self.menuBarTextMode = MenuBarTextMode(rawValue: savedTextMode ?? "") ?? .countdown
        
        self.authorizationStatus = locMgr.authorizationStatus
        self.isUsingManualLocation = UserDefaults.standard.bool(forKey: "isUsingManualLocation")
        
        super.init()
        locMgr.delegate = self
        startLocationProcess()
        startTimer()
    }
    
    func startLocationProcess() {
        if isUsingManualLocation, let manualCoords = loadManualLocation() {
            self.currentCoordinates = manualCoords.coordinates
            self.locationStatusText = manualCoords.name
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.updatePrayerTimes() }
        } else {
            handleAuthorizationStatus(status: locMgr.authorizationStatus)
        }
    }
    
    func setManualLocation(city: String, coordinates: CLLocationCoordinate2D) {
        let manualLocationData: [String: Any] = ["name": city, "latitude": coordinates.latitude, "longitude": coordinates.longitude]
        UserDefaults.standard.set(manualLocationData, forKey: "manualLocationData")
        self.isUsingManualLocation = true
        self.currentCoordinates = coordinates
        self.locationStatusText = city
        self.authorizationStatus = .authorized
        updatePrayerTimes()
    }
    
    func switchToAutomaticLocation() {
        self.isUsingManualLocation = false
        UserDefaults.standard.removeObject(forKey: "manualLocationData")
        self.locationStatusText = "Switching to automatic..."
        self.todayTimes = [:]
        self.currentCoordinates = nil
        if let lastKnownLocation = locMgr.location {
            locationManager(locMgr, didUpdateLocations: [lastKnownLocation])
        }
        if locMgr.authorizationStatus == .notDetermined {
            locMgr.requestWhenInUseAuthorization()
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
    
    func searchLocation(query: String, completion: @escaping ([LocationSearchResult]) -> Void) {
        searchCancellable?.cancel()
        guard !query.isEmpty else { completion([]); return }
        let subject = PassthroughSubject<String, Never>()
        searchCancellable = subject
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .flatMap { currentQuery -> Future<[LocationSearchResult], Never> in
                Future { promise in
                    let request = MKLocalSearch.Request(); request.naturalLanguageQuery = currentQuery; request.resultTypes = .address
                    let search = MKLocalSearch(request: request)
                    search.start { response, _ in
                        guard let response = response else { promise(.success([])); return }
                        let results = response.mapItems.compactMap { item -> LocationSearchResult? in
                            guard let city = item.placemark.locality, let country = item.placemark.country else { return nil }
                            return LocationSearchResult(name: city, country: country, coordinates: item.placemark.coordinate)
                        }.unique(by: \.name)
                        promise(.success(results))
                    }
                }
            }
            .receive(on: RunLoop.main)
            .sink(receiveValue: completion)
        subject.send(query)
    }
    
    private func handleAuthorizationStatus(status: CLAuthorizationStatus) {
        self.authorizationStatus = status
        switch status {
        case .authorized:
            locationStatusText = "Fetching location..."; locMgr.requestLocation()
        case .denied, .restricted:
            locationStatusText = "Location access denied."; menuTitle = "Location needed"
            self.todayTimes = [:]
        case .notDetermined:
            locationStatusText = "Waiting for location access."; menuTitle = "Location needed"
            self.todayTimes = [:]
        @unknown default: break
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { if !isUsingManualLocation { handleAuthorizationStatus(status: manager.authorizationStatus) } }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard !isUsingManualLocation, let location = locs.last else { return }
        self.currentCoordinates = location.coordinate
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
            DispatchQueue.main.async {
                if let city = placemarks?.first?.locality { self.locationStatusText = city }
                else { self.locationStatusText = placemarks?.first?.timeZone?.identifier ?? "Unknown Location" }
                self.updatePrayerTimes()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locationStatusText = "Preparing prayer schedule..."
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if self.currentCoordinates == nil && !self.isUsingManualLocation {
                    self.locationStatusText = "Unable to determine location."; self.menuTitle = "Location Error"
                }
            }
        }
    }
    
    func requestLocationPermission() { if authorizationStatus == .notDetermined { locMgr.requestWhenInUseAuthorization() } }
    
    func openLocationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") else { return }
        NSWorkspace.shared.open(url)
    }
    
    func updatePrayerTimes() {
        guard let coord = currentCoordinates else { return }
        
        let cal = Calendar(identifier: .gregorian)
        var params = method.params
        params.madhab = self.useHanafiMadhhab ? .hanafi : .shafi
        let today = Date()
        
        let todayDC = cal.dateComponents([.year, .month, .day], from: today)
        guard let prayersToday = PrayerTimes(coordinates: Coordinates(latitude: coord.latitude, longitude: coord.longitude), date: todayDC, calculationParameters: params),
              let tomorrowDate = cal.date(byAdding: .day, value: 1, to: today),
              let prayersTomorrow = PrayerTimes(
                coordinates: Coordinates(latitude: coord.latitude, longitude: coord.longitude),
                date: cal.dateComponents([.year, .month, .day], from: tomorrowDate),
                calculationParameters: params
              ) else { return }
        
        var allPrayerTimes: [(name: String, time: Date)] = [
            ("Fajr", prayersToday.fajr),
            ("Dhuhr", prayersToday.dhuhr),
            ("Asr", prayersToday.asr),
            ("Maghrib", prayersToday.maghrib),
            ("Isha", prayersToday.isha)
        ]
        
        if showSunnahPrayers {
            let nightDuration = prayersTomorrow.fajr.timeIntervalSince(prayersToday.isha)
            let lastThirdOfNightStart = prayersToday.isha.addingTimeInterval(nightDuration * (2/3.0))
            allPrayerTimes.append(("Tahajud", lastThirdOfNightStart))
            
            let dhuhaTime = prayersToday.sunrise.addingTimeInterval(20 * 60)
            allPrayerTimes.append(("Dhuha", dhuhaTime))
        }
        
        allPrayerTimes.sort { $0.time < $1.time }
        
        let nextPrayer = allPrayerTimes.first { $0.time > today }
        
        DispatchQueue.main.async {
            self.todayTimes = Dictionary(uniqueKeysWithValues: allPrayerTimes.map { ($0.name, $0.time) })

            if let nextPrayer = nextPrayer {
                self.nextPrayerName = nextPrayer.name
            } else {
                self.recalculateForTomorrow()
                return
            }
            
            self.updateCountdown()
            self.updateNotifications()
        }
    }
    
    private func recalculateForTomorrow() {
        guard let coord = currentCoordinates else { return }
        let cal = Calendar(identifier: .gregorian)
        var params = method.params
        params.madhab = self.useHanafiMadhhab ? .hanafi : .shafi
        guard let tomorrowDate = cal.date(byAdding: .day, value: 1, to: Date()),
              let prayersTomorrow = PrayerTimes(
                coordinates: Coordinates(latitude: coord.latitude, longitude: coord.longitude),
                date: cal.dateComponents([.year, .month, .day], from: tomorrowDate),
                calculationParameters: params
              ) else { return }
        
        self.nextPrayerName = "Fajr"
        self.todayTimes = [
            "Fajr": prayersTomorrow.fajr, "Dhuhr": prayersTomorrow.dhuhr, "Asr": prayersTomorrow.asr,
            "Maghrib": prayersTomorrow.maghrib, "Isha": prayersTomorrow.isha
        ]

        if showSunnahPrayers {
            guard let dayAfterTomorrow = cal.date(byAdding: .day, value: 1, to: tomorrowDate),
                  let prayersDayAfter = PrayerTimes(
                    coordinates: Coordinates(latitude: coord.latitude, longitude: coord.longitude),
                    date: cal.dateComponents([.year, .month, .day], from: dayAfterTomorrow),
                    calculationParameters: params
                  ) else { return }
            
            let nightDuration = prayersDayAfter.fajr.timeIntervalSince(prayersTomorrow.isha)
            self.todayTimes["Tahajud"] = prayersTomorrow.isha.addingTimeInterval(nightDuration * (2/3.0))
            self.todayTimes["Dhuha"] = prayersTomorrow.sunrise.addingTimeInterval(20 * 60)
        }
        
        self.updateCountdown()
        self.updateNotifications()
    }

    private func updateCountdown() {
        guard !nextPrayerName.isEmpty, let nextDate = todayTimes[nextPrayerName] else {
            countdown = "--:--"; updateMenuTitle(); return
        }
        let diff = Int(nextDate.timeIntervalSince(Date()))
        if diff > 0 {
            let h = diff / 3600; let m = (diff % 3600) / 60
            countdown = h > 0 ? String(format: "%dh %dm", h, m + 1) : String(format: "%dm", m + 1)
        } else {
            countdown = "Now"; DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.updatePrayerTimes() }
        }
        updateMenuTitle()
    }
    
    func updateMenuTitle() {
        var textToShow = ""
        if !isPrayerDataAvailable {
            textToShow = "Sajda"
        } else {
            switch menuBarTextMode {
            case .hidden:
                textToShow = ""
            case .countdown:
                textToShow = "\(nextPrayerName) in \(countdown)"
            case .exactTime:
                if let nextDate = todayTimes[nextPrayerName] {
                    textToShow = "\(nextPrayerName) at \(dateFormatter.string(from: nextDate))"
                } else {
                    textToShow = "Sajda"
                }
            }
        }
        self.menuTitle = textToShow
    }
    
    var isPrayerDataAvailable: Bool {
        return !todayTimes.isEmpty
    }
    
    func startTimer() { timer?.invalidate(); timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.updateCountdown() } }
    
    private func updateNotifications() {
        guard isNotificationsEnabled, !todayTimes.isEmpty else { NotificationManager.cancelNotifications(); return }
        NotificationManager.requestPermission()
        let prayerOrder = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha", "Tahajud", "Dhuha"]
        NotificationManager.scheduleNotifications(for: todayTimes, prayerOrder: prayerOrder)
    }
    
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter(); formatter.timeStyle = .short
        formatter.locale = use24HourFormat ? Locale(identifier: "en_GB") : Locale(identifier: "en_US")
        return formatter
    }
}

extension Sequence {
    func unique<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        var set = Set<T>()
        return filter { set.insert($0[keyPath: keyPath]).inserted }
    }
}
