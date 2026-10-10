// MARK: - Sajda/CustomTimetableStore.swift
//
// Local custom timetables imported from user-supplied PDFs, ZIPs, or CSV
// files. Fully offline: the app never contacts any timetable server.
//
// The library holds any number of named timetables, one of which is active.
// Only the active one feeds the panel. Timetables double as favorites: the
// main panel's favorites list shows active + saved timetables next to cities,
// so switching mosques is one tap. Use `useCustomTimetable` (+
/// `activeTimetableId`) for the source — `customTimetable` is just the cached
// active copy, refreshed lazily by `resolvedTimetable()`.

import Foundation

/// One imported timetable: 12 months of day rows plus optional iqama and
/// Friday sessions.
struct CustomTimetable: Codable, Identifiable, Hashable {
    /// Stable id, assigned on import (`timetable_<uuid>`). Favorites point at
    /// it; deleting the timetable retires its favorites.
    var id: String
    var name: String
    var importedAt: Date
    /// 12 months of day-of-month -> [fajr, sunrise, dhuhr, asr, maghrib, isha].
    var calendar: [[String: [String]]]
    /// Same shape, day -> [fajr, dhuhr, asr, maghrib, isha] absolute "HH:MM".
    var iqamaCalendar: [[String: [String]]]?
    /// Friday sessions as "HH:MM", global for the timetable.
    var jumuahSessions: [String]?

    init(id: String = "timetable_" + UUID().uuidString,
         name: String, importedAt: Date = Date(),
         calendar: [[String: [String]]],
         iqamaCalendar: [[String: [String]]]? = nil,
         jumuahSessions: [String]? = nil) {
        self.id = id
        self.name = name
        self.importedAt = importedAt
        self.calendar = calendar
        self.jumuahSessions = (jumuahSessions?.isEmpty ?? true) ? nil : jumuahSessions
        self.iqamaCalendar = (iqamaCalendar?.isEmpty ?? true) ? nil : iqamaCalendar
    }

    /// Decodes timetables written before stable ids existed (a single object
    /// with no `id` key): gives the copy its id from the legacy active file,
    /// or a fresh one when imported that way.
    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try box.decode(String.self, forKey: .name)
        self.importedAt = (try? box.decode(Date.self, forKey: .importedAt)) ?? Date()
        self.calendar = try box.decode([[String: [String]]].self, forKey: .calendar)
        self.iqamaCalendar = try? box.decodeIfPresent([[String: [String]]].self, forKey: .iqamaCalendar)
        self.jumuahSessions = try? box.decodeIfPresent([String].self, forKey: .jumuahSessions)
        self.id = (try? box.decode(String.self, forKey: .id)) ?? ("timetable_" + UUID().uuidString)
    }
}

enum CustomTimetableStore {
    /// How many timetables the library keeps (same cap as city favorites).
    static let maxCount = 5
    enum ImportError: LocalizedError {
        case emptyFile
        case missingHeader(String)
        case noUsableRows
        case pdfUnreadable

        var errorDescription: String? {
            switch self {
            case .emptyFile: return "The file is empty."
            case .missingHeader(let s): return "Missing column: \(s)."
            case .noUsableRows: return "No usable day rows found."
            case .pdfUnreadable: return "Couldn't read the PDF."
            }
        }
    }

