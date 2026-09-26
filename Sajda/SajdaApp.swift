// MARK: - Sajda/SajdaMenuBarApp.swift
//
// SwiftUI entry point for the Control Center revamp.
//
// - The menu bar UI is a native SwiftUI `MenuBarExtra` (style `.window`) whose
//   content is `SajdaControlCenterMenu` — a `MacControlCenterMenu` builder that
//   mimics the look, feel, and resize animations of macOS Control Center menus.
// - `AppDelegate` is kept as an `NSApplicationDelegate` adaptor for lifecycle
//   work that must stay in AppKit: prayer engine startup, notifications,
//   onboarding window, wake-from-sleep, and the right-click context menu.
// - The menu bar label (icon + text) is driven by `PrayerTimeViewModel.menuTitle`
//   via `SajdaMenuBarLabel`, so countdown / exact-time / icon modes keep working.

import SwiftUI
import NavigationStack
import MacControlCenterUI

@main
struct SajdaMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var isMenuPresented = false

    var body: some Scene {
        MenuBarExtra {
            SajdaControlCenterMenu(isMenuPresented: $isMenuPresented)
                .environmentObject(appDelegate.vm)
                .environmentObject(appDelegate.languageManager)
                .environmentObject(appDelegate.navigationModel)
                .onReceive(NotificationCenter.default.publisher(for: .popoverDidClose)) { _ in
                    if appDelegate.navigationModel.hasAlternativeViewShowing {
                        appDelegate.navigationModel.hideView(ContentView.id, animation: nil)
                    }
                    if !appDelegate.vm.settingsTabLocked {
                        appDelegate.vm.settingsSelectedTab = "display"
                    }
                }
        } label: {
            SajdaMenuBarLabel()
                .environmentObject(appDelegate.vm)
                .environmentObject(appDelegate.languageManager)
        }
        .menuBarExtraAccess(isPresented: $isMenuPresented)
        .menuBarExtraStyle(.window)
    }
}

