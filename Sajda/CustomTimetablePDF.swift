// MARK: - Sajda/CustomTimetablePDF.swift
//
// Parses a mosque "Annual prayer calendar" PDF (one page per month) into a
// CustomTimetable: adhan times, iqama, and Jumu'ah sessions.
//
// Works on PDFKit's plain text (`PDFPage.string`), never on glyph geometry:
// the glyph coordinates in these files are inconsistent, so a position-based
// reader produced interleaved garbage. The text however is regular: a header
// line, then one line per day carrying the date, the weekday, an optional
// Jumu'ah time, and the Fajr time; then the five remaining prayer columns as
// time/offset pairs, in header order.
//
// Day line, e.g.:
//   2026-01-02 13 Rajab 1447 Vrijdag / Salat al-jumua 13:50 & 14:30 07:05
//     -> day 2, Jumu'ah 13:50 + 14:30, Fajr 07:05
// The line after it carries the Fajr iqama offset ("+8").

import Foundation
import PDFKit

extension CustomTimetableStore {
    /// Reads a mosque calendar PDF into a CustomTimetable.
    static func parsePDF(url: URL) throws -> CustomTimetable {
        guard let doc = PDFDocument(url: url) else { throw ImportError.pdfUnreadable }
        var pages: [String] = []
        for index in 0..<doc.pageCount {
            if let text = doc.page(at: index)?.string { pages.append(text) }
        }
        guard !pages.isEmpty else { throw ImportError.pdfUnreadable }
        return try parsePDFPages(pages, name: url.deletingPathExtension().lastPathComponent)
    }

    /// Pure form: parses already-extracted page texts (unit-testable).
    static func parsePDFPages(_ pages: [String], name: String) throws -> CustomTimetable {
        var adhan = Array(repeating: [String: [String]](), count: 12)
        var iqama = Array(repeating: [String: [String]](), count: 12)
        var jumuaSet = Set<String>()
        var dayCount = 0

        for page in pages {
            let lines = page.components(separatedBy: "\n")
            guard let headerIndex = lines.firstIndex(where: { isCalendarHeader($0) }) else { continue }
            var index = headerIndex + 1

            struct Day { var month: Int; var day: Int; var fajr: String; var fajrOffset: Int?; var jumua: [String] }
            var days: [Day] = []

            // A page covers exactly one month: its first date row names it. The
            // remaining rows must belong to that month — the export appends a
            // next-month day-1 spillover row (e.g. "2026-03-01" at the foot of
            // the February page), which would otherwise be double-counted.
            var pageMonth: Int?
            // Day rows, each followed by its Fajr iqama-offset line.
            while index < lines.count, let (month, day) = datePrefix(in: lines[index]) {
                let line = lines[index]
                if let known = pageMonth, month != known {
                    // Spillover row: consume it and its offset, then stop.
                    index += 1
                    if index < lines.count, signedInt(lines[index]) != nil { index += 1 }
                    continue
                }
                if pageMonth == nil { pageMonth = month }
                let times = allTimes(in: line)
                let fajr = times.last ?? ""
                var jumua: [String] = []
                if let range = line.range(of: "al-jumua") {
                    var tailTimes = allTimes(in: String(line[range.upperBound...]))
                    if !tailTimes.isEmpty { tailTimes.removeLast() }
                    jumua = tailTimes
                }
                index += 1
                var fajrOffset: Int?
                if index < lines.count, let offset = signedInt(lines[index]) {
                    fajrOffset = offset
                    index += 1
                }
                days.append(Day(month: month, day: day, fajr: fajr,
                                fajrOffset: fajrOffset, jumua: jumua))
            }
            guard !days.isEmpty else { continue }

            // Remaining column blocks: pairs of a time line then an offset line.
            var pairs: [(time: String, offset: Int?)] = []
            while index < lines.count {
                let timeLine = lines[index].trimmingCharacters(in: .whitespaces)
                if isTime(timeLine) {
                    var offset: Int?
                    if index + 1 < lines.count, let value = signedInt(lines[index + 1]) {
                        offset = value
                        index += 1
                    }
                    pairs.append((timeLine, offset))
                }
                index += 1
            }

            let n = days.count
            // Columns after Fajr, in the calendar header order.
            guard pairs.count >= 5 * n else {
                // Layout differs from the expected shape; skip the page rather
                // than import misaligned times.
                continue
            }
            let shoe = Array(pairs[0..<n])
            let dho  = Array(pairs[n..<(2 * n)])
            let asr  = Array(pairs[(2 * n)..<(3 * n)])
            let magh = Array(pairs[(3 * n)..<(4 * n)])
            let isha = Array(pairs[(4 * n)..<(5 * n)])

            for (i, day) in days.enumerated() {
                let times = [day.fajr, shoe[i].time, dho[i].time, asr[i].time, magh[i].time, isha[i].time]
                guard times.allSatisfy({ minutesFromHM($0) != nil }),
                      (1...12).contains(day.month), (1...31).contains(day.day) else { continue }
                adhan[day.month - 1]["\(day.day)"] = times
                dayCount += 1

                // Iqama as absolute clock times: adhan + the column's offset.
                let offsets = [day.fajrOffset, dho[i].offset, asr[i].offset, magh[i].offset, isha[i].offset]
                let adhanForIqama = [day.fajr, dho[i].time, asr[i].time, magh[i].time, isha[i].time]
                var absolute: [String] = []
                var complete = true
                for (time, offset) in zip(adhanForIqama, offsets) {
                    guard let offset, let minutes = minutesFromHM(time) else { complete = false; break }
                    absolute.append(clockString(minutes + offset))
                }
                if complete, absolute.count == 5 {
                    iqama[day.month - 1]["\(day.day)"] = absolute
                }

                for session in day.jumua where minutesFromHM(session) != nil {
                    jumuaSet.insert(session)
                }
            }
        }

        guard dayCount > 0 else { throw ImportError.noUsableRows }
        // Jumu'ah can shift seasonally (13:00 in winter, 14:00 in summer); the
        // app shows one list every Friday, so the union is stored and the user
        // can trim it in Settings.
        let jumua = jumuaSet.sorted { (minutesFromHM($0) ?? 0) < (minutesFromHM($1) ?? 0) }
        return CustomTimetable(name: name, calendar: adhan,
                               iqamaCalendar: iqama.contains(where: { !$0.isEmpty }) ? iqama : nil,
                               jumuahSessions: jumua)
    }

