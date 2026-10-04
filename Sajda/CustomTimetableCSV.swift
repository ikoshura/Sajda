// MARK: - Sajda/CustomTimetableCSV.swift
// CSV row splitting + adhan/iqama/jumuah file parsers.

import Foundation

extension CustomTimetableStore {
    static func parseAdhanCSV(_ text: String, month: Int? = nil) throws -> [[String: [String]]] {
        let table = splitCSV(text)
        guard !table.isEmpty else { throw ImportError.emptyFile }
        let col = ColumnMap(header: table[0].map { normalizeHeader($0) }, kind: .adhan, externalMonth: month)
        guard col.isComplete else { throw ImportError.missingHeader(col.missingDescription) }
        var calendar = Array(repeating: [String: [String]](), count: 12)
        var usable = 0
        for row in table.dropFirst() {
            guard let (m0, d, times) = col.adhanRow(row) else { continue }
            // The per-month export has only a `Day` column: the month is
            // the file's own month, supplied by the caller. A file that carries
            // its own Month or Date column keeps the month it parsed.
            let m = (col.month >= 0 || col.date >= 0) ? m0 : (month ?? 0)
            guard (1...12).contains(m), (1...31).contains(d),
                  // February keeps a 29th row so a leap-year file holds Feb 29.
                  // A plain non-leap file's 29th row is actually the next
                  // month's day 1; `dropFebruarySpillover` cross-checks it
                  // against March after merging and removes it if so.
                  d <= (m == 2 ? 29 : daysInMonth(m)),
                  times.allSatisfy({ minutesFromHM($0) != nil }) else { continue }
            calendar[m - 1]["\(d)"] = times
            usable += 1
        }
        guard usable > 0 else { throw ImportError.noUsableRows }
        return calendar
    }

    /// Days in a month, using a non-leap February. The export appends a trailing
    /// next-month day-1 row to its February export ("29" in `02.csv`), so days
    /// past the real month length are treated as that spillover and dropped;
    /// a genuine leap-year Feb 29 then falls back to calculated times.
    static func daysInMonth(_ month: Int) -> Int {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12: return 31
        case 4, 6, 9, 11: return 30
        case 2: return 28
        default: return 31
        }
    }

    static func parseIqamaCSV(_ text: String) throws -> [[String: [String]]] {
        let table = splitCSV(text)
        guard !table.isEmpty else { throw ImportError.emptyFile }
        let col = ColumnMap(header: table[0].map { normalizeHeader($0) }, kind: .iqama)
        guard col.isComplete else { throw ImportError.missingHeader(col.missingDescription) }
        var calendar = Array(repeating: [String: [String]](), count: 12)
        var usable = 0
        for row in table.dropFirst() {
            guard let (m, d, times) = col.iqamaRow(row) else { continue }
            guard (1...12).contains(m), (1...31).contains(d),
                  times.allSatisfy({ minutesFromHM($0) != nil }) else { continue }
            calendar[m - 1]["\(d)"] = times
            usable += 1
        }
        guard usable > 0 else { throw ImportError.noUsableRows }
        return calendar
    }

    /// Merges per-month CSV exports (01.csv … 12.csv) into one
    /// 12-month calendar. Each file's month comes from its filename; a file
    /// that carries its own Month/Date column is used as-is.
    static func parseAdhanFiles(_ urls: [URL]) throws -> [[String: [String]]] {
        var calendar = Array(repeating: [String: [String]](), count: 12)
        var usable = 0
        for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let text = try String(contentsOf: url, encoding: .utf8)
            let month = monthFromFilename(url)
            let partial = try parseAdhanCSV(text, month: month)
            for index in 0..<12 where !partial[index].isEmpty {
                calendar[index].merge(partial[index]) { _, new in new }
                usable += partial[index].count
            }
        }
        calendar = dropFebruarySpillover(calendar)
        guard usable > 0 else { throw ImportError.noUsableRows }
        return calendar
    }

    /// February's 29th row is either a real leap-year Feb 29 or, in a plain
    /// non-leap file, the export's copy of March 1 appended as a spillover. The
    /// two are told apart by comparing against March's day 1 when March is
    /// present: identical times mean spillover (drop it), different times mean
    /// a genuine Feb 29 (keep it). With no March file to check against, the
    /// safer reading is spillover, so it is dropped.
    static func dropFebruarySpillover(_ calendar: [[String: [String]]]) -> [[String: [String]]] {
        guard calendar.count == 12, let feb29 = calendar[1]["29"] else { return calendar }
        guard let mar1 = calendar[2]["1"] else {
            var out = calendar
            out[1]["29"] = nil
            return out
        }
        guard feb29 == mar1 else { return calendar }
        var out = calendar
        out[1]["29"] = nil
        return out
    }

    /// "01.csv" / "1.csv" / "january.csv" -> 1 ... 12, or nil.
    static func monthFromFilename(_ url: URL) -> Int? {
        let stem = url.deletingPathExtension().lastPathComponent
        // Leading number, e.g. "01" or "01 - Mosque".
        let leading = stem.prefix { $0.isNumber }
        if !leading.isEmpty, let value = Int(leading), (1...12).contains(value) { return value }
        let lower = stem.lowercased()
        let names = ["january", "february", "march", "april", "may", "june",
                     "july", "august", "september", "october", "november", "december"]
        for (index, name) in names.enumerated() where lower.contains(name) { return index + 1 }
        return nil
    }

    /// Parses a jumuah file: one "HH:MM" per line, or one CSV row of times.
    static func parseJumuah(_ text: String) throws -> [String] {
        let candidates = text
            .replacingOccurrences(of: ";", with: ",")
            .split(whereSeparator: { $0.isNewline || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let times = candidates.compactMap { cleanHM($0) }
        guard !times.isEmpty else { throw ImportError.noUsableRows }
        return Array(times.prefix(5))
    }

    static func normalizeHeader(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
    }

    static func splitCSV(_ text: String) -> [[String]] {
        let lines = text.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let first = lines.first else { return [] }
        let semis = first.filter { $0 == ";" }.count
        let commas = first.filter { $0 == "," }.count
        let delimiter: Character = semis > commas ? ";" : first.contains("\t") ? "\t" : ","
        return lines.map { splitLine($0, delimiter: delimiter) }
    }

    private static func splitLine(_ line: String, delimiter: Character) -> [String] {
        var cells: [String] = []
        var current = ""
        var inQuotes = false
        var quote: Character = "\""
        for ch in line {
            if inQuotes {
                if ch == quote { inQuotes = false } else { current.append(ch) }
            } else if ch == "\"" || ch == "'" {
                inQuotes = true; quote = ch
            } else if ch == delimiter {
                cells.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(ch)
            }
        }
        cells.append(current.trimmingCharacters(in: .whitespaces))
        return cells
    }
}