    private static var storeURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Sajda", isDirectory: true)
            .appendingPathComponent("custom_timetable.json")
    }

    private static var libraryURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Sajda", isDirectory: true)
            .appendingPathComponent("custom_timetables.json")
    }

    static func load() -> CustomTimetable? {
        // Legacy single-timetable file, kept as a migration source.
        guard let data = try? Data(contentsOf: storeURL) else { return nil }
        return try? JSONDecoder().decode(CustomTimetable.self, from: data)
    }

    static func save(_ timetable: CustomTimetable) throws {
        try FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(timetable).write(to: storeURL, options: .atomic)
    }

    static func deleteStored() {
        try? FileManager.default.removeItem(at: storeURL)
    }

    // MARK: - Library

    /// All saved timetables, newest import last.
    static func loadAll() -> [CustomTimetable] {
        // Migrate the legacy single file once: it becomes the library's first
        // entry under a stable id so references to it keep working.
        if let data = try? Data(contentsOf: storeURL),
           let legacy = try? JSONDecoder().decode(CustomTimetable.self, from: data),
           (try? Data(contentsOf: libraryURL)) == nil {
            var migrated = legacy
            migrated.id = "timetable_legacy"
            try? saveAll([migrated])
            try? FileManager.default.removeItem(at: storeURL)
            return [migrated]
        }
        guard let data = try? Data(contentsOf: libraryURL),
              let list = try? JSONDecoder().decode([CustomTimetable].self, from: data) else { return [] }
        return list
    }

    static func saveAll(_ timetables: [CustomTimetable]) throws {
        try FileManager.default.createDirectory(
            at: libraryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(timetables).write(to: libraryURL, options: .atomic)
    }

    /// Adds an import, replacing any same-named timetable and dropping the
    /// oldest past the cap. Returns the stored copy.
    static func add(_ timetable: CustomTimetable) throws -> CustomTimetable {
        var list = loadAll()
        var stored = timetable
        if stored.id.isEmpty { stored.id = "timetable_" + UUID().uuidString }
        list.removeAll { $0.id == stored.id || $0.name == stored.name }
        list.append(stored)
        while list.count > maxCount { list.removeFirst() }
        try saveAll(list)
        try? FileManager.default.removeItem(at: storeURL)
        return stored
    }

    static func remove(id: String) {
        var list = loadAll()
        list.removeAll { $0.id == id }
        try? saveAll(list)
    }

    /// Renames a saved timetable. Returns the updated copy, or nil when the
    /// id is unknown or the name is blank / unchanged.
    @discardableResult
    static func rename(id: String, to newName: String) -> CustomTimetable? {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var list = loadAll()
        guard let index = list.firstIndex(where: { $0.id == id }),
              list[index].name != trimmed else { return nil }
        list[index].name = trimmed
        do {
            try saveAll(list)
        } catch {
            return nil
        }
        return list[index]
    }

    static func timetable(id: String?) -> CustomTimetable? {
        guard let id else { return nil }
        return loadAll().first { $0.id == id }
    }

    /// Removes legacy mosque caches so no scraped data survives migration.
    /// Keeps matching the old on-disk filename prefix so files written by
    /// earlier builds are still cleaned up.
    static func deleteLegacyMosqueCaches() {
        let dir = storeURL.deletingLastPathComponent()
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil) else { return }
        // Matches the old on-disk cache names by shape ("…_mosque.json",
        // "…_mosque_<slug>.json") without naming the retired vendor, so files
        // written by earlier builds are still cleaned up.
        for url in items where url.lastPathComponent.hasSuffix("_mosque.json")
            || url.lastPathComponent.contains("_mosque_") {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Six adhan times for a date, or nil when not covered.
    static func times(for date: Date, in calendar: [[String: [String]]]) -> [String]? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let month = cal.component(.month, from: date) - 1
        let day = cal.component(.day, from: date)
        guard month >= 0, month < calendar.count else { return nil }
        guard let times = calendar[month]["\(day)"], times.count >= 6 else { return nil }
        return times
    }

    static let iqamaOrder = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]

    /// Iqama gaps in minutes after adhan, derived per day as
    /// iqama clock minus adhan clock. Bad entries are dropped.
    static func iqamaOffsets(for date: Date, adhan: [[String: [String]]],
                             iqama: [[String: [String]]]?) -> [String: Int] {
        guard let iqama, iqama.count == 12 else { return [:] }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let month = cal.component(.month, from: date) - 1
        let day = cal.component(.day, from: date)
        guard month >= 0, month < adhan.count, month < iqama.count,
              let a = adhan[month]["\(day)"], a.count >= 6,
              let q = iqama[month]["\(day)"] else { return [:] }
        let adhanIdx = [0, 2, 3, 4, 5]
        var result: [String: Int] = [:]
        for (i, prayer) in iqamaOrder.enumerated() {
            guard i < q.count, adhanIdx[i] < a.count,
                  let tA = minutesFromHM(a[adhanIdx[i]]),
                  let tQ = minutesFromHM(q[i]) else { continue }
            let diff = tQ - tA
            let gap = diff < 0 ? diff + 1440 : diff
            if gap > 0, gap <= 180 { result[prayer] = gap }
        }
        return result
    }

    /// "HH:MM" (or "HH:MM:SS") -> minutes past midnight.
    static func minutesFromHM(_ value: String) -> Int? {
        let parts = value.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":")
        guard parts.count >= 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return hour * 60 + minute
    }

    /// Normalizes a time cell to "HH:MM".
    static func cleanHM(_ value: String) -> String? {
        let parts = value.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":")
        guard parts.count >= 2, let h = Int(parts[0]), let m = Int(parts[1]),
              (0...23).contains(h), (0...59).contains(m) else { return nil }
        return String(format: "%02d:%02d", h, m)
    }
}
