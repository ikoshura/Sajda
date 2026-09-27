//
//  SajdaTests.swift
//  SajdaTests
//
//  Created by Aliyya Nazhifah on 28/08/25.
//

import XCTest
import Combine
import SwiftUI
@testable import Sajda

final class SajdaTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

    // MARK: - Cached-schedule merge

    /// A per-favorite cache written by an older build carries no Jumu'ah or
    /// iqama fields. Activating that copy is what made the Jumu'ah footer
    /// disappear on a mosque → city → mosque round trip, so the merge has to
    /// restore exactly the fields the fresh copy is missing — and nothing else.
    func testMergingRestoresMissingSessionsWithoutTouchingAnythingElse() {
        let stale = MawaqitMosque(slug: "mosque", name: "Old Name", fetchedAt: Date(timeIntervalSince1970: 0),
                                   calendar: [[String: [String]]]())
        let fresh = MawaqitMosque(slug: "mosque", name: "New Name", fetchedAt: Date(timeIntervalSince1970: 100),
                                   calendar: [[String: [String]]](repeating: [:], count: 12),
                                   jumuaSessions: ["13:30", "14:30"],
                                   iqamaCalendar: [[String: [String]]](repeating: [:], count: 12))
        let merged = MawaqitService.merging(stale, with: fresh)

        // The missing fields come across…
        XCTAssertEqual(merged.jumuaSessions, ["13:30", "14:30"])
        XCTAssertNotNil(merged.iqamaCalendar)
        // …and everything the stale copy already had is left alone: it is the
        // copy being activated, so its own calendar and metadata must survive.
        XCTAssertEqual(merged.name, "Old Name")
        XCTAssertEqual(merged.fetchedAt, Date(timeIntervalSince1970: 0))
        XCTAssertTrue(merged.calendar.isEmpty)
    }

    /// A complete copy is returned untouched, and merging from a copy that has
    /// nothing either leaves the empties as nil rather than as empty arrays —
    /// `nil` and `[]` mean the same thing downstream, but nil round-trips
    /// through JSON as absent instead of as noise on every save.
    func testMergingIsANoOpWhenNothingIsMissing() {
        let iqama = [[String: [String]]](repeating: [:], count: 12)
        let complete = MawaqitMosque(slug: "m", name: "N", fetchedAt: Date(), calendar: [],
                                     jumuaSessions: ["13:30"], iqamaCalendar: iqama)
        let merged = MawaqitService.merging(complete, with: MawaqitMosque(slug: "m", name: "Other", fetchedAt: Date(), calendar: []))
        XCTAssertEqual(merged.jumuaSessions, ["13:30"])
        XCTAssertNotNil(merged.iqamaCalendar)

        let bare = MawaqitService.merging(MawaqitMosque(slug: "m", name: "N", fetchedAt: Date(), calendar: []),
                                          with: MawaqitMosque(slug: "m", name: "N", fetchedAt: Date(), calendar: []))
        XCTAssertNil(bare.jumuaSessions)
        XCTAssertNil(bare.iqamaCalendar)
    }

    // MARK: - Mosque iqama offsets

    /// Mawaqit publishes the mosque's own iqama gaps as signed minute strings,
    /// five of them in a fixed prayer order (sunrise has no iqama). The app
    /// follows these in mosque mode instead of estimating, so the sign has to
    /// be stripped without swallowing the value.
    func testMinutesFromSignedOffset() {
        XCTAssertEqual(MawaqitService.minutesFromSignedOffset("+20"), 20)
        XCTAssertEqual(MawaqitService.minutesFromSignedOffset("+0"), 0)
        // A missing sign (older entries) is still a valid gap.
        XCTAssertEqual(MawaqitService.minutesFromSignedOffset("10"), 10)
        XCTAssertEqual(MawaqitService.minutesFromSignedOffset("  +7 "), 7)
        // An iqama can't precede its adhan, and junk is simply unusable.
        XCTAssertNil(MawaqitService.minutesFromSignedOffset("-5"))
        XCTAssertNil(MawaqitService.minutesFromSignedOffset("+abc"))
        XCTAssertNil(MawaqitService.minutesFromSignedOffset(""))
        XCTAssertNil(MawaqitService.minutesFromSignedOffset("+"))
    }

    /// The five offsets are positional, so they have to land on the right
    /// prayer names — a shift by one would silently give Asr the Dhuhr iqama.
    func testIqamaOffsetsMapOntoTheRightPrayers() {
        var calendar = Array(repeating: [String: [String]](), count: 12)
        calendar[0]["1"] = ["+20", "+10", "+10", "+7", "+10"]
        let offsets = MawaqitService.iqamaOffsets(for: date(year: 2026, month: 1, day: 1), in: calendar)
        XCTAssertEqual(offsets, ["Fajr": 20, "Dhuhr": 10, "Asr": 10, "Maghrib": 7, "Isha": 10])
    }

    /// One bad entry must not cost the other four, and a mosque that publishes
    /// nothing usable has to come back empty so the caller falls back to the
    /// user's own gap rather than showing a bogus iqama.
    func testIqamaOffsetsDegradeGracefully() {
        var calendar = Array(repeating: [String: [String]](), count: 12)
        calendar[0]["1"] = ["+20", "?", "+10", "+7", "+10"]
        let partial = MawaqitService.iqamaOffsets(for: date(year: 2026, month: 1, day: 1), in: calendar)
        XCTAssertNil(partial["Dhuhr"])
        XCTAssertEqual(partial["Fajr"], 20)
        XCTAssertEqual(partial["Isha"], 10)

        // A short row can't fill all five; the rest fall back.
        var short = Array(repeating: [String: [String]](), count: 12)
        short[0]["1"] = ["+20", "+10"]
        let shortOffsets = MawaqitService.iqamaOffsets(for: date(year: 2026, month: 1, day: 1), in: short)
        XCTAssertEqual(shortOffsets, ["Fajr": 20, "Dhuhr": 10])

        // No calendar at all, the wrong number of months, and a date the
        // calendar doesn't cover all come back empty.
        XCTAssertTrue(MawaqitService.iqamaOffsets(for: date(year: 2026, month: 1, day: 1), in: nil).isEmpty)
        XCTAssertTrue(MawaqitService.iqamaOffsets(for: date(year: 2026, month: 1, day: 1),
                                                in: [[String: [String]]](repeating: [:], count: 3)).isEmpty)
        XCTAssertTrue(MawaqitService.iqamaOffsets(for: date(year: 2026, month: 3, day: 9), in: calendar).isEmpty)
    }

    /// Local-timezone date at midnight, for the calendar lookups above.
    private func date(year: Int, month: Int, day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: - Jumu'ah sessions

    /// Mawaqit publishes the Friday gatherings in three separate confData
    /// fields, not as a list. Only the first was read, which is why a mosque
    /// running two khutbahs (Aubervilliers: 13:30 + 14:30) showed a single
    /// session. Every populated field has to come through, in order.
    func testJumuaTimesKeepsEveryPublishedSession() {
        XCTAssertEqual(MawaqitService.jumuaTimes(["13:30", "14:30", nil]), ["13:30", "14:30"])
        XCTAssertEqual(MawaqitService.jumuaTimes(["13:41", nil, nil]), ["13:41"])
        XCTAssertEqual(
            MawaqitService.jumuaTimes(["12:30", "13:00", "14:15"]),
            ["12:30", "13:00", "14:15"]
        )
    }

    /// A gap in the middle of the three fields (a mosque with a first and a
    /// third khutbah but no second) must not leave a hole, and a blank or
    /// malformed value must not become a bogus midnight session.
    func testJumuaTimesDropsBlanksAndJunk() {
        XCTAssertEqual(MawaqitService.jumuaTimes(["13:30", nil, "14:30"]), ["13:30", "14:30"])
        XCTAssertEqual(MawaqitService.jumuaTimes([nil, "  ", nil]), [])
        XCTAssertEqual(MawaqitService.jumuaTimes(["", "-", nil]), [])
        XCTAssertEqual(MawaqitService.jumuaTimes([nil, nil, nil]), [])
        // Surrounding whitespace from the page is trimmed, not rejected.
        XCTAssertEqual(MawaqitService.jumuaTimes([" 13:30 ", nil, nil]), ["13:30"])
    }

    /// "HH:MM" → minutes past midnight, guarding the range so a malformed
    /// entry can't become a session outside the 0...1439 clock.
    func testMinutesFromHM() {
        XCTAssertEqual(MawaqitService.minutesFromHM("13:30"), 13 * 60 + 30)
        XCTAssertEqual(MawaqitService.minutesFromHM("00:00"), 0)
        XCTAssertEqual(MawaqitService.minutesFromHM("23:59"), 23 * 60 + 59)
        // Seconds are accepted and dropped — Mawaqit writes them sometimes.
        XCTAssertEqual(MawaqitService.minutesFromHM("13:30:00"), 13 * 60 + 30)
        XCTAssertNil(MawaqitService.minutesFromHM("24:00"))
        XCTAssertNil(MawaqitService.minutesFromHM("13:60"))
        XCTAssertNil(MawaqitService.minutesFromHM("1330"))
        XCTAssertNil(MawaqitService.minutesFromHM(""))
    }

    /// A session added in Settings is seeded at the quarter hour just after
    /// Dhuhr, so a mosque that starts Jumu'ah minutes past Dhuhr never gets a
    /// row at an arbitrary morning time (the old seed followed the wall clock).
    func testJumuahSessionSeedRoundsDhuhrUpToTheNextQuarterHour() {
        XCTAssertEqual(PrayerTimeViewModel.jumuahSessionSeed(hour: 12, minute: 17), 12 * 60 + 30)
        // Dhuhr sitting exactly on a quarter still moves forward: the seed is
        // the *next* quarter hour, never the one it is already on.
        XCTAssertEqual(PrayerTimeViewModel.jumuahSessionSeed(hour: 12, minute: 15), 12 * 60 + 30)
        XCTAssertEqual(PrayerTimeViewModel.jumuahSessionSeed(hour: 12, minute: 30), 12 * 60 + 45)
        XCTAssertEqual(PrayerTimeViewModel.jumuahSessionSeed(hour: 13, minute: 5), 13 * 60 + 15)
        // Late Dhuhr wraps to the start of the next day instead of overflowing
        // the 0...1439 clock the session list is stored in.
        XCTAssertEqual(PrayerTimeViewModel.jumuahSessionSeed(hour: 23, minute: 50), 0)
    }

    // MARK: - Settings tab (the dropdown)

    /// The tab bar only ever builds the picked tab's rows and the panel resizes
    /// to them, so the tab write has to repaint the page and re-key the menu's
    /// resize animation. `settingsSelectedTab` is @AppStorage on the view model,
    /// which does not publish on its own — this is the test that keeps its
    /// `didSet` republish in place.
    func testSettingsSelectedTabPublishesEveryWrite() {
        let vm = PrayerTimeViewModel()
        var changes = 0
        let cancellable = vm.objectWillChange.sink { _ in changes += 1 }

        vm.settingsSelectedTab = "prayerTimes"
        XCTAssertEqual(vm.settingsSelectedTab, "prayerTimes")
        XCTAssertGreaterThan(changes, 0)

        let afterFirstWrite = changes
        vm.settingsSelectedTab = "display"
        XCTAssertEqual(vm.settingsSelectedTab, "display")
        XCTAssertGreaterThan(changes, afterFirstWrite)

        cancellable.cancel()
    }

    /// Reopening Settings resets the tab to Display so the panel is already the
    /// right height on its first frame. This is the test that keeps the reset
    /// inside a `disablesAnimations` transaction: `settingsSelectedTab` is part
    /// of `panelLayoutSignature`, the `value:` of the menu's resize animation,
    /// so an animated reset during an open made the panel visibly flicker.
    /// A transaction is only current for the duration of its own write, so the
    /// observable contract is that the reset lands and completes rather than
    /// half-applying; the `disablesAnimations` flag itself is asserted by
    /// reading it inside a transaction in the implementation.
    func testResetSettingsTabToDisplayResetsUnlockedTab() {
        let vm = PrayerTimeViewModel()
        vm.settingsTabLocked = false

        vm.settingsSelectedTab = "prayerTimes"
        vm.resetSettingsTabToDisplay()
        XCTAssertEqual(vm.settingsSelectedTab, "display")
    }

    /// Locked keeps the last-used tab across a reopen, which is what the lock
    /// icon is for — the reset helper is a no-op in that state.
    func testResetSettingsTabToDisplayKeepsTabWhenLocked() {
        let vm = PrayerTimeViewModel()
        vm.settingsTabLocked = true
        defer { vm.settingsTabLocked = false }

        vm.settingsSelectedTab = "system"
        vm.resetSettingsTabToDisplay()
        XCTAssertEqual(vm.settingsSelectedTab, "system")
    }

    // MARK: - Colour dropdown

    /// The inline colour surface seeds its HSB state from the picked colour when
    /// it drops down (its own `Color.hue/…` helpers are internal to the package,
    /// so the conversion runs through `PrayerTimeViewModel.hsbaComponents`).
    func testColorPickerSeedsHSBAComponentsFromThePickedColour() {
        let red = PrayerTimeViewModel.hsbaComponents(from: Color(red: 1, green: 0, blue: 0))
        XCTAssertEqual(red.saturation, 1, accuracy: 0.001)
        XCTAssertEqual(red.brightness, 1, accuracy: 0.001)
        XCTAssertEqual(red.alpha, 1, accuracy: 0.001)
        // Pure red sits at either end of the wheel depending on how the colour
        // space rounds it — both read as 0° to the surface.
        XCTAssertTrue(red.hue < 0.001 || red.hue > 0.999, "red hue was \(red.hue)")

        // r 0, g ½, b 1 → 210° on the colour wheel, still fully saturated.
        let cyanish = PrayerTimeViewModel.hsbaComponents(from: Color(red: 0, green: 0.5, blue: 1))
        XCTAssertEqual(cyanish.hue, 210.0 / 360.0, accuracy: 0.02, "cyanish hue was \(cyanish.hue)")
        XCTAssertEqual(cyanish.brightness, 1, accuracy: 0.001)

        // Nothing picked yet: the surface opens bright and unsaturated rather
        // than collapsed into a corner.
        let none = PrayerTimeViewModel.hsbaComponents(from: nil)
        XCTAssertEqual(none.saturation, 1)
        XCTAssertEqual(none.brightness, 1)
        XCTAssertEqual(none.alpha, 1)
    }

}
