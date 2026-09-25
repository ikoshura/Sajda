// MARK: - GANTI SELURUH FILE: Sajda/FluidMenuBar/FluidMenuBarExtraStatusItem.swift (PERBAIKAN FINAL ANIMASI & STATE)

import AppKit
import SwiftUI

public final class FluidMenuBarExtraStatusItem: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let statusItem: NSStatusItem
    private var localEventMonitor: EventMonitor?
    private var globalEventMonitor: EventMonitor?
    /// Token for the `NSWindow.didBecomeKeyNotification` observer that keeps
    /// app-owned auxiliary windows (system panels, the colour panel) above this
    /// status-bar-level panel.
    private var auxiliaryWindowObserver: NSObjectProtocol?
    public var button: NSStatusBarButton? { statusItem.button }
    /// Tracks whether we currently hold an "expanded interface session" on the
    /// status item (see `setSystemHighlight(_:)`), so begin and end stay balanced.
    private var isSystemHighlightActive = false
    /// True from the moment `dismissWindow()` starts its close animation until
    /// the window is ordered out, so re-entrant dismissal requests (session-end
    /// callback, key-loss + outside click racing each other) run at most once.
    private var isDismissing = false
    /// Set while `performEndExpandedSession()` runs, so the session-end callback
    /// AppKit sends for that handshake is not mistaken for an external end.
    private var isEndingExpandedSession = false
    /// Generation counter for the session-watch chain; bumped on start/stop so a
    /// tick scheduled before a fast close/reopen cannot spawn a second chain.
    private var sessionWatchGeneration = 0
    private var sessionWatchAbsentTicks = 0
    private var sessionWatchSeenSession = false
    
    /// Diagnostics for the open/close state machine. Enabled by setting
    /// `SAJDA_MENUBAR_DEBUG=1` in the environment; silent otherwise.
    private static let debugEnabled = ProcessInfo.processInfo.environment["SAJDA_MENUBAR_DEBUG"] != nil

    private func log(_ message: @autoclosure () -> String) {
        guard Self.debugEnabled else { return }
        let line = String(format: "[SajdaMenuBar %.3f] ", ProcessInfo.processInfo.systemUptime) + message() + "\n"
        FileHandle.standardError.write(Data(line.utf8))
    }

    /// Compact description of the panel state used by `log(_:)` call sites.
    private var stateDescription: String {
        "visible=\(window.isVisible) key=\(window.isKeyWindow) main=\(window.isMainWindow) "
            + "appActive=\(NSApp.isActive) frontmost=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil") "
            + "alpha=\(String(format: "%.2f", window.alphaValue)) session=\(hasExpandedInterfaceSession()) "
            + "btnHighlighted=\(statusItem.button?.isHighlighted ?? false)"
    }

    private init(window: NSWindow) {
        self.window = window
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.isVisible = true
        super.init()

        // AppKit reports every expanded-session end through this callback —
        // including ends it decides on its own, like the second click of a
        // force click (see `systemEndedExpandedSession()`).
        expandedInterfaceDelegate.sessionDidEnd = { [weak self] in
            self?.systemEndedExpandedSession()
        }

        localEventMonitor = LocalEventMonitor(mask: [.leftMouseDown]) { [weak self] event in
            guard let self else { return event }
            let isButtonClick = event.window == self.statusItem.button?.window
            if isButtonClick, !event.modifierFlags.contains(.command) {
                self.log("localMonitor: click on status item → didPress (before: \(self.stateDescription))")
                self.didPressStatusBarButton(self.statusItem.button!)
                return nil
            }
            if isButtonClick {
                self.log("localMonitor: click on status item ignored (command modifier)")
            }
            return event
        }
        
        globalEventMonitor = GlobalEventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self else { return }
            self.log("globalMonitor: outside click, keyWindow=\(self.window.isKeyWindow)")
            // A global monitor only sees events dispatched to *other* apps, so any
            // event here is a real click-away. The panel is closed whenever it is
            // on screen — not only while it happens to hold key focus — because
            // the colour panel (ColorPicker) can hold key while the popover is
            // still open.
            guard self.window.isVisible else { return }
            self.dismissWindow()
        }
        
        window.delegate = self

        // Panels a control inside the popover opens (open/save panels, the shared
        // colour panel) are ordinary app windows at a level *below* this
        // status-bar-level panel, so they would appear behind it and look like a
        // dead control. Raise them to the panel's own level as soon as they take
        // key, whatever took key away from the popover.
        auxiliaryWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  self.window.isVisible,
                  let keyWindow = notification.object as? NSWindow,
                  keyWindow !== self.window else { return }
            self.raiseAuxiliaryWindow(keyWindow)
        }

        localEventMonitor?.start()
        log("status item created: \(statusItem)")
    }

    deinit {
        if let auxiliaryWindowObserver { NotificationCenter.default.removeObserver(auxiliaryWindowObserver) }
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    /// Keeps an app-owned auxiliary window at the popover's window level, so it
    /// is never drawn behind it. Windows already above the popover are untouched.
    private func raiseAuxiliaryWindow(_ auxiliaryWindow: NSWindow) {
        guard auxiliaryWindow.level.rawValue < window.level.rawValue else { return }
        auxiliaryWindow.level = window.level
        log("auxiliary window \(type(of: auxiliaryWindow)) raised to level \(window.level.rawValue)")
    }

    /// True while another window of this app holds key focus — a system panel a
    /// control opened, or any app window opened from inside the popover. Such a
    /// window is not a click-away: only clicks dispatched to *other* apps close
    /// the popover, and those arrive through the global event monitor.
    private var isAuxiliaryAppWindowKey: Bool {
        guard let keyWindow = NSApp.keyWindow else { return false }
        return keyWindow !== window
    }

    // MARK: - Keyboard menu-bar focus (blue-outline navigation)

    /// Height of the menu bar strip (points) watched for keyboard focus.
    private static let keyboardFocusStripHeight: CGFloat = 28
    /// Horizontal slack around the status item while the keyboard pill moves.
    private static let keyboardFocusHorizontalMargin: CGFloat = 40
    /// How long focus must sit away from the item before the panel follows
    /// the pill and closes — long enough to survive one arrow-key hop.
    private static let keyboardFocusAwayDelay: TimeInterval = 0.45
    /// Poll cadence while the panel is open for focus-driven open/close.
    private static let keyboardFocusPollInterval: TimeInterval = 0.08
    /// Cancellable delayed close scheduled when focus leaves the item.
    private var keyboardFocusWorkItem: DispatchWorkItem?
    /// Last keyboard-focus open state, so the panel toggles exactly on edges.
    private var wasKeyboardMenuBarFocus = false
    /// Live "mouse is over my status item" state. `NSEvent.mouseLocation` is
    /// sampled from the same poll, so hover and keyboard focus can share one
    /// watcher instead of installing mouse-tracking areas on a status item.
    private var isMouseUserHover = false

    /// True while the pointer itself sits on this status item.
    private var isMouseUserHoveringNow: Bool {
        guard let button = statusItem.button,
              let window = button.window
        else { return false }
        let location = NSEvent.mouseLocation
        return window.convertToScreen(window.frame).contains(location)
    }

    /// True while the *keyboard* focus pill sits on this status item —
    /// priority over mouse hover for the whole session. This is Control-F2
    /// (Fn-Ctrl-F2) menu-bar navigation with arrows: the pill slides across
    /// the menu bar without the mouse ever moving. The pill itself is opaque
    /// to third parties (AppKit exposes no focus-pill API for menu extras),
    /// so this reads the only public edge available: the mouse is untouched
    /// while the pointer sits inside a small strip around this item. Mouse
    /// hover sets `isMouseUserHover` first in the same poll, so a parked
    /// cursor can never fake a keyboard session.
    private var isKeyboardMenuBarFocus: Bool {
        guard !isMouseUserHover else { return false }
        guard let button = statusItem.button,
              let window = button.window,
              let screen = window.screen ?? NSScreen.main
        else { return false }
        let location = NSEvent.mouseLocation
        let buttonFrame = window.convertToScreen(window.frame)
        let trackingFrame = CGRect(
            x: buttonFrame.minX - Self.keyboardFocusHorizontalMargin,
            y: screen.frame.maxY - Self.keyboardFocusStripHeight,
            width: buttonFrame.width + Self.keyboardFocusHorizontalMargin * 2,
            height: Self.keyboardFocusStripHeight
        )
        return trackingFrame.contains(location)
    }

    /// Starts the keyboard-focus watcher alongside the session watch, so the
    /// panel also opens on Ctrl-F2 + arrows, and closes again when the pill
    /// moves on — the Wi-Fi/battery behaviour.
    private func startKeyboardFocusWatch() {
        wasKeyboardMenuBarFocus = false
        scheduleKeyboardFocusWatch()
    }

    /// Stops the watcher and drops any pending focus-driven close.
    private func stopKeyboardFocusWatch() {
        keyboardFocusWorkItem?.cancel()
        keyboardFocusWorkItem = nil
        wasKeyboardMenuBarFocus = false
    }

    private func scheduleKeyboardFocusWatch() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.keyboardFocusPollInterval) { [weak self] in
            guard let self, self.window.isVisible else { return }
            self.keyboardFocusWatchTick()
            self.scheduleKeyboardFocusWatch()
        }
    }

    private func keyboardFocusWatchTick() {
        isMouseUserHover = isMouseUserHoveringNow
        let focused = isKeyboardMenuBarFocus
        guard focused != wasKeyboardMenuBarFocus else { return }
        wasKeyboardMenuBarFocus = focused
        if focused {
            // The pill arrived while the mouse never moved: this is a
            // keyboard session. Cancel a pending focus-away close and open
            // exactly like a click would.
            keyboardFocusWorkItem?.cancel()
            keyboardFocusWorkItem = nil
            if !window.isVisible {
                didPressStatusBarButton(statusItem.button!)
            }
        } else {
            // The pill moved on. Dismiss after a beat so one more arrow hop
            // can't flap the panel, then mirror the close path click-away
            // uses (ending a focus session dismisses like AppKit's panels).
            keyboardFocusWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.keyboardFocusWorkItem = nil
                guard self.window.isVisible else { return }
                self.dismissWindow()
            }
            keyboardFocusWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.keyboardFocusAwayDelay, execute: workItem)
        }
    }

    private func didPressStatusBarButton(_ sender: NSStatusBarButton) {
        log("didPress: \(stateDescription)")
        if window.isVisible {
            log("didPress: panel already visible → dismissWindow")
            dismissWindow()
            return
        }
        setWindowPosition()
        DistributedNotificationCenter.default().post(name: .beginMenuTracking, object: nil)
        window.makeKeyAndOrderFront(nil)
        log("didPress: after makeKeyAndOrderFront → \(stateDescription)")
        setSystemHighlight(true)
        startSessionWatch()
        startKeyboardFocusWatch()
    }
    
    public func windowDidBecomeKey(_ notification: Notification) {
        log("windowDidBecomeKey")
        NotificationCenter.default.post(name: .popoverDidOpen, object: nil)
        globalEventMonitor?.start()
    }
    
    public func windowDidResignKey(_ notification: Notification) {
        log("windowDidResignKey: \(stateDescription)")
        // Another window of this app can legitimately take key focus while the
        // popover stays open: the open/save panel behind "Browse…" for a custom
        // adhan sound, the shared colour panel, or any app window opened from
        // inside the popover. Dismissing here would kill that interaction — and
        // because those windows sit at a lower level they would also be drawn
        // behind the popover, looking like a dead control.
        if let keyWindow = NSApp.keyWindow, keyWindow !== window {
            raiseAuxiliaryWindow(keyWindow)
            log("windowDidResignKey: \(type(of: keyWindow)) took key → keeping popover open")
            return
        }
        if window.isVisible {
            dismissWindow()
        }
    }
        
    private func dismissWindow() {
        guard window.isVisible else {
            log("dismissWindow: ignored, window not visible")
            return
        }
        guard !isDismissing else {
            log("dismissWindow: ignored, dismissal already in progress")
            return
        }
        isDismissing = true
        stopSessionWatch()
        stopKeyboardFocusWatch()
        log("dismissWindow: begin → \(stateDescription)")

        globalEventMonitor?.stop()
        setSystemHighlight(false)
        DistributedNotificationCenter.default().post(name: .endMenuTracking, object: nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            // --- PERBAIKAN UTAMA DI SINI ---
            // Pindahkan notifikasi ke dalam completion handler.
            // Ini memastikan state di-reset HANYA SETELAH animasi selesai dan window hilang.
            guard let self else { return }
            self.log("dismissWindow: animation finished → \(self.stateDescription)")
            NotificationCenter.default.post(name: .popoverDidClose, object: nil)
            
            self.window.orderOut(nil)
            self.window.alphaValue = 1
            self.isDismissing = false
            self.log("dismissWindow: after orderOut → \(self.stateDescription)")
        }
    }

    // MARK: - Session ends we did not ask for

    /// AppKit retired the expanded-interface session on its own — the pill is
    /// drawn from the session, so it has already vanished, and the panel has to
    /// follow it in the same beat.
    ///
    /// This is the force-click case: the extra click a force click produces
    /// lands while the item holds the session, and AppKit closes the expanded
    /// interface exactly as it does for its own panels (Wi-Fi, battery). The
    /// panel is a separate window this class owns, so without this hook it
    /// outlives the pill.
    private func systemEndedExpandedSession() {
        guard !isEndingExpandedSession else {
            log("sessionDidEnd: own end handshake → ignored (\(stateDescription))")
            return
        }
        guard !hasExpandedInterfaceSession() else {
            // A session is active again (a fast toggle already replaced the one
            // that ended); the pill is on screen, so there is nothing to fix.
            log("sessionDidEnd: a session is active again → ignored (\(stateDescription))")
            return
        }
        guard window.isVisible, !isDismissing else {
            log("sessionDidEnd: panel not open or already dismissing → ignored")
            return
        }
        log("sessionDidEnd: session ended externally → dismissWindow (\(stateDescription))")
        dismissWindow()
    }

    // MARK: - Session watch (backstop for silent session ends)

    /// Starts watching the session behind the pill while the panel is open.
    /// `systemEndedExpandedSession()` handles the normal case instantly; this is
    /// the backstop for AppKit dropping the session without calling back.
    private func startSessionWatch() {
        sessionWatchGeneration += 1
        sessionWatchAbsentTicks = 0
        sessionWatchSeenSession = false
        scheduleSessionWatch(generation: sessionWatchGeneration)
    }

    private func stopSessionWatch() {
        sessionWatchGeneration += 1
        sessionWatchAbsentTicks = 0
        sessionWatchSeenSession = false
    }

    private func scheduleSessionWatch(generation: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.sessionWatchInterval) { [weak self] in
            guard let self, generation == self.sessionWatchGeneration else { return }
            self.sessionWatchTick()
        }
    }

    private func sessionWatchTick() {
        guard window.isVisible else {
            stopSessionWatch()
            return
        }
        if isAuxiliaryAppWindowKey {
            // A panel opened from inside the popover (open/save, colour) is up.
            // AppKit can drop the expanded-interface session while the user is
            // still interacting with it, which must not tear the popover down.
            sessionWatchSeenSession = true
            scheduleSessionWatch(generation: sessionWatchGeneration)
            return
        }
        if hasExpandedInterfaceSession() {
            sessionWatchSeenSession = true
            sessionWatchAbsentTicks = 0
        } else if sessionWatchSeenSession {
            // Absence only counts once a session has actually been granted this
            // open: on systems without the SPI there is no session at all, and
            // right after a fast reopen the new grant is still in flight — a
            // transient gap must not look like the pill vanishing.
            sessionWatchAbsentTicks += 1
            if sessionWatchAbsentTicks >= Self.sessionWatchMissLimit {
                log("sessionWatch: session gone while panel open → dismissWindow (\(stateDescription))")
                dismissWindow()
                return
            }
        }
        scheduleSessionWatch(generation: sessionWatchGeneration)
    }

    private func setWindowPosition() {
        guard let statusItemWindow = statusItem.button?.window else { window.center(); return }
        var targetRect = statusItemWindow.frame
        if let screen = statusItemWindow.screen {
            let windowWidth = window.frame.width
            if statusItemWindow.frame.origin.x + windowWidth > screen.visibleFrame.width {
                targetRect.origin.x += statusItemWindow.frame.width
                targetRect.origin.x -= windowWidth
                targetRect.origin.x += Metrics.windowBorderSize
            } else {
                targetRect.origin.x -= Metrics.windowBorderSize
            }
        } else {
            targetRect.origin.x -= Metrics.windowBorderSize
        }
        window.setFrameTopLeftPoint(targetRect.origin)
    }
    
    public func updateTitle(to newTitle: NSAttributedString) {
        statusItem.button?.attributedTitle = newTitle
    }

    // MARK: - System highlight pill

    /// macOS 27 draws the real status-bar highlight pill — the same one Wi-Fi,
    /// battery or Control Center show while their panels are open — only for
    /// status items that hold an "expanded interface session" and report the
    /// frame of the content that session belongs to.
    ///
    /// SwiftUI's `MenuBarExtra` (`.window` style) gets this for free because it
    /// performs that handshake on the status item AppKit gives it. A hand-rolled
    /// status item never does, which is exactly why `cell.isHighlighted`,
    /// `NSControl.highlight(_:)`, `drawStatusBarBackgroundInRect:withHighlight:`
    /// and app activation all fail to reproduce the pill: they toggle state but
    /// nothing ever tells the system to draw the highlight.
    ///
    /// So we run the same handshake ourselves. The sequence below was captured
    /// live from a running `MenuBarExtra` app, and one extra requirement was found
    /// by experiment: the item must have an `expandedInterfaceDelegate` that
    /// answers the two session callbacks, otherwise the session never completes
    /// and the pill can be turned on but never turned off. A second finding works
    /// the other way: that delegate has to be handed back as soon as the session
    /// ends, because while an item holds one AppKit keeps it in session mode and
    /// swallows every later click on the item — the panel then opens exactly once
    /// and never again (see `restoreExpandedInterfaceDelegate()`).
    ///
    ///     open : _requestExpandedInterfaceSession
    ///            _beginExpandedInterfaceSession: (session start time)
    ///            _setSelectedContentFrame:options: (empty rect, option 1)
    ///     close: _endExpandedInterfaceSession:animate: ×3 (NO, YES)
    ///            _setSelectedContentFrame:options: ×5 (empty rect, option 1)
    ///
    /// An empty rect is what SwiftUI sends — AppKit derives the pill geometry
    /// from the status item's own window, so there is nothing to measure here.
    /// Every call is guarded, so on macOS versions without this SPI the item
    /// simply shows no pill and nothing else changes.
    private enum SystemHighlightSelector {
        static let requestExpandedSession = NSSelectorFromString("_requestExpandedInterfaceSession")
        static let beginExpandedSession = NSSelectorFromString("_beginExpandedInterfaceSession:")
        static let endExpandedSession = NSSelectorFromString("_endExpandedInterfaceSession:animate:")
        static let setSelectedContentFrame = NSSelectorFromString("_setSelectedContentFrame:options:")
        static let setExpandedInterfaceDelegate = NSSelectorFromString("setExpandedInterfaceDelegate:")
        static let expandedInterfaceSessionName = "expandedInterfaceSession"
        static let expandedInterfaceSession = NSSelectorFromString(expandedInterfaceSessionName)
        static let expandedInterfaceDelegateName = "expandedInterfaceDelegate"
    }

    /// How long after a close the session state keeps being sampled, and how
    /// often: 20 × 0.15 s ≈ 3 s of grace for asynchronous grants to land.
    private static let maximumSessionEndAttempts = 20
    private static let sessionEndRetryDelay: TimeInterval = 0.15
    /// How often the open panel re-checks the session behind the pill, and how
    /// many consecutive misses before treating it as gone: 3 × 0.25 s = 0.75 s —
    /// comfortably longer than an asynchronous session grant, so a late grant
    /// can never look like the pill vanishing, but short enough to feel instant.
    private static let sessionWatchInterval: TimeInterval = 0.25
    private static let sessionWatchMissLimit = 3

    private typealias RequestExpandedSession = @convention(c) (AnyObject, Selector) -> Void
    private typealias BeginExpandedSession = @convention(c) (AnyObject, Selector, Double) -> Void
    private typealias EndExpandedSession = @convention(c) (AnyObject, Selector, Bool, Bool) -> Void
    private typealias SetSelectedContentFrame = @convention(c) (AnyObject, Selector, NSRect, Int) -> Void

    /// Session callback target. AppKit drives the expanded-interface session
    /// through these two delegate methods, so they have to exist even though the
    /// panel itself is fully managed by this class.
    ///
    /// The end callback doubles as the notification that AppKit retired the
    /// session by itself — e.g. the extra click of a force click lands while the
    /// item holds the session, and AppKit closes the expanded interface the way
    /// it does for Wi-Fi and battery. The pill is drawn from the session, so it
    /// vanishes with it; `sessionDidEnd` lets the owning status item close the
    /// panel in the same beat (see `systemEndedExpandedSession()`).
    @objcMembers
    private final class ExpandedInterfaceDelegate: NSObject {
        /// Called for every session end AppKit reports, including ones we did
        /// not request; the receiver filters out its own (via
        /// `isEndingExpandedSession`).
        var sessionDidEnd: (() -> Void)?

        func statusItem(_ statusItem: NSStatusItem, didBeginExpandedInterfaceSession session: AnyObject) {}
        func statusItemDidEndExpandedInterfaceSession(_ statusItem: NSStatusItem, animated: Bool) {
            sessionDidEnd?()
        }
    }

    private let expandedInterfaceDelegate = ExpandedInterfaceDelegate()
    /// The delegate the status item had before we claimed it, so it can be handed
    /// back once our session is over. AppKit treats an item that has an expanded
    /// interface delegate differently from a plain one, so holding on to it longer
    /// than the session needs changes how the item behaves.
    private var previousExpandedInterfaceDelegate: AnyObject?
    private var didInstallExpandedInterfaceDelegate = false

    /// Claims the two session callbacks so the begin/end handshake can complete.
    /// Called on open; paired with `restoreExpandedInterfaceDelegate()` on close.
    private func installExpandedInterfaceDelegateIfNeeded() {
        guard !didInstallExpandedInterfaceDelegate else { return }
        previousExpandedInterfaceDelegate = currentExpandedInterfaceDelegate()

        let item = statusItem as AnyObject
        guard item.responds(to: SystemHighlightSelector.setExpandedInterfaceDelegate),
              let implementation = item.method(for: SystemHighlightSelector.setExpandedInterfaceDelegate) else {
            return
        }
        typealias SetDelegate = @convention(c) (AnyObject, Selector, AnyObject?) -> Void
        let setDelegate = unsafeBitCast(implementation, to: SetDelegate.self)
        setDelegate(item, SystemHighlightSelector.setExpandedInterfaceDelegate, expandedInterfaceDelegate)
        didInstallExpandedInterfaceDelegate = true
        log("installed expandedInterfaceDelegate (previous=\(String(describing: previousExpandedInterfaceDelegate)))")
    }

    /// Hands the status item back to whatever delegate it had before us — normally
    /// `nil`, which restores the item's ordinary behaviour.
    private func restoreExpandedInterfaceDelegate() {
        guard didInstallExpandedInterfaceDelegate else { return }

        let item = statusItem as AnyObject
        guard item.responds(to: SystemHighlightSelector.setExpandedInterfaceDelegate),
              let implementation = item.method(for: SystemHighlightSelector.setExpandedInterfaceDelegate) else {
            return
        }
        typealias SetDelegate = @convention(c) (AnyObject, Selector, AnyObject?) -> Void
        let setDelegate = unsafeBitCast(implementation, to: SetDelegate.self)
        setDelegate(item, SystemHighlightSelector.setExpandedInterfaceDelegate, previousExpandedInterfaceDelegate)
        didInstallExpandedInterfaceDelegate = false
        log("restored expandedInterfaceDelegate (now=\(String(describing: currentExpandedInterfaceDelegate())))")
    }

    private func currentExpandedInterfaceDelegate() -> AnyObject? {
        let item = statusItem as AnyObject
        let getter = NSSelectorFromString("expandedInterfaceDelegate")
        guard item.responds(to: getter) else { return nil }
        return item.perform(getter)?.takeUnretainedValue()
    }

    private func setSystemHighlight(_ highlighted: Bool) {
        log("setSystemHighlight(\(highlighted)) active=\(isSystemHighlightActive) session=\(hasExpandedInterfaceSession())")

        if highlighted {
            // The delegate is claimed for the lifetime of the session and handed
            // back in `scheduleSessionCleanup(attempt:)` as soon as the session is
            // over. Holding it after that puts the item into session mode, where
            // AppKit swallows every later click on it instead of delivering it —
            // the panel would then open exactly once and never again.
            installExpandedInterfaceDelegateIfNeeded()
            guard !isSystemHighlightActive else { return }
            isSystemHighlightActive = true

            let item = statusItem as AnyObject
            guard item.responds(to: SystemHighlightSelector.beginExpandedSession),
                  let implementation = item.method(for: SystemHighlightSelector.beginExpandedSession) else {
                return
            }
            // A session left over from a very fast open/close pair is retired
            // before claiming a new one, so sessions never stack up.
            if hasExpandedInterfaceSession() {
                performEndExpandedSession()
            }
            if item.responds(to: SystemHighlightSelector.requestExpandedSession),
               let requestImplementation = item.method(for: SystemHighlightSelector.requestExpandedSession) {
                let request = unsafeBitCast(requestImplementation, to: RequestExpandedSession.self)
                request(item, SystemHighlightSelector.requestExpandedSession)
            }
            let begin = unsafeBitCast(implementation, to: BeginExpandedSession.self)
            begin(item, SystemHighlightSelector.beginExpandedSession, ProcessInfo.processInfo.systemUptime)
            reportSelectedContentFrame(for: item)
            return
        }

        guard isSystemHighlightActive else {
            // No session of ours should be open at this point, but retire one if
            // a grant outlived the panel anyway.
            if hasExpandedInterfaceSession() {
                scheduleSessionCleanup(attempt: 0)
            }
            return
        }
        isSystemHighlightActive = false
        scheduleSessionCleanup(attempt: 0)
    }

    /// Ends the session, then keeps sampling for a fixed grace window so a late
    /// grant can never leave the pill stuck.
    ///
    /// Requesting a session is asynchronous: when the panel is toggled quickly the
    /// system can grant the session *after* our end call, or hand out a second one.
    /// A grant can also land in a gap where the session already reads clear, which
    /// is why cleanup does not stop at the first clear reading — it samples for the
    /// whole window and retires anything that shows up. Each round that finds a
    /// session claims the delegate, runs the end handshake and immediately hands
    /// the delegate back, so clicks keep flowing between rounds.
    private func scheduleSessionCleanup(attempt: Int) {
        guard !isSystemHighlightActive else {
            // The panel was reopened while cleanup was still running; the session
            // is wanted again, so this older cleanup pass stops touching it.
            return
        }

        if hasExpandedInterfaceSession() {
            installExpandedInterfaceDelegateIfNeeded()
            performEndExpandedSession()
        }
        // Hand the delegate back even when the session reads clear. An external
        // end (the force click) retires the session before this round runs, and
        // a delegate claimed over an empty session is exactly the state in which
        // AppKit swallows clicks instead of delivering them — the item then eats
        // every click until the delegate is finally handed back at the end of
        // the grace window (see `restoreExpandedInterfaceDelegate()`). Rounds
        // that catch a late grant above re-claim it themselves before ending it.
        restoreExpandedInterfaceDelegate()
        log("sessionCleanup attempt \(attempt) → session=\(hasExpandedInterfaceSession()) "
            + "delegateHeld=\(statusItem.value(forKey: SystemHighlightSelector.expandedInterfaceDelegateName) != nil) "
            + "btnHighlighted=\(statusItem.button?.isHighlighted ?? false)")

        guard attempt < Self.maximumSessionEndAttempts else {
            restoreExpandedInterfaceDelegate()
            log("sessionCleanup: finished after \(attempt) checks → session=\(hasExpandedInterfaceSession())")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.sessionEndRetryDelay) { [weak self] in
            self?.scheduleSessionCleanup(attempt: attempt + 1)
        }
    }

    /// The end/frame sequence AppKit needs to retire the pill, exactly as SwiftUI
    /// emits it: three end calls with the selected-content frame reported
    /// interleaved between them, then four more frame reports.
    private func performEndExpandedSession() {
        // AppKit may report this end back through the delegate; mark it as ours
        // so `systemEndedExpandedSession()` does not close a panel we just
        // reopened over a leftover session. Cleared on the next runloop turn
        // because the callback is allowed to arrive asynchronously.
        isEndingExpandedSession = true
        DispatchQueue.main.async { [weak self] in
            self?.isEndingExpandedSession = false
        }

        let item = statusItem as AnyObject

        if item.responds(to: SystemHighlightSelector.endExpandedSession),
           let implementation = item.method(for: SystemHighlightSelector.endExpandedSession) {
            let end = unsafeBitCast(implementation, to: EndExpandedSession.self)
            end(item, SystemHighlightSelector.endExpandedSession, false, true)
            end(item, SystemHighlightSelector.endExpandedSession, false, true)
            reportSelectedContentFrame(for: item)
            end(item, SystemHighlightSelector.endExpandedSession, false, true)
        }
        for _ in 0..<4 { reportSelectedContentFrame(for: item) }
    }

    private func hasExpandedInterfaceSession() -> Bool {
        let item = statusItem as AnyObject
        guard item.responds(to: SystemHighlightSelector.expandedInterfaceSession) else { return false }
        return item.value(forKey: SystemHighlightSelector.expandedInterfaceSessionName) != nil
    }

    private func reportSelectedContentFrame(for item: AnyObject) {
        guard item.responds(to: SystemHighlightSelector.setSelectedContentFrame),
              let implementation = item.method(for: SystemHighlightSelector.setSelectedContentFrame) else {
            return
        }
        let setFrame = unsafeBitCast(implementation, to: SetSelectedContentFrame.self)
        setFrame(item, SystemHighlightSelector.setSelectedContentFrame, .zero, 1)
    }

    // Convenience initializers
    convenience init(title: String, window: NSWindow) {
        self.init(window: window)
        statusItem.button?.title = title
        statusItem.button?.setAccessibilityTitle(title)
    }
    convenience init(title: String, image: String, window: NSWindow) {
        self.init(window: window)
        statusItem.button?.setAccessibilityTitle(title)
        statusItem.button?.image = NSImage(named: image)
    }
    convenience init(title: String, systemImage: String, window: NSWindow) {
        self.init(window: window)
        statusItem.button?.setAccessibilityTitle(title)
        statusItem.button?.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: title)
    }
}

private extension Notification.Name {
    static let beginMenuTracking = Notification.Name("com.apple.HIToolbox.beginMenuTrackingNotification")
    static let endMenuTracking = Notification.Name("com.apple.HIToolbox.endMenuTrackingNotification")
}

private enum Metrics { static let windowBorderSize: CGFloat = 2 }