    /// Header line, tolerant of localised labels.
    private static func isCalendarHeader(_ line: String) -> Bool {
        let lower = line.lowercased()
        let hasFajr = lower.contains("fajr") || lower.contains("fadjr")
        let hasOther = lower.contains("shoeroeq") || lower.contains("shuruk")
            || lower.contains("shuruq") || lower.contains("sunrise")
            || lower.contains("maghrib") || lower.contains("ishaa") || lower.contains("isha")
        return hasFajr && hasOther
    }

    /// "2026-01-02 13 Rajab..." -> (1, 2).
    private static func datePrefix(in line: String) -> (month: Int, day: Int)? {
        guard line.count >= 10 else { return nil }
        let prefix = Array(line.prefix(10))
        guard prefix[4] == "-", prefix[7] == "-" else { return nil }
        let month = String(prefix[5..<7]); let day = String(prefix[8..<10])
        guard month.allSatisfy(\.isNumber), day.allSatisfy(\.isNumber),
              let m = Int(month), let d = Int(day) else { return nil }
        return (m, d)
    }

    private static func allTimes(in text: String) -> [String] {
        let regex = try? NSRegularExpression(pattern: #"\b\d{1,2}:\d{2}\b"#)
        let ns = text as NSString
        return (regex?.matches(in: text, range: NSRange(location: 0, length: ns.length)) ?? [])
            .map { ns.substring(with: $0.range) }
    }

    private static func isTime(_ line: String) -> Bool {
        minutesFromHM(line.trimmingCharacters(in: .whitespaces)) != nil
    }

    /// "+8" / "10" / "0" -> Int, else nil.
    private static func signedInt(_ line: String) -> Int? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let digits = trimmed.hasPrefix("+") ? String(trimmed.dropFirst()) : trimmed
        guard !digits.isEmpty, digits.allSatisfy(\.isNumber), let value = Int(digits) else { return nil }
        return value
    }

    /// Minutes past midnight -> "HH:MM", wrapping at midnight.
    private static func clockString(_ minutes: Int) -> String {
        let wrapped = ((minutes % 1440) + 1440) % 1440
        return String(format: "%02d:%02d", wrapped / 60, wrapped % 60)
    }
}
