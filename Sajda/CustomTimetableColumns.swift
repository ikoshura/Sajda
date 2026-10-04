// MARK: - Sajda/CustomTimetableColumns.swift
// Header fuzzy-matching for adhan/iqama CSV files.

import Foundation

extension CustomTimetableStore {
    enum CSVKind { case adhan, iqama }

    struct ColumnMap {
        var month = -1, day = -1, date = -1
        var fajr = -1, sunrise = -1, dhuhr = -1, asr = -1, maghrib = -1, isha = -1
        let kind: CSVKind
        /// Month to assume when the file has only a `Day` column (the
        /// per-month export names the month only in the filename).
        var externalMonth: Int?

        init(header: [String], kind: CSVKind, externalMonth: Int? = nil) {
            self.kind = kind
            self.externalMonth = externalMonth
            for (i, h) in header.enumerated() {
                switch h {
                case let s where s.hasPrefix("month") || s == "mois": if month < 0 { month = i }
                case "day", "jour", "d": if day < 0 { day = i }
                case "date": if date < 0 { date = i }
                case "fajr", "sobh", "subh", "subuh": if fajr < 0 { fajr = i }
                case "shuruk", "shuruq", "shourouk", "sunrise", "lever", "syuruk":
                    if sunrise < 0 { sunrise = i }
                case "duhr", "dhuhr", "dohr", "zuhr", "dzuhur", "dhuhur":
                    if dhuhr < 0 { dhuhr = i }
                case "asr", "asar": if asr < 0 { asr = i }
                case "maghrib", "maghreb", "magrib": if maghrib < 0 { maghrib = i }
                case "isha", "icha", "isya": if isha < 0 { isha = i }
                default: break
                }
            }
        }

        var hasDate: Bool { (month >= 0 && day >= 0) || date >= 0 || (day >= 0 && externalMonth != nil) }

        var isComplete: Bool {
            switch kind {
            case .adhan:
                return fajr >= 0 && sunrise >= 0 && dhuhr >= 0 && asr >= 0
                    && maghrib >= 0 && isha >= 0 && hasDate
            case .iqama:
                return fajr >= 0 && dhuhr >= 0 && asr >= 0 && maghrib >= 0
                    && isha >= 0 && hasDate
            }
        }

        var missingDescription: String {
            var out: [String] = []
            if !hasDate { out.append("Month/Day or Date") }
            if fajr < 0 { out.append("Fajr") }
            if kind == .adhan, sunrise < 0 { out.append("Sunrise/Shuruk") }
            if dhuhr < 0 { out.append("Dhuhr") }
            if asr < 0 { out.append("Asr") }
            if maghrib < 0 { out.append("Maghrib") }
            if isha < 0 { out.append("Isha") }
            return out.joined(separator: ", ")
        }

        func cell(_ row: [String], _ idx: Int) -> String? {
            guard idx >= 0, idx < row.count else { return nil }
            let v = row[idx].trimmingCharacters(in: .whitespacesAndNewlines)
            return v.isEmpty ? nil : v
        }

        func monthDay(_ row: [String]) -> (Int, Int)? {
            if month >= 0, day >= 0,
               let ms = cell(row, month), let ds = cell(row, day),
               let m = Int(ms), let d = Int(ds) {
                return (m, d)
            }
            // Day-only file (monthly export): month comes from the caller.
            if month < 0, date < 0, day >= 0, let ds = cell(row, day), let d = Int(ds) {
                return (externalMonth ?? 0, d)
            }
            if date >= 0, let ds = cell(row, date),
               let (m, d) = Self.parseDate(ds) {
                return (m, d)
            }
            return nil
        }

        func adhanRow(_ row: [String]) -> (Int, Int, [String])? {
            guard let (m, d) = monthDay(row),
                  let f = cell(row, fajr).flatMap(CustomTimetableStore.cleanHM),
                  let s = cell(row, sunrise).flatMap(CustomTimetableStore.cleanHM),
                  let dh = cell(row, dhuhr).flatMap(CustomTimetableStore.cleanHM),
                  let a = cell(row, asr).flatMap(CustomTimetableStore.cleanHM),
                  let ma = cell(row, maghrib).flatMap(CustomTimetableStore.cleanHM),
                  let i = cell(row, isha).flatMap(CustomTimetableStore.cleanHM) else { return nil }
            return (m, d, [f, s, dh, a, ma, i])
        }

        func iqamaRow(_ row: [String]) -> (Int, Int, [String])? {
            guard let (m, d) = monthDay(row),
                  let f = cell(row, fajr).flatMap(CustomTimetableStore.cleanHM),
                  let dh = cell(row, dhuhr).flatMap(CustomTimetableStore.cleanHM),
                  let a = cell(row, asr).flatMap(CustomTimetableStore.cleanHM),
                  let ma = cell(row, maghrib).flatMap(CustomTimetableStore.cleanHM),
                  let i = cell(row, isha).flatMap(CustomTimetableStore.cleanHM) else { return nil }
            return (m, d, [f, dh, a, ma, i])
        }

        static func parseDate(_ s: String) -> (month: Int, day: Int)? {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            let sep: Character? = t.contains("/") ? "/" : t.contains("-") ? "-" : t.contains(".") ? "." : nil
            guard let sep else { return nil }
            let parts = t.split(separator: sep).compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            if parts.count == 3 {
                if parts[0] > 31 {
                    guard (1...12).contains(parts[1]) else { return nil }
                    return (parts[1], parts[2])
                }
                guard (1...12).contains(parts[1]) else { return nil }
                return (parts[1], parts[0])
            }
            if parts.count == 2 {
                let (a, b) = (parts[0], parts[1])
                if (1...12).contains(a), (1...31).contains(b) { return (a, b) }
                if (1...12).contains(b), (1...31).contains(a) { return (b, a) }
            }
            return nil
        }
    }
}