/// Menu bar label (status item button content) driven by the prayer view model.
///
/// `menuTitle` is an `NSAttributedString` (red while prayer is imminent, with
/// optional larger/bold accessibility styling). The icon mirrors the previous
/// AppKit behavior: a template mosque glyph normally, a red-tinted copy while
/// imminent, hidden in text-only modes, mirrored trailing in RTL (Arabic).
struct SajdaMenuBarLabel: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    @EnvironmentObject var languageManager: LanguageManager

    var body: some View {
        HStack(spacing: 4) {
            // While the red alert is on, icon + text are drawn into a single
            // non-template image. `MenuBarExtra` renders the label text in the
            // status bar's own colour (ignoring both the AppKit
            // `.foregroundColor` attribute and SwiftUI `.foregroundColor`), and
            // a second `Image` in the label does not even get measured — so the
            // red has to be baked into one image that also carries the width.
            if let alert = imminentLabelImage {
                Image(nsImage: alert)
            } else if vm.menuBarLargerText || vm.accessibilityBoldText {
                // Accessibility path: bake into image(s) because the status
                // bar ignores `.font` on `Text`. Icon + text must be ONE
                // image — a second `Image` in the label is not measured and
                // the text vanishes (same reason the red alert is one image).
                if showsIcon, showsText, !vm.menuTitle.string.isEmpty {
                    if let img = Self.combinedLabelImage(
                        title: vm.menuTitle,
                        larger: vm.menuBarLargerText,
                        bold: vm.accessibilityBoldText,
                        iconSize: iconPointSize
                    ) {
                        Image(nsImage: img)
                    }
                } else {
                    if showsIcon {
                        Image(nsImage: menuBarIcon)
                    }
                    if showsText, !vm.menuTitle.string.isEmpty {
                        if let img = Self.textLabelImage(
                            title: vm.menuTitle,
                            larger: vm.menuBarLargerText,
                            bold: vm.accessibilityBoldText
                        ) {
                            Image(nsImage: img)
                        }
                    }
                }
            } else {
                if showsIcon {
                    Image(nsImage: menuBarIcon)
                }
                if showsText, !vm.menuTitle.string.isEmpty {
                    if useImageLabel, let img = Self.textLabelImage(
                        title: vm.menuTitle,
                        larger: vm.menuBarLargerText,
                        bold: vm.accessibilityBoldText
                    ) {
                        Image(nsImage: img)
                    } else if !useImageLabel {
                        Text(AttributedString(vm.menuTitle))
                    }
                }
            }
        }
    }

    /// Composite icon + red title for the imminent (red alert) state, or `nil`
    /// when the normal icon/text pair should be used instead.
    /// Image labels render slightly smaller than the system status-bar font,
    /// so the image path is only used when the accessibility options (or
    /// the red alert) actually need it.
    private var useImageLabel: Bool { false }

    private var imminentLabelImage: NSImage? {
        guard vm.isPrayerImminent, showsText, !vm.menuTitle.string.isEmpty else { return nil }
        return SajdaMenuBarLabel.imminentLabelImage(
            title: vm.menuTitle,
            iconSize: showsIcon ? iconPointSize : 0
        )
    }

    /// Whether the mosque glyph shows in the current menu bar text mode.
    private var showsIcon: Bool {
        switch vm.menuBarTextMode {
        case .hidden, .iconCountdown, .iconExactTime: return true
        case .countdown, .exactTime: return false
        }
    }

    /// Whether the countdown / exact-time text shows in the current mode.
    private var showsText: Bool {
        switch vm.menuBarTextMode {
        case .hidden: return false
        case .countdown, .iconCountdown, .exactTime, .iconExactTime: return true
        }
    }

    /// Renders plain (non-red) text into an image so the accessibility
    /// size/weight is honored. `MenuBarExtra` draws `Text` labels with the
    /// status-bar font no matter what `.font` we set, so the `.font`
    /// modifier alone cannot grow the text — baking the `+3pt`/bold into an
    /// image is the only path that visibly enlarges it.
    private static func textLabelImage(title: NSAttributedString, larger: Bool, bold: Bool, red: Bool = false) -> NSImage? {
        let attributed = NSMutableAttributedString(attributedString: title)
        let range = NSRange(location: 0, length: attributed.length)
        guard range.length > 0 else { return nil }
        let size: CGFloat = NSFont.systemFontSize + (larger ? 3 : 0)
        // Redraw at device pixels so the image stays sharp next to the
        // system-drawn label (which renders at backing-store scale).
        let scale: CGFloat = NSScreen.main?.backingScaleFactor ?? 2
        let font = NSFont.systemFont(ofSize: size * scale, weight: bold ? .bold : .regular)
        attributed.addAttribute(.font, value: font, range: range)
        attributed.addAttribute(.foregroundColor, value: red ? NSColor.systemRed : NSColor.black, range: range)
        let textSize = attributed.size()
        // Downscale back to points; keep template so the status bar tints
        // it like a normal text label (light/dark + click highlight).
        let imageSize = NSSize(width: ceil(textSize.width / scale) + 1, height: ceil(textSize.height / scale))
        let image = NSImage(size: imageSize)
        image.lockFocus()
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.cgContext.scaleBy(x: 1 / scale, y: 1 / scale)
        attributed.draw(at: NSPoint(x: 0, y: (imageSize.height * scale - textSize.height) / 2))
        NSGraphicsContext.restoreGraphicsState()
        image.unlockFocus()
        image.isTemplate = red ? false : true
        return image
    }

    /// Point size the status bar glyph is drawn at (see `menuBarIcon`).
    private var iconPointSize: CGFloat {
        var size: CGFloat = 19
        let isIconPlusText = (vm.menuBarTextMode == .iconCountdown || vm.menuBarTextMode == .iconExactTime)
        if isIconPlusText, vm.menuBarLargerText {
            let scale = (NSFont.systemFontSize + 3) / NSFont.systemFontSize
            size = (size * scale).rounded()
        }
        return size
    }

    /// Icon + text baked into ONE template image for the accessibility
    /// path. `MenuBarExtra` does not measure a second `Image` in the label,
    /// so keeping icon and text as separate views drops the text entirely.
    private static func combinedLabelImage(title: NSAttributedString, larger: Bool, bold: Bool, iconSize: CGFloat) -> NSImage? {
        let attributed = NSMutableAttributedString(attributedString: title)
        let range = NSRange(location: 0, length: attributed.length)
        guard range.length > 0 else { return nil }
        let scale: CGFloat = NSScreen.main?.backingScaleFactor ?? 2
        let fontSize = NSFont.systemFontSize + (larger ? 3 : 0)
        attributed.addAttribute(.font, value: NSFont.systemFont(ofSize: fontSize * scale, weight: bold ? .bold : .regular), range: range)
        attributed.addAttribute(.foregroundColor, value: NSColor.black, range: range)
        let textSize = attributed.size()
        let spacingPx: CGFloat = 4 * scale
        let iconPx = iconSize * scale
        let widthPx = ceil(iconPx + spacingPx + textSize.width)
        let heightPx = ceil(max(iconPx, textSize.height))
        let imageSize = NSSize(width: ceil(widthPx / scale) + 1, height: ceil(heightPx / scale))
        guard let icon = baseIconImage() else { return textLabelImage(title: title, larger: larger, bold: bold) }
        let image = NSImage(size: imageSize)
        image.lockFocus()
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.cgContext.scaleBy(x: 1 / scale, y: 1 / scale)
        let iconY = (heightPx - iconPx) / 2
        icon.draw(in: NSRect(x: 0, y: iconY, width: iconPx, height: iconPx), from: NSRect(origin: .zero, size: icon.size), operation: .sourceOver, fraction: 1.0)
        attributed.draw(at: NSPoint(x: iconPx + spacingPx, y: (heightPx - textSize.height) / 2))
        NSGraphicsContext.restoreGraphicsState()
        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    /// Raw mosque glyph (un-sized) shared by `menuBarIcon` and the combined
    /// accessibility image so both paths render the same asset.
    private static func baseIconImage() -> NSImage? {
        if let image = NSImage(named: "MenuBarMosque") { return image }
        return NSImage(systemSymbolName: "moon.zzz.fill", accessibilityDescription: "Sajda Pro")
    }

    private var menuBarIcon: NSImage {
        let size = iconPointSize
        if vm.isPrayerImminent, let red = SajdaMenuBarLabel.tintedIcon(size: size) {
            return red
        }
        if let image = NSImage(named: "MenuBarMosque") {
            image.size = NSSize(width: size, height: size)
            image.isTemplate = true
            return image
        }
        let fallback = NSImage(systemSymbolName: "moon.zzz.fill", accessibilityDescription: "Sajda Pro")
            ?? NSImage()
        fallback.size = NSSize(width: size, height: size)
        fallback.isTemplate = true
        return fallback
    }

    /// Renders the imminent (red alert) label into a **single** non-template
    /// image: red-tinted mosque glyph plus the red title text.
    ///
    /// Two things force this shape:
    /// - `MenuBarExtra` draws label text in the status bar's own colour, so
    ///   neither the AppKit `.foregroundColor` attribute on `menuTitle` nor a
    ///   SwiftUI `.foregroundColor` modifier survives.
    /// - A second `Image` inside the label (icon + red text as separate views)
    ///   is not measured, so the item collapses to the icon alone. Baking both
    ///   into one image gives the status item a width to lay out.
    ///
    /// - Parameter iconSize: glyph size in points, or `0` for text-only modes.
    private static func imminentLabelImage(title: NSAttributedString, iconSize: CGFloat) -> NSImage? {
        let attributed = NSMutableAttributedString(attributedString: title)
        let range = NSRange(location: 0, length: attributed.length)
        guard range.length > 0 else { return nil }

        attributed.addAttribute(.foregroundColor, value: NSColor.systemRed, range: range)
        // `updateMenuTitle()` only sets a font when the accessibility text
        // size/weight options are on; supply the status bar's default so the
        // rendered glyphs match the system-drawn (non-red) case.
        if attributed.attribute(.font, at: 0, effectiveRange: nil) == nil {
            attributed.addAttribute(
                .font,
                value: NSFont.systemFont(ofSize: NSFont.systemFontSize),
                range: range
            )
        }

        let textSize = attributed.size()
        let spacing: CGFloat = iconSize > 0 ? 4 : 0
        let size = NSSize(
            width: ceil(iconSize + spacing + textSize.width) + 1,
            height: max(ceil(textSize.height), iconSize)
        )
        let icon = iconSize > 0 ? tintedIcon(size: iconSize) : nil

        let image = NSImage(size: size)
        image.lockFocus()
        if let icon {
            icon.draw(
                in: NSRect(x: 0, y: (size.height - iconSize) / 2, width: iconSize, height: iconSize),
                from: NSRect(origin: .zero, size: icon.size),
                operation: .sourceOver,
                fraction: 1.0
            )
        }
        attributed.draw(at: NSPoint(x: iconSize + spacing, y: (size.height - textSize.height) / 2))
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func tintedIcon(size: CGFloat) -> NSImage? {
        let base: NSImage?
        if let mosque = NSImage(named: "MenuBarMosque") {
            base = mosque
        } else {
            base = NSImage(systemSymbolName: "moon.zzz.fill", accessibilityDescription: "Sajda Pro")
        }
        guard let base else { return nil }
        let size = NSSize(width: size, height: size)
        let tinted = NSImage(size: size)
        tinted.lockFocus()
        NSColor.systemRed.set()
        NSRect(origin: .zero, size: size).fill()
        base.draw(in: NSRect(origin: .zero, size: size), from: NSRect(origin: .zero, size: base.size), operation: .destinationIn, fraction: 1.0)
        tinted.unlockFocus()
        tinted.isTemplate = false
        return tinted
    }
}

