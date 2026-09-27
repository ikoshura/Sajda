// MARK: - Sajda/StatusItemContextMenu.swift
//
// Right-click menu for the menu bar item: **Quit Sajda**, and nothing else.
//
// SwiftUI's `MenuBarExtra` has no API for a status item's context menu, and the
// `FluidMenuBar` stack that used to own one is dead code (the app runs on the
// native `MenuBarExtra` scene — see `SajdaApp.swift`). So this is a plain
// `NSMenu`, popped up by a right-click monitor on the real `NSStatusItem` that
// `MenuBarExtraAccess` hands over through its `statusItem:` closure.
//
// Deliberately NOT `statusItem.button.menu`: an `NSStatusBarButton` with a menu
// set routes left-clicks to that menu too, which would replace the panel with
// this menu. A right-click monitor leaves the left-click path untouched.
//
// Deliberately Quit-only, after trying and rejecting three ways to offer more:
// "About"/"Check for Updates" need to open the panel programmatically, and
// every route to that was either broken or worse than the feature was worth:
//
//   - Flipping the `isMenuPresented` binding opens the panel, but the menu bar's
//     pill highlight is drawn by the system for an AppKit expanded interface
//     session, which a binding change does not start — so the item stays
//     un-highlighted and the next left-click closes the panel and reopens it.
//   - `statusItem.button.performClick` and the package's `togglePresented()` are
//     both no-ops on macOS 27+, where the button's target/action are nil and
//     presentation runs through the expanded interface session machinery.
//   - Synthesising a real left-click (CGEvent on the HID tap) *does* work, pill
//     and all, but macOS then asks for Accessibility permission for the app.
//     Requiring a permission prompt to reach the About page is a bad trade, so
//     it was dropped. (Its side effect — `pendingPanelPage`, and the menu's
//     consumption of it — is gone with it.)
//
// Everything those pages offer is already reachable from the panel's own
// one-line footer, so Quit is the only thing that genuinely needs a path that
// does not open it.

import AppKit

@MainActor
final class StatusItemContextMenu: NSObject {
    /// Right-click monitor. Scoped to clicks on *this* status item, so a
    /// right-click anywhere else in the system is untouched.
    private var monitor: Any?

    override init() {
        super.init()
    }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
    }

    /// Installs the right-click handler on `statusItem`. Safe to call more than
    /// once (`MenuBarExtraAccess` re-introspects on scene rebuilds): the
    /// previous monitor is always removed first, so handlers cannot stack up
    /// and pop several menus for one click.
    func install(on statusItem: NSStatusItem) {
        uninstall()
        guard let button = statusItem.button else { return }
        let window = button.window
        monitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
            guard let self, event.window === window else { return event }
            // Consume the click: AppKit's own status-item handling would
            // otherwise do something with it (and the panel would not open,
            // since this is a right-click).
            self.popUp(relativeTo: button)
            return nil
        }
    }

    func uninstall() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    /// Shows the menu under the status item, the same place AppKit anchors a
    /// status item menu of its own.
    private func popUp(relativeTo button: NSStatusBarButton) {
        makeMenu().popUp(positioning: nil, at: NSPoint(x: 0, y: 0), in: button)
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let quit = menu.addItem(
            withTitle: NSLocalizedString("Quit Sajda", comment: "Status item context menu"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        // `terminate:` lives on NSApplication, so this needs an explicit
        // target: left to the responder chain it would resolve against the
        // status item and find nothing.
        quit.target = NSApp
        return menu
    }
}
