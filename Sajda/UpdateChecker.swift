// MARK: - Sajda/UpdateChecker.swift
//
// In-app updates through Sparkle 2.
//
// Sparkle owns the whole cycle — feed fetch, EdDSA signature check, download,
// install, relaunch — so this class is only the thin SwiftUI-facing shell
// around it. Its job is to (a) start the updater, (b) mirror the existing
// "check automatically" preference onto Sparkle, and (c) translate Sparkle's
// delegate callbacks into the `State` the panel's footer badge and the About
// page already render.
//
// Configuration lives in `Sajda/Info.plist` (SUFeedURL + SUPublicEDKey, and
// SUEnableInstallerLauncherService for the sandbox), so nothing about the feed
// or the signing key is hard-coded here.

import Foundation
import Combine
import AppKit
import Sparkle

@MainActor
final class UpdateChecker: NSObject, ObservableObject, SPUUpdaterDelegate {
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

    /// Still the human-facing releases page: the About copy links here when a
    /// user would rather read the notes than let Sparkle install the update.
    static let releasesPageURL = URL(string: "https://github.com/ikoshura/Sajda/releases")!

    /// True only for the span of a user-initiated check, so "no update found"
    /// can be reported as *up to date* from the About page while a background
    /// check stays silent instead of painting a result the user never asked for.
    private var isManualCheckInFlight = false

    /// Sparkle's entry point. Created on first use (i.e. on the main thread,
    /// from `checkIfDue()` at launch) and retained for the app's lifetime —
    /// Sparkle requires its controller to outlive every check it starts.
    private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: self,
        userDriverDelegate: nil
    )

    private var updater: SPUUpdater { controller.updater }

    // MARK: - Public surface used by the panel

    var updateAvailable: Bool {
        if case .updateAvailable = state { return true }
        return false
    }

    /// Keeps Sparkle's own background schedule in step with the app's opt-in
    /// switch, then asks for a check right now.
    ///
    /// The old UserDefaults 24h throttle is gone on purpose: Sparkle throttles
    /// itself (`SULastCheckTime`) and survives relaunches, which is the
    /// behaviour the hand-rolled version was approximating. Called on launch
    /// and whenever the Settings/Onboarding switch flips.
    func checkIfDue() {
        let enabled = autoCheckEnabled
        updater.automaticallyChecksForUpdates = enabled
        guard enabled else { return }
        updater.checkForUpdatesInBackground()
    }

    /// Manual check from About or the panel's footer badge. Unlike the
    /// background path this always surfaces UI — Sparkle's window either
    /// offers the update or reports that the app is current.
    func checkManually() {
        isManualCheckInFlight = true
        state = .checking
        updater.checkForUpdates()
    }

    /// Opens the releases page in the browser, for the read-the-notes path.
    func openReleasePage() {
        NSWorkspace.shared.open(releaseURL ?? Self.releasesPageURL)
    }

    // MARK: - SPUUpdaterDelegate

    /// A signed, newer item came back from the feed.
    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let version = item.displayVersionString
        let notesURL = item.releaseNotesURL
        Task { @MainActor in
            self.latestVersion = version
            let url = notesURL ?? Self.releasesPageURL
            self.releaseURL = url
            self.state = .updateAvailable(version: version, url: url)
            self.isManualCheckInFlight = false
        }
    }

    /// No newer item in the feed — or the check itself failed. Either way the
    /// result is only *reported* when the user asked for the check.
    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        Task { @MainActor in
            self.state = self.isManualCheckInFlight ? .upToDate : .idle
            self.isManualCheckInFlight = false
        }
    }

    /// The update cycle aborted — bad signature, unreadable feed, install
    /// failure.
    nonisolated func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        Task { @MainActor in
            self.state = .failed
            self.isManualCheckInFlight = false
        }
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

    /// Clears an `updateAvailable` badge that the running bundle already
    /// satisfies — the case where Sparkle found an update earlier in this
    /// launch and the user then updated by some other route (a manual DMG, for
    /// instance). Cheap, so it is safe to call from `onAppear`.
    func revalidateAgainstCurrentVersion() {
        guard case .updateAvailable(let version, _) = state else { return }
        guard let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else { return }
        if !Self.isNewer(version, than: current) {
            state = .idle
            updateBannerDismissed = false
        }
    }
}

