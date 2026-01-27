// MARK: - DiyanetLookup.swift
// Loads official Diyanet prayer times from bundled JSON for all Turkish provinces

import Foundation

struct DiyanetPrayerTimes: Codable {
    let fajr: String
    let sunrise: String
    let dhuhr: String
    let asr: String
    let maghrib: String
    let isha: String
}

class DiyanetLookup {
    static let shared = DiyanetLookup()
    
    // Dictionary of province name -> (date -> prayer times)
    private var provinceTimes: [String: [String: DiyanetPrayerTimes]] = [:]
    
    // All 81 Turkish provinces (uppercase, Turkish characters)
    private let turkishProvinces: Set<String> = [
        "ADANA", "ADIYAMAN", "AFYONKARAHISAR", "AKSARAY", "AMASYA", "ANKARA", "ANTALYA",
        "ARDAHAN", "ARTVIN", "AYDIN", "AGRI", "BALIKESIR", "BARTIN", "BATMAN", "BAYBURT",
        "BILECIK", "BINGOL", "BITLIS", "BOLU", "BURDUR", "BURSA", "CANAKKALE", "CANKIRI",
        "CORUM", "DENIZLI", "DIYARBAKIR", "DUZCE", "EDIRNE", "ELAZIG", "ERZINCAN", "ERZURUM",
        "ESKISEHIR", "GAZIANTEP", "GIRESUN", "GUMUSHANE", "HAKKARI", "HATAY", "IGDIR",
        "ISPARTA", "ISTANBUL", "IZMIR", "KAHRAMANMARAS", "KARABUK", "KARAMAN", "KARS",
        "KASTAMONU", "KAYSERI", "KIRIKKALE", "KIRKLARELI", "KIRSEHIR", "KILIS", "KOCAELI",
        "KONYA", "KUTAHYA", "MALATYA", "MANISA", "MARDIN", "MERSIN", "MUGLA", "MUS",
        "NEVSEHIR", "NIGDE", "ORDU", "OSMANIYE", "RIZE", "SAKARYA", "SAMSUN", "SIIRT",
        "SINOP", "SIVAS", "SANLIURFA", "SIRNAK", "TEKIRDAG", "TOKAT", "TRABZON", "TUNCELI",
        "USAK", "VAN", "YALOVA", "YOZGAT", "ZONGULDAK"
    ]
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"  // Ignore year - prayer times are same for any year
        formatter.timeZone = TimeZone(identifier: "Europe/Istanbul")
        return formatter
    }()
    
    private init() {
        loadTurkeyData()
    }
    
    private func loadTurkeyData() {
        guard let url = Bundle.main.url(forResource: "TurkeyPrayerTimes", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("⚠️ DiyanetLookup: Could not load TurkeyPrayerTimes.json")
            return
        }
        
        do {
            provinceTimes = try JSONDecoder().decode([String: [String: DiyanetPrayerTimes]].self, from: data)
        } catch {
            print("⚠️ DiyanetLookup: Failed to decode JSON - \(error)")
        }
    }
    
    /// Find matching province for a location name
    private func findProvince(for locationName: String) -> String? {
        let upperLocation = locationName.uppercased(with: Locale(identifier: "en_US"))
        
        // Direct match
        if turkishProvinces.contains(upperLocation) {
            return upperLocation
        }
        
        // Check if location contains a province name
        for province in turkishProvinces {
            if upperLocation.contains(province) || province.contains(upperLocation) {
                return province
            }
        }
        
        return nil
    }
    
    /// Returns prayer times for a Turkish province on the given date
    func getPrayerTimes(for date: Date, locationName: String, timezone: TimeZone) -> [String: Date]? {
        guard let province = findProvince(for: locationName),
              let times = provinceTimes[province],
              let dayTimes = times[dateFormatter.string(from: date)] else {
            return nil
        }
        
        // Parse time strings into Date objects
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        
        func parseTime(_ timeString: String) -> Date? {
            let parts = timeString.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2 else { return nil }
            var components = dateComponents
            components.hour = parts[0]
            components.minute = parts[1]
            components.second = 0
            return calendar.date(from: components)
        }
        
        guard let fajr = parseTime(dayTimes.fajr),
              let sunrise = parseTime(dayTimes.sunrise),
              let dhuhr = parseTime(dayTimes.dhuhr),
              let asr = parseTime(dayTimes.asr),
              let maghrib = parseTime(dayTimes.maghrib),
              let isha = parseTime(dayTimes.isha) else {
            print("⚠️ DiyanetLookup: Failed to parse times")
            return nil
        }
        
        return [
            "Fajr": fajr,
            "Sunrise": sunrise,
            "Dhuhr": dhuhr,
            "Asr": asr,
            "Maghrib": maghrib,
            "Isha": isha
        ]
    }
    
    /// Check if a location has Diyanet data available
    func hasData(for locationName: String) -> Bool {
        guard let province = findProvince(for: locationName) else { return false }
        return provinceTimes[province] != nil && !provinceTimes[province]!.isEmpty
    }
    
    /// List of all supported provinces
    var supportedProvinces: [String] {
        Array(turkishProvinces).sorted()
    }
}
