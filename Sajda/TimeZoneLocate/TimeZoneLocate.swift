// Salin dan tempel SELURUH kode ini ke dalam TimeZoneLocate.swift

import Foundation
import CoreLocation

public typealias TimeZoneLocateResult = (_ timeZone:TimeZone?) -> (Void)

extension CLLocation {
    public var timeZone: TimeZone {
        return TimeZoneLocate.timeZoneWithLocation(self)
    }
    
    @available(iOS 9.0, *)
    public func timeZone(completion:@escaping TimeZoneLocateResult) {
        TimeZoneLocate.geocodeTimeZone(location: self, completion: completion)
    }
}

open class TimeZoneLocate : NSObject {
    
    public static let sharedInstance = TimeZoneLocate()
    
    // Perbaikan: Mengubah cara pemanggilan bundle agar lebih andal di macOS
    private static func getBundle() -> Bundle {
        // Untuk aplikasi macOS, bundle utama adalah tempat aset berada.
        return Bundle.main
    }

    public static let timeZonesDB = TimeZoneLocate.importDataBaseFromFile("timezones.json")
    
    @available(iOS 9.0, *)
    open class func geocodeTimeZone(location:CLLocation, completion:@escaping TimeZoneLocateResult) {
        CLGeocoder().reverseGeocodeLocation(location) { (placemarks, error) in
            guard error == nil, let tz = placemarks?.last?.timeZone else {
                return completion(nil)
            }
            completion(tz)
        }
    }
    
    open class func timeZoneWithLocation(_ location:CLLocation) -> TimeZone {
        guard let closestZoneInfo = closestZoneInfo(location:location, source: TimeZoneLocate.timeZonesDB),
              let timeZone = timeZoneWithDictionary(closestZoneInfo)
            else { return TimeZone.current }
        return timeZone
    }
    
    open class func timeZone(location:CLLocation, countryCode:String? = nil) -> TimeZone? {
        guard let countryCode = countryCode,
            let filteredZones = filteredTimeZones(countryCode:countryCode),
            let closestZoneInfo = closestZoneInfo(location:location, source:filteredZones),
            let timeZone = timeZoneWithDictionary(closestZoneInfo)
        else { return TimeZoneLocate.timeZoneWithLocation(location)}
        
        return timeZone
    }
    
    open class func importDataBaseFromFile(_ fileName:String) -> [[AnyHashable: Any]] {
        let currentBundle = getBundle()
        
        guard let filePath = currentBundle.path(forResource: "timezones", ofType: "json") else {
            assertionFailure("Error: timezones.json tidak ditemukan di dalam bundle aplikasi.")
            return []
        }
        
        do {
            let jsonData = try Data(contentsOf: URL(fileURLWithPath: filePath))
            if let timeZones = try JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) as? [[AnyHashable: Any]] {
                return timeZones
            }
        } catch let error as NSError {
            NSLog("Error parsing timezones.json: %@", error.localizedDescription)
        }
        
        assertionFailure("Gagal memuat atau mem-parsing timezones.json")
        return []
    }
    
    open class func closestZoneInfo(location: CLLocation, source:[[AnyHashable: Any]]?) -> [AnyHashable: Any]? {
        var closestDistance: CLLocationDistance = Double.infinity
        var closestZoneInfo: [AnyHashable: Any]?
        
        guard let source = source else { return nil }
            
        for locationInfo in source {
            guard let latitude = locationInfo["latitude"] as? Double,
                  let longitude = locationInfo["longitude"] as? Double else { continue }
            
            let distance = location.distance( from: CLLocation(latitude: latitude, longitude: longitude) )
            if  distance < closestDistance {
                closestDistance = distance
                closestZoneInfo = locationInfo
            }
        }
        return closestZoneInfo
    }
    
    open class func filteredTimeZones(countryCode: String) -> [[AnyHashable: Any]]? {
        let predicate = NSPredicate(format: "country_code LIKE %@", countryCode)
        return (TimeZoneLocate.timeZonesDB as NSArray).filtered(using: predicate) as? [[AnyHashable: Any]]
    }
    
    open class func timeZoneWithDictionary(_ zoneInfo: [AnyHashable: Any]?) -> TimeZone? {
        guard let zoneName = zoneInfo?["zone"] as? String else { return nil }
        return TimeZone(identifier: zoneName)
    }
}
