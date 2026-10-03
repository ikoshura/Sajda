//
//  SajdaTests.swift
//  SajdaTests
//
//  Created by Aliyya Nazhifah on 28/08/25.
//

import XCTest
import Combine
import SwiftUI
import AppKit
import CoreText
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
    /// to them, so the tab write has to repaint the page.
    /// `settingsSelectedTab` is @AppStorage on the view model, which does not
    /// publish on its own — this is the test that keeps its `didSet` republish
    /// in place.
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
    /// intact around its `disablesAnimations` transaction — the guard that a
    /// reset landing while the panel opens can never animate a resize mid-open.
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

    // MARK: - Prayer row gutters

    /// Gap between a text box's leading edge and the first pixel of ink in it.
    private func leadingBearing(_ string: String, font: NSFont) -> CGFloat {
        inkBounds(string, font: font).minX
    }

    /// Gap between the last pixel of ink and the text box's trailing edge.
    private func trailingBearing(_ string: String, font: NSFont) -> CGFloat {
        let attributed = NSAttributedString(string: string, attributes: [.font: font])
        let line = CTLineCreateWithAttributedString(attributed)
        let advance = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        return advance - inkBounds(string, font: font).maxX
    }

    private func inkBounds(_ string: String, font: NSFont) -> CGRect {
        let attributed = NSAttributedString(string: string, attributes: [.font: font])
        let line = CTLineCreateWithAttributedString(attributed)
        return CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    }

    /// Both ends of a schedule row must sit on the panel's 12 pt gutter.
    ///
    /// 4.4.11 shipped two mistakes here, and this pins the constant half of both.
    /// The trailing inset is the panel's gutter again — *not*
    /// `rowHorizontalInset - columnSlack`, because the time column's reserved
    /// slack opens on the inner side of a `.trailing`-aligned frame and never
    /// reaches the outer edge. And it is applied as padding on the row content
    /// rather than as a trailing `Spacer().frame(width:)`: a spacer is an ordinary
    /// stack child, so it also collects the stack's 6 pt spacing, which is how a
    /// nominal 12 pt rendered as an 18.7 pt gutter and a nominal 8 pt as 14.7 pt.
    ///
    /// That second half — the spacing — is invisible to a constant like this one,
    /// so `build/gutter-verify.swift` renders the row shapes headlessly and
    /// measures the ink when the structure changes.
    func testPrayerRowTrailingGutterMatchesTheLeadingOne() {
        XCTAssertEqual(PrayerListView.rowTrailingInset, PrayerListView.rowHorizontalInset)
        XCTAssertEqual(PrayerListView.rowTrailingInset, 12)
    }

    /// The gutters have to *look* equal, not merely measure equal in the layout:
    /// a text box is wider than its ink, so each end carries its own side bearing
    /// — the gap between the box edge and the first/last pixel of ink. Digits and
    /// prayer names, in both scripts, differ by well under a point. Anything past
    /// that is a structural inset that has drifted again, not a font quirk.
    ///
    /// The tolerance is what keeps this useful rather than brittle: the worst
    /// pairing the panel can produce — a name opening on "F" (1.17 pt) against a
    /// clock ending on "٤" (0.46 pt) — is 0.7 pt, and the rendered row measures
    /// 0.5 pt. The 4.4.11 shape measured 1.5 pt and the shape before it 5.5 pt, so
    /// this catches the regression it is here for without failing on a font
    /// revision that moves a bearing by a tenth.
    func testPrayerRowInkGuttersAgreeWithinASideBearing() {
        // The row font, at the same size the layout measures its columns in: the
        // panel's body size at scale 1, bold for the clock because the next-prayer
        // row draws it bold.
        let size = PanelTextSize.baseBodyPointSize
        let nameFont = NSFont.systemFont(ofSize: size, weight: .regular)
        let timeFont = NSFont.systemFont(ofSize: size, weight: .bold)

        let names = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha", "Tahajud", "Dhuha",
                     "الفجر", "الظهر", "العصر", "المغرب", "العشاء", "تهجد", "الضحى"]
        let times = ["05:04", "12:17", "٠٥:٠٤", "١٢:١٧"]

        let leadingInk = names.map { leadingBearing($0, font: nameFont) }.max() ?? 0
        let trailingInk = times.map { trailingBearing($0, font: timeFont) }.max() ?? 0
        let leadingGutter = PrayerListView.rowHorizontalInset + leadingInk
        let trailingGutter = PrayerListView.rowTrailingInset + trailingInk

        XCTAssertEqual(leadingGutter, trailingGutter, accuracy: 1,
                       "ink gutters differ by \(abs(leadingGutter - trailingGutter)) pt")
    }

    /// The clock column reserves the sunnah estimate mark's slot only while
    /// sunnah rows can appear at all.
    ///
    /// The mark is a `.plusminus` hung off Tahajud's and Dhuha's clocks, and
    /// those rows only exist with "Show Sunnah Prayers" on. Reserved with the
    /// setting off, the slot is pure distance between the mute ring and its time
    /// on every row. Whichever way the setting is, the reservation is
    /// whole-column: the digits and the rings stay in one line because every row
    /// is handed the same width.
    ///
    /// Measured against a 24-hour formatter, the widest case that used to be
    /// hardcoded. The 12-hour case is covered by the two tests below — it is the
    /// one that used to overflow, and it must not be able to lean on this
    /// reservation to stay inside the column.
    func testTimeColumnReservesTheSunnahMarkSlotOnlyForSunnahRows() {
        let fontScale: CGFloat = 1
        let formatter = Self.formatter(dateFormat: "HH:mm", locale: "en_US")
        let digits = PrayerListView.timeColumnWidth(fontScale: fontScale, formatter: formatter)
        let mark = PrayerListView.sunnahMarkWidth(fontScale: fontScale)

        XCTAssertEqual(
            PrayerListView.timeColumnWidth(fontScale: fontScale, reservingSunnahMark: true, formatter: formatter),
            digits + mark
        )
        XCTAssertEqual(
            PrayerListView.timeColumnWidth(fontScale: fontScale, reservingSunnahMark: false, formatter: formatter),
            digits
        )
        // The gap this closes is the point of the gate, so it has to stay worth
        // closing: a symbol-only reservation that measured as a sliver would mean
        // the ring's distance comes from somewhere else.
        XCTAssertGreaterThan(mark, 12, "reserved mark slot is only \(mark)pt")
    }

    /// Every clock the formatter can emit has to fit its column, on the 12-hour
    /// path.
    ///
    /// This is the regression test for the mute ring sitting on top of the time.
    /// The column used to be measured from the literal "88:88", which is the
    /// widest case for a 24-hour clock only — and 12-hour is the *default*
    /// (`use24HourFormat` defaults to off), where the formatter appends a
    /// meridiem and renders "12:16 PM". That is ~14pt wider than the column, and
    /// since the digits are `.fixedSize` in a trailing-aligned frame they spilled
    /// leftwards into the 25pt mute toggle's cell.
    ///
    /// Asserted with sunnah rows *off*, because with them on the mark's reserved
    /// slot was absorbing the overflow by coincidence and hiding the bug.
    func testTimeColumnFitsTwelveHourClocksWithoutTheSunnahSlot() {
        let formatter = Self.formatter(dateFormat: nil, locale: "en_US") // timeStyle .short → "12:16 PM"
        let column = PrayerListView.timeColumnWidth(
            fontScale: 1, reservingSunnahMark: false, formatter: formatter
        )
        let font = NSFont.systemFont(ofSize: PanelTextSize.baseBodyPointSize, weight: .bold)

        for clock in Self.clocks(minute: 16, formatter: formatter) {
            let width = (clock as NSString).size(withAttributes: [.font: font]).width
            XCTAssertLessThanOrEqual(
                width, column,
                "\"\(clock)\" is \(width - column)pt wider than the \(column)pt column — it overflows into the mute toggle"
            )
        }
    }

    /// The same guarantee on the 24-hour path, so the fix is not just "make the
    /// column big enough for English 12-hour" and quietly leave Arabic-Indic
    /// digits or a wider meridiem outside it.
    func testTimeColumnFitsTwentyFourHourClocks() {
        let formatter = Self.formatter(dateFormat: "HH:mm", locale: "en_US")
        let column = PrayerListView.timeColumnWidth(
            fontScale: 1, reservingSunnahMark: false, formatter: formatter
        )
        let font = NSFont.systemFont(ofSize: PanelTextSize.baseBodyPointSize, weight: .bold)

        for clock in Self.clocks(minute: 59, formatter: formatter) {
            let width = (clock as NSString).size(withAttributes: [.font: font]).width
            XCTAssertLessThanOrEqual(width, column, "\"\(clock)\" does not fit the \(column)pt column")
        }
    }

    /// "Minimal Menu Bar" is a status-item preference, and it must not reach the
    /// panel's clocks.
    ///
    /// It used to. The meridiem was dropped by a branch inside `dateFormatter` —
    /// the single formatter behind the schedule rows, the countdown header, the
    /// Jumu'ah session line and the time-correction sheet — so turning the setting
    /// on turned "5:03 AM" into "5:03" across the whole panel. That is not what
    /// the setting says it does, and it drops the one thing that tells the
    /// morning prayer from the evening one.
    ///
    /// The two formatters are now separate, so the setting can only reach the
    /// status item: `menuBarDateFormatter` shortens, `dateFormatter` does not.
    func testMinimalMenuBarLeavesThePanelClocksAlone() {
        // Pinned, so the assertion cannot pass for the wrong reason: in a
        // 24-hour locale both formatters render "17:16" and the difference the
        // test is about would simply not exist.
        UserDefaults.standard.set("en", forKey: "selectedLanguage")
        let vm = PrayerTimeViewModel()
        defer {
            vm.useMinimalMenuBarText = false
            vm.use24HourFormat = false
            UserDefaults.standard.removeObject(forKey: "selectedLanguage")
        }

        vm.use24HourFormat = false
        vm.useMinimalMenuBarText = false

        // Afternoon, so a meridiem is actually there to lose.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = vm.displayTimeZone
        var components = DateComponents()
        components.year = 2024
        components.month = 6
        components.day = 15
        components.hour = 17
        components.minute = 16
        let afternoon = calendar.date(from: components)!

        let panelBefore = vm.dateFormatter.string(from: afternoon)
        let menuBarBefore = vm.menuBarDateFormatter.string(from: afternoon)

        vm.useMinimalMenuBarText = true

        let panelAfter = vm.dateFormatter.string(from: afternoon)
        let menuBarAfter = vm.menuBarDateFormatter.string(from: afternoon)

        XCTAssertEqual(panelBefore, panelAfter,
                       "Minimal Menu Bar changed the panel clock: \(panelBefore) -> \(panelAfter)")
        // And the setting still does the one thing it is for.
        XCTAssertNotEqual(menuBarBefore, menuBarAfter,
                          "Minimal Menu Bar no longer shortens the menu bar")
        XCTAssertLessThan(menuBarAfter.count, menuBarBefore.count,
                          "Minimal Menu Bar did not make the menu bar title shorter")
    }

    /// The red alert carries into the interactive glyphs.
    ///
    /// The mute rings and the location row's checkmark are drawn on the panel
    /// with the user's accent, and that accent is what the rest of the panel
    /// replaces while a prayer is imminent — Accent Panel tint, the next-prayer
    /// row, the countdown fill. The glyphs were the one surface left out, so a
    /// teal pick put teal rings and a teal checkmark on an otherwise red panel,
    /// which is the most jarring place for a colour to be out of step.
    ///
    /// Asserted against a saturated pick so it passes the #24 pale-colour
    /// fallback untouched — this test is about the alert, not about luminance.
    func testRedAlertCarriesIntoTheInteractiveGlyphAccent() {
        let vm = PrayerTimeViewModel()
        defer {
            vm.isPrayerImminent = false
            vm.useAccentColor = true
            vm.accentPanelTheme = false
            vm.customHighlightColorHex = ""
        }
        vm.useAccentColor = true
        vm.accentPanelTheme = false
        vm.customHighlightColorHex = "2AA198"

        vm.isPrayerImminent = false
        XCTAssertEqual(
            vm.legibleInteractiveAccent,
            PrayerTimeViewModel.controlTint(fromHighlightHex: "2AA198"),
            "calm glyphs should be the user's own pick"
        )
        XCTAssertEqual(
            vm.selectedHighlightColor,
            PrayerTimeViewModel.controlTint(fromHighlightHex: "2AA198"),
            "calm accents should be the user's own pick"
        )

        vm.isPrayerImminent = true
        XCTAssertEqual(
            vm.legibleInteractiveAccent,
            PrayerTimeViewModel.controlTint(fromHighlightHex: "FF4246"),
            "alert glyphs should be the alert colour, like every other surface"
        )
        // The source fix: this property is what the Settings tab pill, `.tint()`
        // and the search field's focus ring all read, so it has to carry the
        // alert too — fixing only the glyphs leaves those three behind.
        XCTAssertEqual(
            vm.selectedHighlightColor,
            PrayerTimeViewModel.controlTint(fromHighlightHex: "FF4246"),
            "alert accents (tab pill, tint, search ring) should be the alert colour"
        )
    }

    /// The switches, the time-preview arrow and the About page hold their own
    /// `@AppStorage` and never see a view model, so they resolve through
    /// `currentControlTint` and the mirrored `prayerImminentForTint` instead.
    /// Without that they kept the user's pick — which is what left the Settings
    /// switches teal on a red panel.
    func testCurrentControlTintFollowsTheAlertWithoutAViewModel() {
        let defaults = UserDefaults.standard
        let keys = ["prayerImminentForTint", "customHighlightColorHex", "useAccentColor", "accentPanelTheme"]
        let saved = keys.map { defaults.object(forKey: $0) }
        defer {
            for (index, key) in keys.enumerated() {
                if let previous = saved[index] {
                    defaults.set(previous, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }

        defaults.set("2AA198", forKey: "customHighlightColorHex")
        defaults.set(true, forKey: "useAccentColor")
        defaults.set(false, forKey: "accentPanelTheme")

        defaults.set(false, forKey: PrayerTimeViewModel.imminentDefaultsKey)
        XCTAssertEqual(
            PrayerTimeViewModel.currentControlTint,
            PrayerTimeViewModel.controlTint(fromHighlightHex: "2AA198"),
            "a calm switch should use the picked colour"
        )

        defaults.set(true, forKey: PrayerTimeViewModel.imminentDefaultsKey)
        XCTAssertEqual(
            PrayerTimeViewModel.currentControlTint,
            PrayerTimeViewModel.controlTint(fromHighlightHex: "FF4246"),
            "a switch should follow the red alert"
        )
    }

    /// …including the amber fallback when the user's pick is itself red-ish, so
    /// the glyphs stay legible instead of vanishing into the alert.
    func testInteractiveGlyphAccentUsesTheAmberFallbackForRedPicks() {
        let vm = PrayerTimeViewModel()
        defer {
            vm.isPrayerImminent = false
            vm.useAccentColor = true
            vm.accentPanelTheme = false
            vm.customHighlightColorHex = ""
        }
        vm.useAccentColor = true
        vm.accentPanelTheme = false
        vm.isPrayerImminent = true

        for red in ["FF3B30", "FF2D55"] {
            vm.customHighlightColorHex = red
            XCTAssertEqual(
                vm.legibleInteractiveAccent,
                PrayerTimeViewModel.controlTint(fromHighlightHex: "FFCC00"),
                "\(red) must fall back to amber, not sit inside the red alert"
            )
        }
    }

    /// A formatter shaped like `PrayerTimeViewModel.dateFormatter`: either a fixed
    /// `dateFormat`, or the locale's short time style with its meridiem.
    private static func formatter(dateFormat: String?, locale: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: locale)
        formatter.timeZone = TimeZone(identifier: "UTC")
        if let dateFormat {
            formatter.dateFormat = dateFormat
        } else {
            formatter.timeStyle = .short
        }
        return formatter
    }

    /// Every hour shape the formatter can emit, at one two-digit minute: one-digit
    /// hours either side of the 1/2-digit boundary, both meridiem labels, and the
    /// 24-hour extremes.
    private static func clocks(minute: Int, formatter: DateFormatter) -> [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = formatter.timeZone ?? TimeZone.current
        return [0, 1, 9, 10, 11, 12, 23].map { h in
            var components = DateComponents()
            components.year = 2024
            components.month = 1
            components.day = 1
            components.hour = h
            components.minute = minute
            return formatter.string(from: calendar.date(from: components) ?? Date())
        }
    }

    // MARK: - Location row spacing

    /// In the `.bottom` position the location row sits between two dividers, and
    /// the space above it has to read the same as the space below it.
    ///
    /// The two sides are assembled from different pieces — the upper divider's
    /// own gap above the row, against the page stack's spacing *plus* the footer
    /// divider's padding below it — so the two have to be checked against each
    /// other rather than by eye. They were not, once: a -5 pull left the row 3pt
    /// closer to the footer's line than to the one above it. This keeps the pull
    /// derived from those pieces, and pins the values they resolve to.
    ///
    /// These are the *layout* clearances, and `build/locrow-verify.swift` renders
    /// the block headlessly and measures them in the pixels (the row's box reads
    /// 6.00 / 6.00 pt and the -5 it replaced 6.00 / 3.00 pt). Text ink is not what
    /// is balanced here: a line of digits and capitals sits about 2pt high in its
    /// own line box whatever the layout does — the same in every row of the panel
    /// — and it moves with the caption's glyphs.
    func testLocationRowBottomPositionClearsBothDividersEqually() {
        let above = MainView.locationRowBottomTopGap
        // What stacks up under the row before the pull is applied.
        let stackedBelow = MainView.pageStackSpacing + MainView.footerDividerPadding
        let below = stackedBelow - MainView.locationRowBottomPull

        XCTAssertEqual(above, below, accuracy: 0.001,
                       "row clears \(above)pt above and \(below)pt below")
        XCTAssertEqual(MainView.locationRowBottomTopGap, 6)
        XCTAssertEqual(MainView.locationRowBottomPull, 2)

        // The pull comes out of the row's own 5pt padding, so it has to stay
        // smaller than it — past that the row's box would be dragged through the
        // footer divider. The row's padding is symmetric, which is what carries
        // the balance above from the box onto the text inside it.
        XCTAssertLessThan(MainView.locationRowBottomPull, 5)
    }

    // MARK: - Location source switch

    /// A recalculation may replace the panel's times, but it may never empty
    /// them first.
    ///
    /// `isPrayerDataAvailable` is `!todayTimes.isEmpty`, so an empty `todayTimes`
    /// takes the prayer rows, the countdown header and the location row out of
    /// the panel in one pass. That is what switching *into* automatic location
    /// used to do — clear the list, then apply the recalculation a runloop turn
    /// later — and it is why mosque → automatic and manual → automatic flickered
    /// (the panel collapsed to its header and grew back) while the paths into
    /// manual and mosque, which never cleared, stayed smooth. The switch no
    /// longer clears; this pins the recalculation itself, which is where such a
    /// clear would be reached for next.
    func testRecalculationNeverEmptiesTheShownTimes() {
        let vm = PrayerTimeViewModel()
        let upcoming = Date().addingTimeInterval(3600)
        vm.todayTimes = ["Fajr": upcoming]

        vm.updatePrayerTimes()

        XCTAssertFalse(
            vm.todayTimes.isEmpty,
            "recalculation cleared the panel's times instead of replacing them in place"
        )
        XCTAssertTrue(vm.isPrayerDataAvailable)
    }

    // MARK: - Localization

    /// Every localizable key exists in every language.
    ///
    /// English is the reference set, and it is the only place a gap is
    /// *invisible*: `NSLocalizedString` falls back to the key itself, so a key
    /// missing from `en.lproj` still renders correctly in English — and in no
    /// other language is there anything to see. "Location Row" was exactly that:
    /// present in all eight translations, absent in English, and up until #23
    /// nobody knew.
    ///
    /// The `.lproj` files are the only place the key set actually lives, and
    /// several of them carry more than one key per line, so this reads them as
    /// text rather than line by line.
    func testEveryLocalizedKeyExistsInEveryLanguage() throws {
        let stringsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // SajdaTests
            .deletingLastPathComponent()   // repository root
            .appendingPathComponent("Sajda")

        let english = try localizedKeys(in: stringsDirectory.appendingPathComponent("en.lproj/Localizable.strings"))
        XCTAssertFalse(english.isEmpty, "could not read the English strings file")

        for language in ["ar", "de", "es", "fr", "id", "ja", "ko", "zh-Hans"] {
            let translated = try localizedKeys(in: stringsDirectory.appendingPathComponent("\(language).lproj/Localizable.strings"))
            XCTAssertEqual(
                english.subtracting(translated), [],
                "\(language) is missing keys English defines"
            )
        }
    }

    /// The keys a `.strings` file defines, matched anywhere on a line.
    private func localizedKeys(in file: URL) throws -> Set<String> {
        let text = try String(contentsOf: file, encoding: .utf8)
        let regex = try NSRegularExpression(pattern: #"\"((?:[^\"\\]|\\.)*)\"\s*=\s*\""#)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return Set(regex.matches(in: text, range: range).compactMap { match in
            guard let keyRange = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[keyRange])
        })
    }

}
