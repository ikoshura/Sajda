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
        let last = UserDefaults.standard.object(forKey: Self.lastCheckKey) as? Date
        if let last, Date().timeIntervalSince(last) < Self.checkInterval, latestVersion != nil {
            return
        }
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
        defer { UserDefaults.standard.set(Date(), forKey: Self.lastCheckKey) }
        do {
            var request = URLRequest(url: Self.latestReleaseURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
            request.setValue("Sajda", forHTTPHeaderField: "User-Agent")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, _) = try await URLSession.shared.data(for: request)
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
    static func isNewer(_ latest: String, than current: String) -> Bool {
        let l = latest.split(separator: ".").map { Int($0) ?? 0 }
        let c = current.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(l.count, c.count) {
            let lv = i < l.count ? l[i] : 0
            let cv = i < c.count ? c[i] : 0
            if lv != cv { return lv > cv }
        }
        return false
    }
}

