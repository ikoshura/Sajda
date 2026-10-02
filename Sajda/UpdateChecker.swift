// MARK: - Sajda/UpdateChecker.swift
//
// Lightweight in-app update check via the GitHub Releases API.
// No Sparkle dependency, works with unsigned builds: when a newer
// release exists we surface a banner and open the release page.

import Foundation
import Combine
import AppKit

@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case updateAvailable(version: String, url: URL)
        case failed
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var latestVersion: String?
    @Published private(set) var releaseURL: URL?
    /// Dismissed from the MainView banner ("Later"): hides the banner for
    /// this launch only. The About page keeps showing the update — it binds
    /// `state` directly, never this flag.
    @Published var updateBannerDismissed = false

    /// Opt-in: automatic checks only run when the user enables this.
    /// Stored here so both Settings and About bind to the same key.
    static let autoCheckKey = "autoCheckForUpdates"

    var autoCheckEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.autoCheckKey)
    }

    private static let latestReleaseURL = URL(string: "https://api.github.com/repos/ikoshura/Sajda/releases/latest")!
    private static let releasesPageURL = URL(string: "https://github.com/ikoshura/Sajda/releases")!
    private static let lastCheckKey = "lastUpdateCheckDate"
    private static let checkInterval: TimeInterval = 24 * 60 * 60

    var updateAvailable: Bool {
        if case .updateAvailable = state { return true }
        return false
    }

    /// Silent background check, throttled to once per 24h. Only runs when
    /// the user has opted in via Settings. Call on launch.
    func checkIfDue() {
        guard autoCheckEnabled else { return }
        // A badge left over from before the user updated must fall off on
        // launch — even when the 24h throttle says "no new network check".
        revalidateAgainstCurrentVersion()
        if case .updateAvailable = state { return }
        let last = UserDefaults.standard.object(forKey: Self.lastCheckKey) as? Date
        if let last, Date().timeIntervalSince(last) < Self.checkInterval { return }
        Task { await check(showUpToDate: false) }
    }

    /// Manual check from About. Always hits the network and reports the result.
    func checkManually() {
        Task { await check(showUpToDate: true) }
    }

    func openReleasePage() {
        if let releaseURL {
            NSWorkspace.shared.open(releaseURL)
        } else {
            NSWorkspace.shared.open(Self.releasesPageURL)
        }
    }

    private func check(showUpToDate: Bool) async {
        if case .checking = state { return }
        state = .checking
        do {
            var request = URLRequest(url: Self.latestReleaseURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
            request.setValue("Sajda", forHTTPHeaderField: "User-Agent")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            // Cache the check time only on a real answer from the API: a
            // rate-limit (403/429) or any non-2xx must not start the 24h
            // silence, or auto-check looks dead after one throttled call.
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                state = .failed; return
            }
            UserDefaults.standard.set(Date(), forKey: Self.lastCheckKey)
            guard
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let tag = json["tag_name"] as? String
            else { state = .failed; return }
            let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            latestVersion = latest
            let htmlURL = (json["html_url"] as? String).flatMap(URL.init(string:)) ?? Self.releasesPageURL
            releaseURL = htmlURL
            if Self.isNewer(latest, than: Self.currentVersion) {
                state = .updateAvailable(version: latest, url: htmlURL)
            } else if showUpToDate {
                state = .upToDate
            } else {
                state = .idle
            }
        } catch {
            state = .failed
        }
    }

    private static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// Numeric dot-separated comparison ("3.10.0" > "3.9.0").
    ///
    /// Hardened for real-world version strings: trims whitespace, drops build
    /// metadata ("+123") and pre-release suffixes ("-beta.1") before comparing,
    /// and ignores non-numeric segments — so "4.4.13 (511)" or "v4.4.13"
    /// never reads as newer than the installed "4.4.13". This is what clears
    /// a stale footer/About badge right after the user updates (#24: the
    /// "persistent icon" report).
    static func isNewer(_ latest: String, than current: String) -> Bool {
        let l = normalizedComponents(latest)
        let c = normalizedComponents(current)
        for i in 0..<max(l.count, c.count) {
            let lv = i < l.count ? l[i] : 0
            let cv = i < c.count ? c[i] : 0
            if lv != cv { return lv > cv }
        }
        return false
    }

    /// "  v4.4.13-beta.1+5 " -> [4, 4, 13]. Non-numeric segments count as 0
    /// so an unexpected tag can never outrank the installed build.
    private static func normalizedComponents(_ version: String) -> [Int] {
        var v = version.trimmingCharacters(in: .whitespacesAndNewlines)
        if v.hasPrefix("v") || v.hasPrefix("V") { v.removeFirst() }
        // Build metadata never affects precedence.
        if let plus = v.firstIndex(of: "+") { v = String(v[..<plus]) }
        // Pre-release suffix: compare the numeric core only, so "4.4.13-beta"
        // equals "4.4.13" rather than looking newer.
        if let dash = v.firstIndex(of: "-") { v = String(v[..<dash]) }
        // Some tags append "(build)" after a space: keep the leading core.
        if let space = v.firstIndex(of: " ") { v = String(v[..<space]) }
        return v.split(separator: ".").map { Int($0.trimmingCharacters(in: .whitespaces)) ?? 0 }
    }

    /// Clears a stale `.updateAvailable` that no longer outranks the running
    /// app — e.g. the user just updated but this process hasn't re-checked
    /// yet. Safe to call on launch and on view appear; a no-op otherwise.
    func revalidateAgainstCurrentVersion() {
        if case .updateAvailable(let version, _) = state,
           !Self.isNewer(version, than: Self.currentVersion) {
            state = .idle
            updateBannerDismissed = false
        }
    }
}

