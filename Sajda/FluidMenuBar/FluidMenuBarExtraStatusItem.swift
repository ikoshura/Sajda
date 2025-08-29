// Salin dan tempel SELURUH kode ini ke dalam file FluidMenuBar/FluidMenuBarExtraStatusItem.swift
import AppKit
import SwiftUI

final class FluidMenuBarExtraStatusItem: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let statusItem: NSStatusItem
    private var localEventMonitor: EventMonitor?
    private var globalEventMonitor: EventMonitor?
    private init(window: NSWindow) {
        self.window = window
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.isVisible = true
        super.init()
        localEventMonitor = LocalEventMonitor(mask: [.leftMouseDown]) { [weak self] event in
            if let button = self?.statusItem.button, event.window == button.window, !event.modifierFlags.contains(.command) {
                self?.didPressStatusBarButton(button)
                return nil
            }
            return event
        }
        globalEventMonitor = GlobalEventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let window = self?.window, window.isKeyWindow {
                window.resignKey()
            }
        }
        window.delegate = self
        localEventMonitor?.start()
    }
    deinit { NSStatusBar.system.removeStatusItem(statusItem) }
    private func didPressStatusBarButton(_ sender: NSStatusBarButton) {
        if window.isVisible { dismissWindow(); return }
        setWindowPosition()
        DistributedNotificationCenter.default().post(name: .beginMenuTracking, object: nil)
        window.makeKeyAndOrderFront(nil)
    }
    func windowDidBecomeKey(_ notification: Notification) { globalEventMonitor?.start(); setButtonHighlighted(to: true) }
    func windowDidResignKey(_ notification: Notification) {
            // TAMBAHKAN BARIS INI UNTUK MENYIARKAN NOTIFIKASI
            NotificationCenter.default.post(name: .popoverDidClose, object: nil)
            
            globalEventMonitor?.stop()
            dismissWindow()
        }
    private func dismissWindow() {
        DistributedNotificationCenter.default().post(name: .endMenuTracking, object: nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.window.orderOut(nil)
            self?.window.alphaValue = 1
            self?.setButtonHighlighted(to: false)
        }
    }
    private func setButtonHighlighted(to highlight: Bool) { statusItem.button?.highlight(highlight) }
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
    public func updateTitle(to newTitle: String) {
        statusItem.button?.title = newTitle
    }
}
extension FluidMenuBarExtraStatusItem {
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
