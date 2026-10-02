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
    /// Seconds-precision countdown shown in the big panel header.
    @Published var detailedCountdown: String = "--:--:--"
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

    /// Locale used for all user-visible numbers and times. Arabic renders
    /// with Eastern Arabic numerals (٠١٢٣٤٥٦٧٨٩); other languages keep
    /// their default numbering system.
    private var displayLocale: Locale {
        languageManager.language == "ar" ? Locale(identifier: "ar_EG") : Locale(identifier: languageManager.language)
    }
    private let logger = Logger(subsystem: "com.madda.Sajda", category: "Location")
    private var automaticLocationCache: (name: String, coordinates: CLLocationCoordinate2D)?
    private var tomorrowFajrTime: Date?

    @AppStorage("animationType") var animationType: AnimationType = .fade
    /// Selected Settings tab (Display / Appearance / Prayer / System),
    /// persisted so a NavigationStack pop can't reset it mid-exit: the library
    /// swaps its content branch when the precede flag flips, which recreates
    /// the pushed SettingsView with fresh @State — a fresh `.display` is what
    /// used to flash over Appearance during the fade back to Main.
    /// Republishes on every write: Settings' tab bar is a dropdown, so this is
    /// what repaints the page with the picked tab's rows. It is *not* part of
    /// `SajdaControlCenterMenu.panelLayoutSignature` — the swap snaps (see the
    /// note there), so the panel takes the new height in the same layout pass
    /// as the click instead of easing between two tab heights.
    @AppStorage("settingsSelectedTab") var settingsSelectedTab: String = "display" { didSet { objectWillChange.send() } }
    /// When on, reopening Settings keeps the last-used tab; when off, Settings
    /// always opens on Display.
    @AppStorage("settingsTabLocked") var settingsTabLocked: Bool = false

    /// Resets the Settings tab to Display when it is *not* locked, without
    /// animating the change.
    ///
    /// The tab no longer keys `panelLayoutSignature`, so nothing animated
    /// drives this write any more; the `disablesAnimations` transaction stays
    /// as the guarantee that a reset landing while the panel is opening can
    /// never ease a resize mid-open — the flicker this used to guard against —
    /// whatever transaction a caller happens to be in. Locked sessions keep
    /// their last-used tab, so this is a no-op for them.
    func resetSettingsTabToDisplay() {
        guard !settingsTabLocked else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            settingsSelectedTab = SettingsView.SettingsSection.display.rawValue
        }
    }
    /// Whether Settings > Appearance's colour surface is dropped down under the
    /// "Custom Color" row. On the view model rather than in the view's `@State`
    /// because it is part of `SajdaControlCenterMenu.panelLayoutSignature`: that
    /// is what animates the panel's height as the dropdown opens instead of
    /// letting the window snap — and NavigationStack's page recreation would
    /// otherwise lose it mid-pop.
    @Published var settingsColorPickerOpen: Bool = false
    @AppStorage("useMinimalMenuBarText") var useMinimalMenuBarText: Bool = false { didSet { updateAndDisplayTimes() } }
    @AppStorage("showSunnahPrayers") var showSunnahPrayers: Bool = false { didSet { updatePrayerTimes() } }
    @AppStorage("useAccentColor") var useAccentColor: Bool = true
    /// Draws the per-prayer mute ring in the system secondary colour even in
    /// accent mode. Off by default, so accent mode looks as it always has; on,
    /// the accent is spent on the next-prayer highlight alone and the five rings
    /// stop competing with the time column for attention.
    @AppStorage("dimMuteButton") var dimMuteButton: Bool = false
    /// Ring + dot colour for the per-prayer mute icon on a *non*-highlighted
    /// prayer row — the one place that decides it, so the panel and the Adhan
    /// Sound page can't drift apart again.
    ///
    /// System secondary whenever the accent isn't in play (accent mode off, or
    /// "Dim Mute Button" on). The highlighted row is excluded by its callers: it
    /// sits on the highlight fill, where only the row's own text colour is
    /// reliably readable.
    var muteIconColor: Color {
        guard useAccentColor, !dimMuteButton else { return .secondary }
        // Contrast-safe pick: a pale highlight still fills rows fine (paired
        // with on-fill text) but vanishes as a thin ring on the panel (#24).
        return legibleInteractiveAccent
    }
    /// Whether the mute ring gets the dimmed treatment (ring 0.55 / dot 0.85) at
    /// all. Only when the ring is already the calm system secondary — accent
    /// mode off, or "Dim Mute Button" on. In plain accent mode nothing is
    /// dimmed: the ring keeps the accent at full strength, exactly as it always
    /// has, because the accent is the user's own chosen colour and lightening
    /// it to 55% would quietly change what they picked.
    var isMuteIconDimmed: Bool {
        !useAccentColor || dimMuteButton
    }
    /// Colour for the muted dot when it has to step down from `muteIconColor`:
    /// the system secondary, in plain accent mode only.
    ///
    /// `muteIconColor` already returns `.secondary` in the other two modes, so
    /// the dot is secondary there for free. Plain accent mode is the odd one
    /// out — the ring is the user's accent at full strength, and a muted dot in
    /// that same accent put the next-prayer highlight's colour on every muted
    /// row, so muting four of five still read as "all highlighted". There the
    /// dot drops to the calm secondary. `nil` elsewhere keeps the icon's
    /// one-colour rule.
    var mutedMuteDotColor: Color? {
        (useAccentColor && !dimMuteButton) ? .secondary : nil
    }
    /// Which glyph the per-prayer mute button draws. Stored as a raw String (not
    /// the enum) so a value from a newer build, or a hand-edited pref, falls
    /// back to `.halo` instead of failing the row.
    ///
    /// Default `.halo` — what the panel has always shown, so existing installs
    /// are unaffected.
    @AppStorage("muteIconStyle") var muteIconStyleRaw: String = MuteIconStyle.halo.rawValue {
        didSet { objectWillChange.send() }
    }

    /// Typed form of `muteIconStyleRaw`.
    var muteIconStyle: MuteIconStyle {
        get { MuteIconStyle(rawValue: muteIconStyleRaw) ?? .halo }
        set { muteIconStyleRaw = newValue.rawValue }
    }
    /// Whether "Dim Mute Button" can do anything at all right now.
    ///
    /// Two ways it can't, one already covered by `muteIconColor` (accent mode
    /// off makes the icon secondary regardless) and one new: `MuteIconStyle.none`
    /// draws no icon, so there is no ring to dim. Both dim and disable the row
    /// rather than hiding it, so the row order never shifts under the user, and
    /// neither clears `dimMuteButton` — switching back to a visible style
    /// restores whatever was chosen.
    var canDimMuteButton: Bool {
        useAccentColor && muteIconStyle != .none
    }
    /// User-picked next-prayer highlight color ("#RRGGBB"); empty = accent default.
    @AppStorage("customHighlightColorHex") var customHighlightColorHex: String = ""
    /// Shows the big countdown header above the panel schedule.
    @AppStorage("showCountdownHeader") var showCountdownHeader: Bool = true
    /// Letak baris lokasi di panel. Default `.top` — lokasi jadi bagian kepala
    /// panel, terpisah dari daftar shalat, dan pemisah membagi kepala dari isi.
    /// Nilai disimpan sebagai String (bukan enum) supaya nilai baru atau yang
    /// rusak tidak membuat panel gagal total — nilai tak dikenal jatuh ke
    /// `.top` lewat aksesor bertipe di bawah.
    ///
    /// `objectWillChange` diperlukan karena baris ini memengaruhi tata letak,
    /// bukan hanya isi teks: tanpa itu, panel yang sedang terbuka tidak akan
    /// menggambar ulang saat posisinya diganti.
    @AppStorage("locationRowPosition") var locationRowPositionRaw: String = LocationRowPosition.top.rawValue {
        didSet { objectWillChange.send() }
    }

    /// Bentuk bertipe dari `locationRowPositionRaw`, dengan nilai tak dikenal
    /// dipetakan ke `.top` supaya perubahan ke depan tidak(ERROR) membebankan
    /// pengguna yang nilainya sudah tersimpan.
    var locationRowPosition: LocationRowPosition {
        get { LocationRowPosition(rawValue: locationRowPositionRaw) ?? .top }
        set { locationRowPositionRaw = newValue.rawValue }
    }
    /// When on, the whole menu bar panel is tinted with the accent colour and
    /// the panel's colour scheme flips to keep everything balanced against it
    /// (`accentPanelColorScheme` / `accentPanelTint`).
    @AppStorage("accentPanelTheme") var accentPanelTheme: Bool = false
    /// Day shift for the header Hijri date, set with the +/- stepper in
    /// Settings. Defaults to 0 (Umm al-Qura as-is); some locales announce the
    /// new month a day off, so this nudges it without touching the
    /// prayer-time source. Republishes so the header redraws immediately.
    @AppStorage("hijriDateAdjustment") var hijriDateAdjustment: Int = 0 { didSet { objectWillChange.send() } }
    /// Lead time in minutes for the red imminent alert; 0 disables it.
    /// Keeps the former `RedAlertTiming` menu's defaults key (and Int value)
    /// so existing choices carry over. Republishes because the Settings
    /// +/- stepper must redraw immediately.
    @AppStorage("redAlertTiming") var redAlertMinutes: Int = 10 { didSet { objectWillChange.send() } }
    /// When on, the Jumu'ah sessions row shows under Dhuhr every day — not
    /// just Fridays — so travellers can plan ahead. Republishes so the panel
    /// redraws the moment the toggle flips.
    @AppStorage("alwaysShowJumuah") var alwaysShowJumuah: Bool = false { didSet { objectWillChange.send() } }
    /// Downloaded Mawaqit mosque schedule; loaded from disk on first use.
    @Published var mawaqitMosque: MawaqitMosque?
    /// Saved favorite cities + mosque timetables (max 5), loaded from disk.
    @Published var favoritePlaces: [FavoritePlace] = FavoritePlace.load()
    /// True once the user has ever starred a favorite (persists after
    /// removal) — drives the first-run guide hint on the main screen.
    @AppStorage("hasEverSavedFavorite") var hasEverSavedFavorite: Bool = false
    /// Slug of a favorite mosque currently downloading (spinner in the list).
    @Published var favoriteMosqueLoadingSlug: String?
    /// Read-only view of the active coordinates for favorite matching.
    var currentCoordinatesForFavorites: CLLocationCoordinate2D? { currentCoordinates }
    /// When true the panel, menu bar, and notifications read the mosque
    /// calendar instead of calculating from coordinates.
    @AppStorage("useMawaqitSchedule") var useMawaqitSchedule: Bool = false { didSet { updatePrayerTimes() } }
    // Gaya Liquid Glass di atas highlight waktu sholat berikutnya (opsional).
    @AppStorage("useGlassPrayerHighlight") var useGlassPrayerHighlight: Bool = true
    @AppStorage("isNotificationsEnabled") var isNotificationsEnabled: Bool = true { didSet { updateNotifications() } }
    @AppStorage("useCompactLayout") var useCompactLayout: Bool = false
    /// True once the user has set Compact View by hand — from *any* page that
    /// exposes the toggle, or the "Turn On" button on the accessibility page.
    /// Compact view is also flipped automatically for the big text presets, and
    /// this flag is what tells the two apart. The rule is deliberately blunt:
    /// once the user has touched it, the text size never changes it again; until
    /// then, the big presets own it. One rule, no special cases — the earlier
    /// version tried to be clever about "on vs off" and behaved unpredictably.
    @AppStorage("compactLayoutChosenByUser") var compactLayoutChosenByUser: Bool = false
    @AppStorage("panelTextSize") var panelTextSize: PanelTextSize = .default {
        didSet {
            guard !compactLayoutChosenByUser else { return }
            useCompactLayout = panelTextSize.fontScale >= PanelTextSize.large.fontScale
        }
    }

    /// The single way views should flip Compact View: sets the value *and*
    /// records that the user asked for it, so the text size stops managing it.
    /// Use this instead of assigning `useCompactLayout` directly from any
    /// control the user can actually press.
    func setCompactLayout(_ enabled: Bool) {
        useCompactLayout = enabled
        compactLayoutChosenByUser = true
    }

    /// True when the text is big enough that compact view is worth suggesting —
    /// i.e. one of the big presets is on and compact view is not already on.
    /// Drives the "we recommend this" note on the accessibility page.
    var recommendsCompactLayout: Bool {
        panelTextSize.fontScale >= PanelTextSize.large.fontScale && !useCompactLayout
    }

    // Aksesibilitas (Settings > Accessibility): teks yang lebih mudah dibaca
    // untuk pengguna low-vision. Ketiganya menyegarkan judul menu bar karena
    // bobot/uppercase/ukuran memengaruhi teks di sana juga.
    @AppStorage("accessibilityBoldText") var accessibilityBoldText: Bool = false { didSet { updateMenuTitle() } }
    @AppStorage("accessibilityUppercaseText") var accessibilityUppercaseText: Bool = false { didSet { updateMenuTitle() } }
    @AppStorage("menuBarLargerText") var menuBarLargerText: Bool = false { didSet { updateMenuTitle() } }
    /// Ticks the menu bar countdown with seconds (`Fajr in 25:03`) instead of
    /// whole minutes. Only meaningful for the countdown text modes.
    @AppStorage("menuBarShowSeconds") var menuBarShowSeconds: Bool = false { didSet { updateMenuTitle() } }
    @AppStorage("use24HourFormat") var use24HourFormat: Bool = false { didSet { updateAndDisplayTimes() } }

    /// Lebar panel yang diskalakan sesuai ukuran teks terpilih agar font
    /// yang lebih besar tidak terpotong.
    func panelWidth(base: CGFloat) -> CGFloat {
        return (base * panelTextSize.widthMultiplier).rounded()
    }
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
    @Published var highLatitudeRuleSetting: HighLatitudeRuleSetting { didSet { UserDefaults.standard.set(highLatitudeRuleSetting.rawValue, forKey: "highLatitudeRuleSetting"); updatePrayerTimes() } }
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
        self.menuBarTextMode = MenuBarTextMode(rawValue: savedTextMode ?? "") ?? .iconExactTime
        let savedHighLatitudeRule = UserDefaults.standard.string(forKey: "highLatitudeRuleSetting")
        self.highLatitudeRuleSetting = HighLatitudeRuleSetting(rawValue: savedHighLatitudeRule ?? "") ?? .recommended
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
        setupLanguageRefresh()
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
        case .slide: return .sajdaPush
        }
    }

    func backwardAnimation() -> NavigationAnimation? {
        switch animationType {
        case .none: return nil
        case .fade: return .sajdaCrossfade
        case .slide: return .sajdaPop
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
        // Leaving mosque-timetable mode: the picked coordinates are the new
        // source. (Setting this last recalculates from the fresh coords via
        // its didSet; setting it earlier would recalc from stale ones.)
        currentCoordinates = coordinates
        useMawaqitSchedule = false
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
            self.locationTimeZone = .current
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
        // Coordinates go before the flag that recalculates from them:
        // `useMawaqitSchedule`'s didSet runs `updatePrayerTimes()`, and with the
        // old source's coordinates still set that queued a write of the very
        // times being left behind — which landed *after* this switch and
        // repainted the panel with them. Cleared first, that recalculation
        // returns at the coordinates guard instead.
        currentCoordinates = nil
        // Leaving mosque-timetable mode: automatic location is the new source.
        useMawaqitSchedule = false

        lastCalculationDate = nil
        locationInfoText = ""
        locationTimeZone = .current
        locationStatusText = NSLocalizedString("Finding your location...", comment: "")

        // `todayTimes` and `tomorrowFajrTime` are deliberately *not* cleared
        // here, and that is the whole fix for the flicker. They used to be, and
        // `isPrayerDataAvailable` is `!todayTimes.isEmpty` — so the clear took
        // the prayer rows, the countdown header and the location row out of the
        // panel for the frame (or the whole location request) before the
        // replacement landed: the panel collapsed to its header and grew back.
        // That is why *into* automatic flickered while mosque → manual and
        // manual → mosque, which never cleared, stayed smooth. The previous
        // source's times now stand until the replacement is applied in place —
        // the same preservation `failAutomaticLocation` already does when a
        // location request fails — and if this request *does* fail, the manual
        // fallback saved above restores the times that go with it.

        if let cache = automaticLocationCache {
            UserDefaults.standard.removeObject(forKey: "manualLocationData")
            manualLocationFallbackForAutomaticSwitch = nil
            currentCoordinates = cache.coordinates
            locationStatusText = cache.name
            locationTimeZone = .current
            updateAndDisplayTimes()
        } else if locMgr.authorizationStatus == .notDetermined {
            // Picking "Use Automatic Location" *is* the ask for the location,
            // so the system prompt has to come from this tap. Routing it
            // through `handleAuthorizationStatus` instead only set the caption
            // to "Location access needed" and left the actual prompt to a
            // second tap on the permission page — the "I have to click it
            // twice" behaviour. Startup still goes through
            // `startLocationProcess` → `handleAuthorizationStatus`, so the
            // app never prompts on its own.
            requestLocationPermission()
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
        locationTimeZone = .current
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
        // Reset played prayers when day changes or prayer times are recalculated
        if let lastDate = lastCalculationDate,
           !Calendar.current.isDate(lastDate, inSameDayAs: Date()) {
            AdhanAudioPlayer.shared.resetPlayedPrayers()
        }
        lastCalculationDate = Date()

        // Mosque timetable (Mawaqit): runs fully offline from the downloaded
        // calendar and needs no coordinates. Falls through to the calculated
        // path when the calendar doesn't cover today (e.g. Dec 31 before the
        // mosque publishes the new year).
        if mawaqitMosque == nil { mawaqitMosque = MawaqitService.load() }
        if useMawaqitSchedule, let mosque = mawaqitMosque {
            if let day = MawaqitService.times(for: Date(), in: mosque.calendar) {
                applyMawaqitDay(day, mosque: mosque)
                return
            }
            logger.warning("Mawaqit calendar does not cover today; using calculated times.")
        }

        guard let coord = currentCoordinates else { return }

        var locationCalendar = Calendar(identifier: .gregorian); locationCalendar.timeZone = self.locationTimeZone
        let todayInLocation = locationCalendar.dateComponents([.year, .month, .day], from: Date())
        let tomorrowInLocation = locationCalendar.date(byAdding: .day, value: 1, to: Date())!
        let tomorrowDC = locationCalendar.dateComponents([.year, .month, .day], from: tomorrowInLocation)
        var params = method.params; params.madhab = self.useHanafiMadhhab ? .hanafi : .shafi; params.highLatitudeRule = highLatitudeRuleSetting.adhanRule
        guard let prayersToday = PrayerTimes(coordinates: Coordinates(latitude: coord.latitude, longitude: coord.longitude), date: todayInLocation, calculationParameters: params),
              let prayersTomorrow = PrayerTimes(coordinates: Coordinates(latitude: coord.latitude, longitude: coord.longitude), date: tomorrowDC, calculationParameters: params) else { return }

        let correctedFajr = prayersToday.fajr.addingTimeInterval(fajrCorrection * 60)
        let correctedDhuhr = prayersToday.dhuhr.addingTimeInterval(dhuhrCorrection * 60)
        let correctedAsr = prayersToday.asr.addingTimeInterval(asrCorrection * 60)
        let correctedMaghrib = prayersToday.maghrib.addingTimeInterval(maghribCorrection * 60)
        let correctedIsha = prayersToday.isha.addingTimeInterval(ishaCorrection * 60)

        var allPrayerTimes: [(name: String, time: Date)] = [("Fajr", correctedFajr), ("Dhuhr", correctedDhuhr), ("Asr", correctedAsr), ("Maghrib", correctedMaghrib), ("Isha", correctedIsha)]

        if showSunnahPrayers {
            // Tahajud is the last third of the night that is ongoing *now*.
            // Between midnight and today's Fajr that night began at
            // *yesterday's* Isha; anchoring unconditionally to today's Isha
            // put the entry a full day ahead in that window, so the sorted
            // next-prayer search saw it too far away and fell through to
            // highlighting Fajr instead of the Tahajud hours away.
            let now = Date()
            let nightStart: Date
            let nightEnd: Date
            if now < correctedFajr,
               let yesterdayInLocation = locationCalendar.date(byAdding: .day, value: -1, to: now),
               let prayersYesterday = PrayerTimes(coordinates: Coordinates(latitude: coord.latitude, longitude: coord.longitude),
                                                   date: locationCalendar.dateComponents([.year, .month, .day], from: yesterdayInLocation),
                                                   calculationParameters: params) {
                nightStart = prayersYesterday.isha.addingTimeInterval(ishaCorrection * 60)
                nightEnd = correctedFajr
            } else {
                nightStart = correctedIsha
                nightEnd = prayersTomorrow.fajr.addingTimeInterval(fajrCorrection * 60)
            }
            let nightDuration = nightEnd.timeIntervalSince(nightStart)
            let lastThirdOfNightStart = nightStart.addingTimeInterval(nightDuration * (2/3.0))
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

    /// Builds today's times from a mosque calendar day
    /// `[fajr, sunrise, dhuhr, asr, maghrib, isha]` ("HH:MM", Mac timezone).
    private func applyMawaqitDay(_ day: [String], mosque: MawaqitMosque) {
        guard day.count >= 6,
              let rawFajr = dateFromHM(day[0]), let rawDhuhr = dateFromHM(day[2]),
              let rawAsr = dateFromHM(day[3]), let rawMaghrib = dateFromHM(day[4]),
              let rawIsha = dateFromHM(day[5]) else {
            logger.warning("Mawaqit day entry incomplete; keeping previous times.")
            return
        }

        // The mosque's published times are the answer in timetable mode, so
        // the adhan offsets are deliberately *not* applied here: there is no
        // calculated time here to bring into line with the local mosque, and
        // shifting a mosque's own times only makes them wrong. The offsets stay
        // stored and apply again the moment calculated times come back — which
        // is why the Time Correction page greys this tab out while a timetable
        // is active (see `isMosqueTimetableActive`).
        let fajr = rawFajr
        let dhuhr = rawDhuhr
        let asr = rawAsr
        let maghrib = rawMaghrib
        let isha = rawIsha

        // Tomorrow's Fajr for the after-Isha highlight. At the year's edge the
        // new calendar may not be published yet, so fall back to today's Fajr
        // clock time on tomorrow's date (the estimate the Mawaqit applet uses).
        let tomorrow = Date().addingTimeInterval(86_400)
        let fajrTomorrow = MawaqitService.times(for: tomorrow, in: mosque.calendar)
            .flatMap { dateFromHM($0[0], on: tomorrow) }
            ?? dateFromHM(day[0], on: tomorrow)
            ?? rawFajr.addingTimeInterval(86_400)

        // Sunnah prayers stay usable in mosque mode, counted locally: Tahajud
        // from the *ongoing* night, and Dhuha 20 minutes after the mosque's
        // sunrise. Both are derived from the mosque's own times, so neither
        // carries an adhan offset.
        var extras: [(name: String, time: Date)] = []
        if showSunnahPrayers {
            // Which night is "ongoing" is the whole trick, and it depends on
            // where we are in the day. Before Fajr it is last night's, running
            // into this morning's Fajr; after Fajr the night that *will* run is
            // this evening's Isha into tomorrow's Fajr. Anchoring to today's
            // Isha unconditionally would put the row a full day ahead once
            // Fajr had passed, and anchoring only to the before-Fajr window (as
            // this used to) dropped Tahajud from the panel for the rest of the
            // day — the row simply vanished until the small hours.
            //
            // `nightEnd` is the *upcoming* Fajr, which `fajrTomorrow` already
            // resolves, so the night is a real span of hours rather than a
            // guess from today's clock time.
            let now = Date()
            let nightStart: Date
            let nightEnd: Date
            if now < fajr {
                let yesterday = now.addingTimeInterval(-86_400)
                if let yesterdayDay = MawaqitService.times(for: yesterday, in: mosque.calendar),
                   yesterdayDay.count >= 6,
                   let yesterdayIsha = dateFromHM(yesterdayDay[5], on: yesterday) {
                    nightStart = yesterdayIsha
                    nightEnd = fajr
                } else {
                    // Yesterday's calendar is missing (the year's first night,
                    // before the new month is published): use tonight's instead.
                    nightStart = isha
                    nightEnd = fajrTomorrow
                }
            } else {
                // After Fajr: the night that *will* run is this evening's Isha
                // into tomorrow's Fajr. Anchoring to last night here would show
                // a night that has already ended, and skipping the row entirely
                // — as this once did — dropped Tahajud from the panel for the
                // whole day.
                nightStart = isha
                nightEnd = fajrTomorrow
            }
            let nightDuration = nightEnd.timeIntervalSince(nightStart)
            if nightDuration > 0 {
                extras.append(("Tahajud", nightStart.addingTimeInterval(nightDuration * (2 / 3.0))))
            }
            if let sunrise = dateFromHM(day[1]) {
                extras.append(("Dhuha", sunrise.addingTimeInterval(20 * 60)))
            }
        }

        var entries: [(name: String, time: Date)] = [
            ("Fajr", fajr), ("Dhuhr", dhuhr), ("Asr", asr),
            ("Maghrib", maghrib), ("Isha", isha),
        ]
        entries.append(contentsOf: extras)
        DispatchQueue.main.async {
            self.todayTimes = Dictionary(uniqueKeysWithValues: entries.map { ($0.name, $0.time) })
            self.tomorrowFajrTime = fajrTomorrow
            self.updateNextPrayer()
            self.updateNotifications()
        }
    }

    /// Parses "HH:MM" into a Date on the given day (Mac timezone).
    private func dateFromHM(_ hm: String, on day: Date = Date()) -> Date? {
        let parts = hm.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        var comps = cal.dateComponents([.year, .month, .day], from: day)
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        return cal.date(from: comps)
    }

    /// Re-downloads the active mosque's calendar and re-applies it. Mawaqit
    /// edits a mosque's Jumu'ah and iqama entries during the year, so a
    /// schedule picked up months ago goes stale until it's re-fetched. A
    /// failed refresh leaves the existing schedule untouched — the panel keeps
    /// showing the times it already had rather than emptying out.
    ///
    /// Re-entrant calls are ignored, so a double click on the footer's refresh
    /// doesn't fire two downloads.
    ///
    /// `@MainActor` is load-bearing, not decoration: the view model class
    /// itself isn't main-actor isolated, so without it this function would
    /// resume on a background executor after `await`ing the download and
    /// publish `isRefreshingMosqueSchedule` (and the re-activated schedule)
    /// off the main thread — which SwiftUI rejects outright. The class has
    /// other async members with the same constraint; see
    /// `handleAutomaticLocation` and `downloadMosque` in the picker.
    @Published var isRefreshingMosqueSchedule: Bool = false
    @MainActor
    func refreshActiveMosqueSchedule() async {
        guard let slug = mawaqitMosque?.slug, !isRefreshingMosqueSchedule else { return }
        isRefreshingMosqueSchedule = true
        defer { isRefreshingMosqueSchedule = false }
        do {
            let mosque = try await MawaqitService.fetchCalendar(slug: slug)
            activateMosqueSchedule(mosque)
            logger.info("Refreshed Mawaqit schedule for \(slug, privacy: .public).")
        } catch {
            logger.error("Mawaqit refresh failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Persists and activates a downloaded mosque schedule.
    ///
    /// Writes *both* the active file and the per-favorite cache, and merges
    /// first (see `MawaqitService.enriched`). Activating from a favorite used
    /// to read a cache that could be years older than what the user had just
    /// downloaded and then overwrite the newer active file with it, so the
    /// Jumu'ah footer vanished on a mosque → city → mosque round trip and only
    /// came back with a refresh. Keeping the two files in step is what makes
    /// that round trip free and works offline.
    func activateMosqueSchedule(_ mosque: MawaqitMosque) {
        let enriched = MawaqitService.enriched(mosque)
        do {
            try MawaqitService.save(enriched)
            // Same payload into the per-slug cache, so tapping this mosque in
            // Favorites later hands back exactly what is on screen now.
            try MawaqitService.saveToCache(enriched)
        } catch {
            logger.error("Failed to save Mawaqit schedule: \(error.localizedDescription, privacy: .public)")
        }
        mawaqitMosque = enriched
        useMawaqitSchedule = true   // didSet → updatePrayerTimes()
    }

    /// Drops back to coordinate-based calculation (the file is kept for reuse).
    /// When there are no coordinates to calculate from (e.g. location was
    /// never granted), starts the location flow so the user lands on a live
    /// permission/search state instead of stale timetable times.
    func disableMosqueSchedule() {
        useMawaqitSchedule = false  // didSet → updatePrayerTimes()
        if currentCoordinates == nil && !isUsingManualLocation {
            startLocationProcess()
        }
    }

    /// Where the panel prints the iqama gap relative to each prayer time, or
    /// that it doesn't.
    ///
    /// Empty by default — the *position* default is derived from the active
    /// timing source rather than baked in here (see `defaultIqamaDelayPosition`),
    /// because a gap is only meaningful in one of the two modes: a mosque
    /// timetable publishes the real iqama, while calculated times carry only a
    /// user-entered estimate. Storing nothing is what lets that choice follow
    /// the mode instead of being frozen at first launch.
    ///
    /// Republishes because the rows are already laid out — a change here is a
    /// redraw, not new data.
    @AppStorage("iqamaDelayPosition") var iqamaDelayPositionRaw: String = "" {
        didSet { objectWillChange.send() }
    }

    /// Typed form of `iqamaDelayPositionRaw`.
    var iqamaDelayPosition: IqamaDelayPosition {
        get { IqamaDelayPosition(rawValue: iqamaDelayPositionRaw) ?? defaultIqamaDelayPosition }
        set { iqamaDelayPositionRaw = newValue.rawValue }
    }

    /// The position used while nothing has been chosen: shown on the right, but
    /// only under a mosque timetable.
    ///
    /// Under calculated times there is no iqama to show at all (see
    /// `displayedIqamaDelay(for:)`), so the position is moot and the panel draws
    /// nothing whatever this says. Right is the mosque default because a
    /// published gap reads best as one clock: "13:53 +8".
    var defaultIqamaDelayPosition: IqamaDelayPosition {
        .trailing
    }

    /// Jumu'ah session times as minutes past midnight in the shown timezone,
    /// kept as a free list in Settings so mosques with several Friday
    /// sessions can list them all (at most `maxJumuahSessions`). Empty means
    /// "no Jumu'ah row": the panel never invents session times.
    @AppStorage("jumuahSessions") var jumuahSessionsJSON: String = "[]" { didSet { objectWillChange.send() } }

    /// Listing cap — one or two Friday sessions is the norm; five stays
    /// generous while keeping the panel row a single clean line.
    static let maxJumuahSessions = 5

    /// The gap the panel prints beside a prayer time — "+8" — or nothing.
    ///
    /// Only ever a number the mosque itself publishes. With calculated times
    /// (automatic or manual location) there is no iqama to know: the app can
    /// compute an adhan, but *when the imam stands up* is not derivable from
    /// coordinates, and printing an invented one on every row is worse than
    /// printing nothing — a worshipper who trusts "+8" and arrives eight minutes
    /// late has been actively misled. So this returns `nil` unless a mosque
    /// timetable is active.
    ///
    /// Sunnah prayers (Tahajud, Dhuha) have no congregation, so no iqama and no
    /// gap for them even in mosque mode. A zero gap is also `nil` — a mosque that
    /// opens straight after the adhan has no delay to report, and "+0" is noise.
    ///
    /// Returned as `Int?` rather than a formatted string so the row draws the
    /// number in its own font and the accessibility label can reuse it.
    func displayedIqamaDelay(for prayer: String) -> Int? {
        guard isMosqueTimetableActive,
              iqamaDelayPosition != .none,
              Self.congregationalPrayers.contains(prayer),
              let minutes = publishedIqamaDelay(for: prayer)
        else { return nil }
        return minutes > 0 ? minutes : nil
    }

    /// The gap the mosque itself publishes for `prayer`, or `nil` when there is
    /// no mosque timetable or it publishes no gap for that prayer.
    ///
    /// The only iqama source left in the app, deliberately. The per-prayer gap the
    /// user typed under Time Correction went away with its tab, because it could
    /// only ever be a guess — and a guess sitting next to a real clock reads as
    /// a fact.
    func publishedIqamaDelay(for prayer: String) -> Int? {
        guard isMosqueTimetableActive, let mosque = mawaqitMosque else { return nil }
        return MawaqitService.iqamaOffsets(for: Date(), in: mosque.iqamaCalendar)[prayer]
    }

    /// Iqama time for the next prayer, read from the mosque's published gap.
    /// `nil` under calculated times, since there is no iqama to know (see
    /// `displayedIqamaDelay(for:)`), and `nil` for Sunnah prayers, which have no
    /// congregation.
    ///
    /// Note: even when the per-prayer adhan above is muted, its time still reads
    /// here — the mute silences audio, it never moves a clock.
    var nextPrayerIqamaDate: Date? {
        guard isMosqueTimetableActive,
              let occ = nextPrayerOccurrenceDate,
              Self.congregationalPrayers.contains(nextPrayerName),
              let minutes = publishedIqamaDelay(for: nextPrayerName)
        else { return nil }
        return occ.addingTimeInterval(Double(minutes) * 60)
    }

    /// Sanitised Jumu'ah sessions (each a valid 0...1439 clock time, sorted,
    /// deduped, capped): the single source the Settings editor and the
    /// panel's Friday row both read and write through.
    var jumuahSessions: [Int] {
        get {
            let sorted = Self.sanitiseJumuahSessions(decodedJumuahSessions)
            if sorted != decodedJumuahSessions {
                // Fold stale extras away a tick later so reading the value in
                // a body never writes state mid-render.
                DispatchQueue.main.async { [weak self] in self?.jumuahSessions = sorted }
            }
            return sorted
        }
        set {
            if let data = try? JSONEncoder().encode(Self.sanitiseJumuahSessions(newValue)) {
                jumuahSessionsJSON = String(data: data, encoding: .utf8) ?? "[]"
            }
        }
    }

    /// Raw stored list (may hold junk from hand edits): validated on the way
    /// in and out by `jumuahSessions` above.
    private var decodedJumuahSessions: [Int] {
        guard let data = jumuahSessionsJSON.data(using: .utf8),
              let list = try? JSONDecoder().decode([Int].self, from: data) else { return [] }
        return list
    }

    private static func sanitiseJumuahSessions(_ values: [Int]) -> [Int] {
        Array(Set(values.filter { (0..<1440).contains($0) }).sorted().prefix(maxJumuahSessions))
    }

    /// The five congregational prayers — the only ones that get an iqama.
    private static let congregationalPrayers: Set<String> = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]

    /// True on Fridays by the clock the panel shows: that's when the Jumu'ah
    /// row joins the schedule (`weekday == 6` is Friday in the Gregorian
    /// calendar).
    var isFriday: Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = displayTimeZone
        return calendar.component(.weekday, from: Date()) == 6
    }

    /// True when a downloaded mosque timetable is the active source of the
    /// times. Settings that only feed the *calculated* path (method, madhhab,
    /// high-latitude rule, the hand-entered Jumu'ah list, the iqama gap) are
    /// inert while this is on — the mosque's own published values are used
    /// instead, and the user's stay stored for when the timetable is switched
    /// off. The UI greys those rows out through this one flag rather than each
    /// page re-deriving the condition (and disagreeing about what counts).
    var isMosqueTimetableActive: Bool {
        useMawaqitSchedule && mawaqitMosque != nil
    }

    /// The sessions the panel actually shows, in minutes past midnight.
    /// A downloaded mosque timetable wins over the hand-entered list: Mawaqit
    /// publishes every gathering the mosque runs (`jumua`, `jumua2`, `jumua3`),
    /// so a two- or three-khutbah mosque like Aubervilliers shows both or all
    /// three sessions instead of only the one a user bothered to type in. The
    /// stored list stays the fallback — it is all there is for calculated
    /// times, and it keeps showing if the mosque publishes none.
    var effectiveJumuahSessions: [Int] {
        if useMawaqitSchedule,
           let mosque = mawaqitMosque,
           let published = mosque.jumuaSessions?
                .compactMap({ MawaqitService.minutesFromHM($0) }),
           !published.isEmpty {
            return Self.sanitiseJumuahSessions(published)
        }
        return jumuahSessions
    }

    /// Today's Jumu'ah sessions as display-timezone Dates, sorted. Empty when
    /// none are configured — the panel row renders only off this.
    var jumuahSessionDates: [Date] {
        let sessions = effectiveJumuahSessions
        guard !sessions.isEmpty else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = displayTimeZone
        let day = calendar.dateComponents([.year, .month, .day], from: Date())
        return sessions.compactMap { minutes -> Date? in
            var components = day
            components.hour = minutes / 60
            components.minute = minutes % 60
            components.second = 0
            return calendar.date(from: components)
        }
    }

    /// Seed for a newly added Jumu'ah session: today's Dhuhr on the panel's
    /// clock rounded up to the next quarter hour — Jumu'ah follows Dhuhr, so a
    /// session added in Settings should start around there instead of at
    /// whatever o'clock the + happened to be tapped. Falls back to 12:30
    /// before any prayer time is known.
    var jumuahSeedMinutes: Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = displayTimeZone
        let dhuhr = todayTimes["Dhuhr"].map { calendar.dateComponents([.hour, .minute], from: $0) }
        return Self.jumuahSessionSeed(hour: dhuhr?.hour ?? 12, minute: dhuhr?.minute ?? 15)
    }

    /// Quarter-hour rounding behind `jumuahSeedMinutes`, kept pure so the
    /// midnight wrap is unit-testable without a live view model.
    static func jumuahSessionSeed(hour: Int, minute: Int) -> Int {
        let total = hour * 60 + ((minute / 15) + 1) * 15
        return ((total % 1440) + 1440) % 1440
    }

    /// Panel caption: the mosque's name while the mosque timetable is active.
    var panelLocationCaption: String {
        if useMawaqitSchedule, let mosque = mawaqitMosque { return mosque.name }
        return locationStatusText
    }

    // MARK: - High-Latitude Rule Info

    /// The rule actually applied for the current location: the user's override,
    /// or Adhan's recommendation when "Recommended" is selected. nil until a location is known.
    var effectiveHighLatitudeRule: HighLatitudeRuleSetting? {
        guard let coord = currentCoordinates else { return nil }
        let effective = highLatitudeRuleSetting.adhanRule
            ?? HighLatitudeRule.recommended(for: Coordinates(latitude: coord.latitude, longitude: coord.longitude))
        return HighLatitudeRuleSetting(adhanRule: effective)
    }

    /// Human-readable caption showing the active high-latitude rule. nil until a location is known.
    var highLatitudeRuleCaption: String? {
        guard let effective = effectiveHighLatitudeRule, let lat = currentCoordinates?.latitude else { return nil }
        if highLatitudeRuleSetting == .recommended {
            // "latText" arrives already formatted in the locale's own digits —
            // `String(format:)` without a locale always prints ASCII (`%.1f`
            // on the raw Double would read "30.5" inside an Arabic sentence).
            let latText = LocalizedNumber.fixedString(lat, locale: displayLocale, fractionDigits: 1)
            return String(format: NSLocalizedString("Recommended for your location (%@°): %@", comment: "High-latitude rule caption — recommended"), locale: displayLocale, latText, effective.displayName)
        } else {
            return String(format: NSLocalizedString("Override: %@. Recommended for your location is %@.", comment: "High-latitude rule caption — override"), highLatitudeRuleSetting.displayName, effective.displayName)
        }
    }

    /// Description of the effective high-latitude rule, for use as secondary caption text.
    var highLatitudeRuleDescription: String? {
        return effectiveHighLatitudeRule?.description
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

    /// Fajr time displayed by every surface (panel row, menu bar, correction
    /// preview): today's Fajr — except after Isha, when today's Fajr has
    /// already passed and Fajr is the next prayer. Then it is tomorrow's
    /// actual Fajr, because that is when the countdown ends and the next-day
    /// notifications fire. Today's and tomorrow's Fajr differ by a minute in
    /// some cities, which used to make the menu bar read one minute off from
    /// the panel.
    var displayedFajrTime: Date? {
        guard let todayFajr = todayTimes["Fajr"] else { return nil }
        if nextPrayerName == "Fajr", todayFajr < Date() {
            return tomorrowFajrTime
        }
        return todayFajr
    }

    /// Occurrence date of the next prayer — the single source shared by the
    /// countdown and the menu-bar time so they can never disagree.
    var nextPrayerOccurrenceDate: Date? {
        nextPrayerName == "Fajr" ? displayedFajrTime : todayTimes[nextPrayerName]
    }

    private func updateCountdown() {
        guard let nextDate = nextPrayerOccurrenceDate else {
            countdown = "--:--"; detailedCountdown = "--:--:--"; updateMenuTitle(); return
        }

        let diff = Int(nextDate.timeIntervalSince(Date()))
        // Red alert: the imminent styling starts `redAlertMinutes` minutes
        // before the prayer; 0 never triggers it. The UserDefaults mirror
        // lets the window-root Accent Panel tint follow the alert colour too
        // (it owns no view model, so it can't read the @Published flag).
        isPrayerImminent = (redAlertMinutes > 0 && diff <= redAlertMinutes * 60 && diff > 0)
        UserDefaults.standard.set(isPrayerImminent, forKey: "prayerImminentForTint")

        // hh:mm:ss for the panel's countdown header (same locale digits as
        // the menu-bar countdown).
        let digits = NumberFormatter()
        digits.locale = displayLocale
        digits.minimumIntegerDigits = 2
        digits.maximumIntegerDigits = 2
        let comp = { (v: Int) in digits.string(from: NSNumber(value: v)) ?? String(format: "%02d", v) }
        detailedCountdown = diff > 0
            ? "\(comp(diff / 3600)):\(comp((diff % 3600) / 60)):\(comp(diff % 60))"
            : "\(comp(0)):\(comp(0)):\(comp(0))"

        if diff > 0 {
            let h = diff / 3600
            let m = (diff % 3600) / 60
            let numberFormatter = NumberFormatter()
            numberFormatter.locale = displayLocale
            let formattedM = numberFormatter.string(from: NSNumber(value: m + 1)) ?? "\(m + 1)"
            if h > 0 {
                let formattedH = numberFormatter.string(from: NSNumber(value: h)) ?? "\(h)"
                countdown = String(format: NSLocalizedString("countdown_hm", comment: ""), formattedH, formattedM)
            } else {
                countdown = String(format: NSLocalizedString("countdown_m", comment: ""), formattedM)
            }
        } else {
            countdown = NSLocalizedString("Now", comment: "")
            if let sound = adhanSound(for: nextPrayerName) {
                AdhanAudioPlayer.shared.play(adhanType: sound.adhanType, customFilePath: sound.customFilePath, prayerName: nextPrayerName)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.updateNextPrayer() }
        }
        updateMenuTitle()
    }

    /// User-picked next-prayer highlight fill; nil while the accent default applies.
    var customHighlightColor: Color? {
        var hex = customHighlightColorHex
        guard !hex.isEmpty else { return nil }
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6 || hex.count == 8, UInt32(hex, radix: 16) != nil else { return nil }
        // RGB only: the row fill itself stays solid so the highlight text
        // keeps its contrast — the slider alpha drives the panel tint alone.
        return Self.color(fromHex: String(hex.prefix(6)))
    }

    /// Highlight palette offered instead of a system colour picker: the picker's
    /// `NSColorPanel` cannot be interacted with reliably from inside a
    /// non-activating menu bar panel, so the choice is a fixed set of presets.
    /// `key` is localized at the call site, `hex` is the persisted value.
    static let highlightColorPresets: [(key: String, hex: String)] = [
        ("color_blue", "#007AFF"),
        ("color_purple", "#AF52DE"),
        ("color_pink", "#FF2D55"),
        ("color_orange", "#FF9500"),
        ("color_green", "#34C759"),
    ]

    /// `Color` for a "#RRGGBB[AA]" (or "RRGGBB[AA]") string; malformed input
    /// falls back to the accent colour so a swatch is never invisible. The
    /// alpha byte keeps the slider value for controls that read the picked
    /// colour back (ColorSelector guestimates, popover re-opens).
    static func color(fromHex hex: String) -> Color {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("#") { clean.removeFirst() }
        let rgbHex: String
        var alpha = 1.0
        if clean.count == 8, let rgb = UInt32(String(clean.prefix(6)), radix: 16),
           let alphaByte = UInt32(String(clean.suffix(2)), radix: 16) {
            rgbHex = String(clean.prefix(6))
            alpha = Double(alphaByte) / 255.0
            return Color(red: Double((rgb >> 16) & 0xFF) / 255.0,
                         green: Double((rgb >> 8) & 0xFF) / 255.0,
                         blue: Double(rgb & 0xFF) / 255.0,
                         opacity: alpha)
        } else if clean.count == 6, UInt32(clean, radix: 16) != nil {
            rgbHex = clean
        } else {
            return .accentColor
        }
        guard let value = UInt32(rgbHex, radix: 16) else { return .accentColor }
        return Color(red: Double((value >> 16) & 0xFF) / 255.0,
                     green: Double((value >> 8) & 0xFF) / 255.0,
                     blue: Double(value & 0xFF) / 255.0)
    }

    /// "#RRGGBB[AA]" for a picked SwiftUI colour (sRGB) — the inverse of
    /// `color(fromHex:)`, used to store a ColorSelector choice. Fully opaque
    /// colours collapse to 6 digits (matching the palette format); anything
    /// else keeps the explicit alpha byte from the opacity slider.
    static func hexString(from color: Color) -> String {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return "" }
        func channel(_ component: CGFloat) -> Int { Int((component * 255).rounded()) }
        let r = channel(rgb.redComponent), g = channel(rgb.greenComponent)
        let b = channel(rgb.blueComponent), a = rgb.alphaComponent
        guard a < 0.999 else {
            return String(format: "#%02X%02X%02X", r, g, b)
        }
        let alpha = Int((min(max(a, 0), 1) * 255).rounded())
        return String(format: "#%02X%02X%02X%02X", r, g, b, alpha)
    }

    /// Hue / saturation / brightness / alpha of a picked colour, as the HSB
    /// state the colour surface works in. The ColorSelector package converts
    /// with these internally, but its `Color.hue/saturation/brightness/alpha`
    /// helpers are internal to it — so the inline (non-popover) surface seeds
    /// itself from here instead, through AppKit's sRGB components.
    static func hsbaComponents(from color: Color?) -> (hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) {
        guard let color, let srgb = NSColor(color).usingColorSpace(.sRGB) else {
            return (0, 1, 1, 1)
        }
        return (srgb.hueComponent, srgb.saturationComponent, srgb.brightnessComponent, srgb.alphaComponent)
    }

    /// On-state tint for native controls (switches, checkboxes): the selected
    /// highlight colour when one is picked — so every toggle matches the
    /// highlight row and the Accent Panel tint — or nil to keep the system
    /// accent when no colour is selected.
    static func controlTint(fromHighlightHex hex: String) -> Color? {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("#") { clean.removeFirst() }
        guard !clean.isEmpty, clean.count == 6 || clean.count == 8, UInt32(clean, radix: 16) != nil else { return nil }
        // RGB only: switches, checkboxes, and the About icon/Done fill stay
        // solid — alpha (slider) never reaches them.
        return color(fromHex: String(clean.prefix(6)))
    }

    /// Selected highlight colour used as the panel's interactive accent: the
    /// picked custom colour (RGB only, so the picker's alpha never washes
    /// text out), or the system accent when no colour is selected. Single
    /// source for the surfaces that colour text or icons with it — the
    /// correction preview, time popovers, About page.
    var selectedHighlightColor: Color {
        Self.controlTint(fromHighlightHex: customHighlightColorHex) ?? .accentColor
    }

    /// Contrast-safe variant of `selectedHighlightColor` for *small glyphs*
    /// (mute rings, pager chevrons, checkmarks) drawn on the panel surface.
    ///
    /// #24: a pale custom pick (pastel yellow, light mint, …) is a fine
    /// *fill* — the next-prayer row pairs it with
    /// `onFillColorForHighlight` text — but as a thin 12–13pt glyph on the
    /// plain (or Accent-tinted) panel it falls below readable contrast and
    /// the icon "disappears" while staying clickable. In that case this
    /// falls back to the system accent, which is always drawn to stay legible
    /// on both panel appearances. Saturated picks pass through untouched.
    var legibleInteractiveAccent: Color {
        guard Self.controlTint(fromHighlightHex: customHighlightColorHex) != nil else {
            return .accentColor
        }
        let c = Self.accentPanelBaseComponents(fromHighlightHex: customHighlightColorHex)
        // WCAG relative luminance of the pick; pale picks (> ~0.55) read as
        // "almost white" at glyph sizes and need the fallback.
        return Self.relativeLuminance(c.r, c.g, c.b) > 0.55 ? .accentColor : selectedHighlightColor
    }

    /// True while the picked highlight is one of the two red-ish presets
    /// (#FF3B30 red, #FF2D55 pink) — the only picks that would swallow the
    /// panel's red alert instead of standing apart from it.
    static func highlightCollidesWithRedAlert(fromHighlightHex hex: String) -> Bool {
        var clean = hex
        if clean.hasPrefix("#") { clean.removeFirst() }
        return ["FF3B30", "FF2D55"].contains(clean.uppercased())
    }

    /// Hex the Accent Panel theme derives its tint + colour scheme from.
    ///
    /// Normally the user's own pick — but while the red-alert (imminent)
    /// highlight is showing, the panel follows the *alert* colour instead, so
    /// the whole panel reads as one urgent surface rather than "red row on a
    /// blue/green panel". Mirrors `nextPrayerHighlight(imminent:)` exactly,
    /// including the amber fallback for the two red-ish picks that would
    /// otherwise swallow the alert. Returns nil when neither accent mode nor
    /// the Accent Panel theme paints a coloured surface (plain mode keeps the
    /// alert on the row alone).
    ///
    /// Static + hex-driven so `AccentPanelTintOverlay` shares the exact same
    /// math without needing a view model instance.
    static func effectiveAccentHex(
        highlightHex: String,
        imminent: Bool,
        useAccentColor: Bool,
        accentPanelTheme: Bool
    ) -> String? {
        guard useAccentColor || accentPanelTheme else { return nil }
        if imminent {
            if highlightCollidesWithRedAlert(fromHighlightHex: highlightHex) {
                return "FFCC00"   // amber alert fallback (see nextPrayerHighlight)
            }
            return "FF4246"       // imminent red alert fill
        }
        return highlightHex
    }

    /// Single source for the next-prayer highlight on the panel row and the
    /// countdown header, so the accent toggle, custom color, and imminent red
    /// can never disagree between the two surfaces.
    func nextPrayerHighlight(imminent override: Bool? = nil) -> (fill: Color, text: Color) {
        let imminent = override ?? isPrayerImminent
        if imminent {
            // The two red-ish picks would swallow the red alert (same hue as
            // the highlight fill and/or the Accent Panel), so for those — and
            // only while one of those red surfaces is actually showing — the
            // *alert* flips to amber with black text. Inside the panel only:
            // the picked colour itself stays untouched everywhere else.
            if useAccentColor || accentPanelTheme,
               Self.highlightCollidesWithRedAlert(fromHighlightHex: customHighlightColorHex) {
                return (Color(red: 1.0, green: 0xCC / 255.0, blue: 0.0), .black)
            }
            return useAccentColor
                ? (Color(red: 1.0, green: 0x42 / 255.0, blue: 0x46 / 255.0), .white)
                : (Color("HighlightColor"), .red)
        }
        if useAccentColor {
            return (customHighlightColor ?? Color.accentColor, .white)
        }
        return (Color("HoverColor"), .primary)
    }

    // MARK: - Accent Panel Theme

    /// System accent as sRGB components. The `AccentColor` asset ships the
    /// empty system-default template entry, so `NSColor.controlAccentColor` —
    /// the colour `Color.accentColor` resolves to — is read directly.
    private static var systemAccentComponents: (r: Double, g: Double, b: Double) {
        if let rgb = NSColor.controlAccentColor.usingColorSpace(.sRGB) {
            return (rgb.redComponent, rgb.greenComponent, rgb.blueComponent)
        }
        return (0.0, 0.478, 1.0)   // System blue fallback.
    }

    /// Colour the panel tint is derived from: the user's selected highlight
    /// colour when one is picked — so the tinted panel and the highlighted
    /// row share the same colour — otherwise the system accent. Static so
    /// `AccentPanelTintOverlay` (at the window root) shares the exact same
    /// math without needing a view model instance.
    static func accentPanelBaseComponents(fromHighlightHex hex: String) -> (r: Double, g: Double, b: Double) {
        var hex = hex
        if hex.hasPrefix("#") { hex.removeFirst() }
        let rgbHex = String(hex.prefix(6))
        if rgbHex.count == 6, let value = UInt32(rgbHex, radix: 16) {
            return (Double((value >> 16) & 0xFF) / 255.0,
                    Double((value >> 8) & 0xFF) / 255.0,
                    Double(value & 0xFF) / 255.0)
        }
        return Self.systemAccentComponents
    }

    /// Transparency the Accent Panel tint applies: the alpha byte of an
    /// 8-digit pick (the ColorSelector opacity slider), else the default
    /// translucency. Floor-minimum, so full-left is a glassy whisper and
    /// full-right is solid colour.
    static func accentPanelOpacity(fromHighlightHex hex: String) -> Double {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("#") { clean.removeFirst() }
        guard clean.count == 8, let alpha = UInt32(String(clean.suffix(2)), radix: 16) else { return 0.7 }
        return max(Double(alpha) / 255.0, 0.05)
    }

    /// WCAG relative luminance: 0 = black, 1 = white.
    static func relativeLuminance(_ r: Double, _ g: Double, _ b: Double) -> Double {
        func linearize(_ c: Double) -> Double {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b)
    }

    /// True when light text balances better on the accent-tinted panel. At or
    /// below the 0.45 luminance cutoff the tint is shaded toward black (see
    /// `accentPanelTint`); above it the tint is lightened toward white and
    /// dark text wins.
    static func accentPanelPrefersLightText(fromHighlightHex hex: String) -> Bool {
        let c = accentPanelBaseComponents(fromHighlightHex: hex)
        return relativeLuminance(c.r, c.g, c.b) <= 0.45
    }

    /// Legible text/icon tone for content sitting *on* the highlight fill.
    /// The pick is a saturated block, so white reads on it far more often than
    /// not — but a pale yellow or pastel pick would swallow white, so this
    /// reuses the Accent Panel's WCAG luminance test rather than hardcoding a
    /// tone per surface. Empty hex means the system accent is in use, which is
    /// dark enough in both appearances to keep white.
    static func onFillColorForHighlight(_ hex: String) -> Color {
        let clean = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return .white }
        return accentPanelPrefersLightText(fromHighlightHex: clean) ? .white : .black
    }

    /// Panel colour scheme while `accentPanelTheme` is on: drives the dark/
    /// light variants of every asset colour (secondary text, dividers, hover,
    /// border) and the native controls so the rest of the panel matches the
    /// tint instead of fighting it.
    static func accentPanelColorScheme(fromHighlightHex hex: String) -> ColorScheme {
        accentPanelPrefersLightText(fromHighlightHex: hex) ? .dark : .light
    }

    /// Accent panel tint, applied *translucently* at the window root (see
    /// `AccentPanelTintOverlay`) so the Liquid Glass blur keeps showing
    /// through: the base colour shaded toward black (light text) or toward
    /// white (dark text). The heavy shading on the light-text side pays for
    /// the bright backdrop that shows through the translucent tint, keeping
    /// white text above ~4.5:1 even over a white desktop.
    static func accentPanelTint(fromHighlightHex hex: String) -> Color {
        let c = accentPanelBaseComponents(fromHighlightHex: hex)
        if accentPanelPrefersLightText(fromHighlightHex: hex) {
            return Color(red: c.r * 0.5, green: c.g * 0.5, blue: c.b * 0.5)
        }
        return Color(red: c.r + (1 - c.r) * 0.4,
                     green: c.g + (1 - c.g) * 0.4,
                     blue: c.b + (1 - c.b) * 0.4)
    }

    // Instance mirrors for views that already hold the view model, so both
    // call styles stay in lockstep with the window-root tint overlay.

    /// The pick the Accent Panel derivations (tint, scheme, text tone) use
    /// right now: the alert colour while imminent, the user's pick otherwise.
    var effectiveAccentPanelHex: String {
        Self.effectiveAccentHex(
            highlightHex: customHighlightColorHex,
            imminent: isPrayerImminent,
            useAccentColor: useAccentColor,
            accentPanelTheme: accentPanelTheme
        ) ?? customHighlightColorHex
    }

    var accentPanelPrefersLightText: Bool {
        Self.accentPanelPrefersLightText(fromHighlightHex: effectiveAccentPanelHex)
    }

    var accentPanelColorScheme: ColorScheme {
        Self.accentPanelColorScheme(fromHighlightHex: effectiveAccentPanelHex)
    }

    var accentPanelTint: Color {
        Self.accentPanelTint(fromHighlightHex: effectiveAccentPanelHex)
    }

    /// Today's Hijri date for the panel header — Umm al-Qura reckoning with
    /// localized month names and era, e.g. "15 Rabiʻ II 1448 AH" (matches the
    /// system Calendar/iPhone reading). `hijriDateAdjustment` still lets the
    /// user nudge it ± days where the local announcement differs. Arabic
    /// renders its own numerals and era symbol (هـ), matching every other
    /// time in the app.
    var hijriDateText: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .islamicUmmAlQura)
        formatter.locale = displayLocale
        // Same zone as the prayer times: in mosque mode the day being shown
        // is the one `MawaqitService.times` looked up (Mac day), not the
        // stale manual-location day.
        formatter.timeZone = displayTimeZone
        formatter.dateFormat = "d MMMM yyyy G"
        let base = Date()
        guard hijriDateAdjustment != 0,
              let shifted = Calendar(identifier: .gregorian).date(byAdding: .day, value: hijriDateAdjustment, to: base)
        else { return formatter.string(from: base) }
        return formatter.string(from: shifted)
    }

    /// Nama shalat yang sudah dilokalkan, di-uppercase bila opsi aksesibilitas
    /// "Uppercase Text" aktif. Untuk bahasa Arab (tanpa kapitalisasi) hasilnya
    /// otomatis tetap sama.
    func prayerDisplayName(_ prayerName: String) -> String {
        let localized = NSLocalizedString(prayerName, comment: "")
        return accessibilityUppercaseText ? localized.uppercased() : localized
    }

    /// Teks countdown pada header panel ("Fajr in 25m") dengan penyesuaian
    /// aksesibilitas uppercase yang sama seperti menu bar.
    var headerCountdownText: String {
        let format = NSLocalizedString("prayer_in_countdown", comment: "")
        var text = String(format: format, prayerDisplayName(nextPrayerName), countdown)
        if accessibilityUppercaseText { text = text.uppercased() }
        return text
    }

    /// Countdown string for the status item. Minute-granular by default
    /// (`countdown`); with "Show Seconds" on it ticks as `mm:ss` — `h:mm:ss`
    /// once there is an hour to show — using the same locale digits as the
    /// panel's countdown header, so the two can never disagree.
    private var menuBarCountdown: String {
        guard menuBarShowSeconds, menuBarTextMode.isCountdown else { return countdown }
        guard let nextDate = nextPrayerOccurrenceDate else { return countdown }
        let diff = Int(nextDate.timeIntervalSince(Date()))
        guard diff > 0 else { return NSLocalizedString("Now", comment: "") }

        let digits = NumberFormatter()
        digits.locale = displayLocale
        digits.minimumIntegerDigits = 2
        digits.maximumIntegerDigits = 2
        let comp = { (value: Int) in digits.string(from: NSNumber(value: value)) ?? String(format: "%02d", value) }

        let hours = diff / 3600
        let minutes = (diff % 3600) / 60
        let seconds = diff % 60
        return hours > 0
            // Hours need the same locale digits as the padded components —
            // a raw interpolation would leave ASCII hours beside localized
            // minutes ("2:٣٠:٤٥").
            ? "\(LocalizedNumber.string(hours, locale: displayLocale)):\(comp(minutes)):\(comp(seconds))"
            : "\(comp(minutes)):\(comp(seconds))"
    }

    func updateMenuTitle() {
        guard isPrayerDataAvailable else { self.menuTitle = NSAttributedString(string: "Sajda Pro"); return }
        var textToShow = ""
        let localizedPrayerName = NSLocalizedString(nextPrayerName, comment: "")
        switch menuBarTextMode {
        case .hidden:
            textToShow = ""
        case .countdown, .iconCountdown:
            let countdownText = menuBarCountdown
            if useMinimalMenuBarText {
                textToShow = String(format: NSLocalizedString("prayer_minimal_countdown", comment: ""), localizedPrayerName, countdownText)
            } else {
                textToShow = String(format: NSLocalizedString("prayer_in_countdown", comment: ""), localizedPrayerName, countdownText)
            }
        case .exactTime, .iconExactTime:
            guard let nextDate = nextPrayerOccurrenceDate else { textToShow = "Sajda Pro"; break }
            if useMinimalMenuBarText {
                textToShow = String(format: NSLocalizedString("prayer_minimal_exact", comment: ""), localizedPrayerName, dateFormatter.string(from: nextDate))
            } else {
                textToShow = String(format: NSLocalizedString("prayer_at_time", comment: ""), localizedPrayerName, dateFormatter.string(from: nextDate))
            }
        }
        // Aksesibilitas: seluruh teks menu bar di-uppercase bila diminta.
        if accessibilityUppercaseText {
            textToShow = textToShow.uppercased()
        }
        var attributes: [NSAttributedString.Key: Any] = [:]
        if isPrayerImminent {
            attributes[.foregroundColor] = NSColor.systemRed
        }
        // Aksesibilitas: judul menu bar bisa diperbesar dan/atau ditebalkan
        // agar tetap terbaca tanpa zoom sistem. Dengan "Show Seconds" aktif
        // fontnya memakai digit monospaced supaya lebar status item tidak
        // bergoyang setiap detik.
        if menuBarLargerText || accessibilityBoldText || menuBarShowSeconds {
            let size = menuBarLargerText ? NSFont.systemFontSize + 3 : NSFont.systemFontSize
            let weight: NSFont.Weight = accessibilityBoldText ? .bold : .regular
            attributes[.font] = menuBarShowSeconds
                ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
                : NSFont.systemFont(ofSize: size, weight: weight)
        }
        self.menuTitle = NSAttributedString(string: textToShow, attributes: attributes)
    }

    /// Timezone every surface renders prayer times and the Hijri header in.
    ///
    /// Calculated times are true instants for the chosen location, so they
    /// render in `locationTimeZone`. Mosque-timetable times are the raw
    /// "HH:MM" wall-clock strings the mosque publishes, parsed in
    /// `TimeZone.current` by `dateFromHM`/`MawaqitService.times` — they must
    /// render in that same zone. Otherwise a leftover manual-location zone
    /// leaks into mosque mode: switching manual location → Tokyo (UTC+9) and
    /// then activating a mosque shifted every row by the zone difference
    /// (Grande Mosquée de Paris Fajr showed 08:11 instead of 06:11 from a
    /// UTC+7 Mac). Switching back to automatic "fixed" it only because that
    /// path resets `locationTimeZone` to `.current`.
    var displayTimeZone: TimeZone {
        useMawaqitSchedule ? .current : locationTimeZone
    }

    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeZone = self.displayTimeZone
        formatter.locale = displayLocale
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

    /// Sound to play for a prayer's adhan, or nil when it should stay silent:
    /// the prayer is muted from the home panel, or "None" is chosen in
    /// Settings. The notification banner still shows either way.
    func adhanSound(for prayerName: String) -> (adhanType: AdhanType, customFilePath: String)? {
        let config = soundConfig(for: prayerName)
        guard !config.muted, config.adhanType != .none else { return nil }
        return (config.adhanType, config.customFilePath)
    }

    /// Whether a prayer currently makes no sound — muted from the home panel
    /// or "None" in Settings. Drives that row's speaker icon on the panel.
    func isAdhanMuted(_ prayerName: String) -> Bool {
        adhanSound(for: prayerName) == nil
    }

    /// Per-prayer adhan mute from the home panel. Muting only flips `muted`,
    /// never the sound picked in Settings; enabling a prayer whose type is
    /// "None" falls back to the default beep so the toggle actually turns
    /// sound back on.
    func setAdhanMuted(_ muted: Bool, for prayerName: String) {
        var config = soundConfig(for: prayerName)
        config.muted = muted
        if !muted, config.adhanType == .none { config.adhanType = .defaultBeep }
        setSoundConfig(config, for: prayerName)
    }

    func stopAdhan() {
        AdhanAudioPlayer.shared.stop()
    }

    private func setupAdhanObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleAdhanDidStart(_:)), name: .adhanDidStart, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAdhanDidStop(_:)), name: .adhanDidStop, object: nil)
    }

    /// Rebuilds the menu bar title the moment the app language is switched —
    /// the menu bar label lives outside `LanguageManagerView`'s
    /// `.id(language)` re-render, so without this the old-language title
    /// would linger until the countdown tick rebuilt it a second later.
    private func setupLanguageRefresh() {
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .compactMap { _ in UserDefaults.standard.string(forKey: "selectedLanguage") }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateMenuTitle() }
            .store(in: &cancellables)
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
        // Republish immediately so the sound rows (menu selection, Browse
        // link, file name) update on the spot instead of waiting for the
        // next unrelated view-model change.
        objectWillChange.send()
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
        // Ensure the countdown timer fires during menu tracking and other
        // common-mode run-loop activities so the adhan is not delayed.
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
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
        // Leaving mosque-timetable mode: a refresh means live location again.
        useMawaqitSchedule = false
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
        // Branch on the *live* status, not the cached `authorizationStatus`
        // property. The panel can be showing a stale `.notDetermined` from
        // before a location switch, and taking the `else` branch on that stale
        // value only re-ran the status handler — which for `.notDetermined`
        // does nothing but park the UI on "Location access needed" — so the
        // tap silently did nothing and the user had to press the button a
        // second time to actually get the system prompt.
        let status = locMgr.authorizationStatus
        authorizationStatus = status
        if status == .notDetermined {
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
