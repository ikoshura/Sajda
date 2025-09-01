// MARK: - GANTI SELURUH FILE: Sajda/FluidMenuBar/FluidMenuBarExtraStatusItem.swift (PERBAIKAN FINAL ANIMASI & STATE)

import AppKit
import SwiftUI

public final class FluidMenuBarExtraStatusItem: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let statusItem: NSStatusItem
    private var localEventMonitor: EventMonitor?
    private var globalEventMonitor: EventMonitor?
    public var button: NSStatusBarButton? { statusItem.button }
    
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
        
        globalEventMonitor = GlobalEventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let window = self?.window, window.isKeyWindow {
                self?.dismissWindow()
            }
        }
        
        window.delegate = self
        localEventMonitor?.start()
    }

    deinit { NSStatusBar.system.removeStatusItem(statusItem) }
    
    private func didPressStatusBarButton(_ sender: NSStatusBarButton) {
        if window.isVisible {
            dismissWindow()
            return
        }
        setWindowPosition()
        DistributedNotificationCenter.default().post(name: .beginMenuTracking, object: nil)
        window.makeKeyAndOrderFront(nil)
    }
    
    public func windowDidBecomeKey(_ notification: Notification) {
        NotificationCenter.default.post(name: .popoverDidOpen, object: nil)
        globalEventMonitor?.start()
        setButtonHighlighted(to: true)
    }
    
    public func windowDidResignKey(_ notification: Notification) {
        if window.isVisible {
            dismissWindow()
        }
    }
        
    private func dismissWindow() {
        guard window.isVisible else { return }

        globalEventMonitor?.stop()
        DistributedNotificationCenter.default().post(name: .endMenuTracking, object: nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            // --- PERBAIKAN UTAMA DI SINI ---
            // Pindahkan notifikasi ke dalam completion handler.
            // Ini memastikan state di-reset HANYA SETELAH animasi selesai dan window hilang.
            NotificationCenter.default.post(name: .popoverDidClose, object: nil)
            
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
    
    public func updateTitle(to newTitle: NSAttributedString) {
        statusItem.button?.attributedTitle = newTitle
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
