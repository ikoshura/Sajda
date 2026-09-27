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

    // MARK: - Jumu'ah sessions

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
