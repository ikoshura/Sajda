import Foundation

/// A mosque search hit from mawaqit.net's public JSON endpoint.
struct MosqueSearchResult: Identifiable, Hashable {
    let slug: String
    /// Display name plus locality when the API didn't fold it into the name.
    let label: String
    var id: String { slug }
}

/// One downloaded mosque schedule — everything the app needs while offline.
/// `calendar` mirrors Mawaqit's confData: 12 month dictionaries of
/// day-of-month → `[fajr, sunrise, dhuhr, asr, maghrib, isha]` as "HH:MM".
struct MawaqitMosque: Codable {
    let slug: String
    let name: String
    let fetchedAt: Date
    let calendar: [[String: [String]]]
}

/// Networking, parsing, and storage for the optional Mawaqit mosque timetable.
///
/// Search hits `api/2.0/mosque/search` (public JSON, 10 per page). The yearly
/// calendar comes from the mosque page's embedded `var confData = {...}` JSON,
/// extracted with a brace-balanced scan — a Swift port of the parser the KDE
/// Mawaqit applet uses in production. Everything is saved to Application
/// Support so the app runs fully offline afterwards.
enum MawaqitService {
    static let base = "https://mawaqit.net"

    enum FetchError: Error {
        case notReachable, notFound, formatChanged, badData
    }

    // MARK: - Search

    /// Keyword search against Mawaqit's public endpoint (page 1, 10 hits).
    static func searchMosques(matching word: String) async throws -> [MosqueSearchResult] {
        var comps = URLComponents(string: base + "/api/2.0/mosque/search")!
        comps.queryItems = [
            URLQueryItem(name: "word", value: word),
            URLQueryItem(name: "page", value: "1"),
        ]
        guard let url = comps.url else { throw FetchError.badData }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FetchError.notReachable }
        switch http.statusCode {
        case 200: break
        case 404: throw FetchError.notFound
        default: throw FetchError.notReachable
        }

        let items = try JSONDecoder().decode([SearchItem].self, from: data)
        return items.compactMap { item in
            guard !item.slug.isEmpty else { return nil }
            var label = item.label ?? item.name ?? item.slug
            if let locality = item.localisation, !label.contains(locality) {
                label += " — \(locality)"
            }
            return MosqueSearchResult(slug: item.slug, label: label)
        }
    }

    private struct SearchItem: Decodable {
        let slug: String
        let label: String?
        let name: String?
        let localisation: String?
    }

    // MARK: - Calendar download

    /// Downloads the mosque page and extracts the embedded yearly calendar.
    static func fetchCalendar(slug: String) async throws -> MawaqitMosque {
        guard let url = URL(string: base + "/en/" + slug) else { throw FetchError.badData }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FetchError.notReachable }
        switch http.statusCode {
        case 200: break
        case 404: throw FetchError.notFound
        default: throw FetchError.notReachable
        }

        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1),
              let raw = extractConfData(from: html) else {
            throw FetchError.formatChanged
        }
        let conf = try JSONDecoder().decode(ConfData.self, from: Data(raw.utf8))
        guard let calendar = conf.calendar, calendar.count == 12 else { throw FetchError.badData }
        let name = cleanMosqueName(conf.name ?? conf.label ?? extractTitle(from: html) ?? slug)
        return MawaqitMosque(slug: slug, name: name, fetchedAt: Date(), calendar: calendar)
    }

    private struct ConfData: Decodable {
        let name: String?
        let label: String?
        let calendar: [[String: [String]]]?
    }

    /// Returns the JSON object of `var|let|const confData = {...}` using a
    /// brace-balanced scan that respects strings and escapes, so a `}` inside
    /// a prayer name or announcement cannot cut the JSON short.
    static func extractConfData(from html: String) -> String? {
        guard let decl = html.range(of: #"(?:var|let|const)\s+confData\s*="#, options: .regularExpression),
              let open = html[decl.upperBound...].firstIndex(of: "{") else {
            return nil
        }

        var depth = 0
        var inString = false
        var quote: Character = "\""
        var escaped = false

        for index in html[open...].indices {
            let char = html[index]
            if inString {
                if escaped {
                    escaped = false
                } else if char == "\\" {
                    escaped = true
                } else if char == quote {
                    inString = false
                }
            } else if char == "\"" || char == "'" {
                inString = true
                quote = char
            } else if char == "{" {
                depth += 1
            } else if char == "}" {
                depth -= 1
                if depth == 0 {
                    return String(html[open...index])
                }
            }
        }
        return nil
    }

    // MARK: - Lookup

    /// Mosque display name from the page `<title>`: "Name | Mawaqit - ...".
    private static func extractTitle(from html: String) -> String? {
        guard let start = html.range(of: "<title>"),
              let end = html.range(of: "</title>", range: start.upperBound..<html.endIndex) else {
            return nil
        }
        let inside = html[start.upperBound..<end.lowerBound]
        let beforePipe = inside.split(separator: "|", maxSplits: 1).first.map(String.init) ?? String(inside)
        let trimmed = beforePipe.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Admins often pack the address into the name field
    /// ("NAME — street city country"); cut at the first spaced dash. Bare
    /// hyphens inside words (Al-Hidaya) are preserved.
    static func cleanMosqueName(_ name: String) -> String {
        let range = name.range(of: #"\s+[—–]\s*|\s+-\s+"#, options: .regularExpression)
        let cut = range.map { String(name[..<$0.lowerBound]) } ?? name
        let trimmed = cut.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? name.trimmingCharacters(in: .whitespacesAndNewlines) : trimmed
    }

    /// Today's (or any day's) six mosque times, or nil when the calendar
    /// doesn't cover the date (e.g. Dec 31 before the new year publishes).
    static func times(for date: Date, in calendar: [[String: [String]]]) -> [String]? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let month = cal.component(.month, from: date) - 1
        let day = cal.component(.day, from: date)
        guard month >= 0, month < calendar.count else { return nil }
        guard let times = calendar[month]["\(day)"], times.count >= 6 else { return nil }
        return times
    }

    // MARK: - Storage

    private static var storeURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Sajda", isDirectory: true)
            .appendingPathComponent("mawaqit_mosque.json")
    }

    static func load() -> MawaqitMosque? {
        guard let data = try? Data(contentsOf: storeURL) else { return nil }
        return try? JSONDecoder().decode(MawaqitMosque.self, from: data)
    }

    static func save(_ mosque: MawaqitMosque) throws {
        try FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(mosque).write(to: storeURL, options: .atomic)
    }

    static func deleteStored() {
        try? FileManager.default.removeItem(at: storeURL)
    }
}