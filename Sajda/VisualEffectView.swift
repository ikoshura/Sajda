// MARK: - Sajda/VisualEffectView.swift (LIQUID GLASS REVAMP)
//
// Shared background + hover styling helpers.
// - On macOS 26+: native Liquid Glass (NSGlassEffectView / .glassEffect).
// - On older systems: the previous NSVisualEffectView / HoverColor look.

import SwiftUI
import AppKit

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = material
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}

// MARK: - GlassConstants

/// Corner radii shared by the menu bar panel and standalone windows so the
/// Liquid Glass look stays consistent across the app (and across OS versions).
enum GlassConstants {
    /// Corner radius of the main menu bar panel (220–260 pt wide).
    static let panelCornerRadius: CGFloat = 16
    /// Corner radius of the standalone windows (onboarding, prayer alert).
    static let windowCornerRadius: CGFloat = 20
}

// MARK: - PanelInteriorBackground

/// Background for views that live *inside* the menu bar panel (e.g. AboutView).
///
/// On macOS 26+ this is fully transparent so the panel's own Liquid Glass
/// (installed in `FluidMenuBarExtraWindow`) shows through — a second blur
/// layer would cover it up. On older systems it returns the given
/// `NSVisualEffectView` material, matching the panel behind it.
struct PanelInteriorBackground: View {
    var material: NSVisualEffectView.Material = .popover

    var body: some View {
        Group {
            if #available(macOS 26.0, *) {
                Color.clear
            } else {
                VisualEffectView(material: material)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - GlassBackgroundView

/// Liquid Glass background for standalone windows (onboarding, prayer alert).
///
/// On macOS 26+ this renders an `NSGlassEffectView` (`.regular` style,
/// interactive on macOS 27+ since these windows host controls). On older
/// systems it falls back to an `NSVisualEffectView` with the given material.
struct GlassBackgroundView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var cornerRadius: CGFloat = 0
    var isInteractive: Bool = false

    func makeNSView(context: Context) -> NSView {
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.style = .regular
            glass.cornerRadius = cornerRadius
            if #available(macOS 27.0, *), isInteractive {
                glass.effectIsInteractive = true
            }
            return glass
        } else {
            let view = NSVisualEffectView()
            view.blendingMode = .behindWindow
            view.state = .active
            view.material = material
            if cornerRadius > 0 {
                view.wantsLayer = true
                view.layer?.cornerRadius = cornerRadius
                view.layer?.masksToBounds = true
            }
            return view
        }
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if #available(macOS 26.0, *) {
            guard let glass = nsView as? NSGlassEffectView else { return }
            glass.cornerRadius = cornerRadius
            if #available(macOS 27.0, *) {
                glass.effectIsInteractive = isInteractive
            }
        } else if let view = nsView as? NSVisualEffectView {
            view.material = material
        }
    }
}

// MARK: - LiquidHover

/// Flat macOS hover highlight for rows and buttons.
///
/// Uses the translucent `HoverColor` fill on every macOS version — the same
/// regular hover the app has always used, matching the native menu-bar hover
/// shown on Wi-Fi / battery. The Liquid Glass pill (`.glassEffect(.interactive)`)
/// that previously appeared on macOS 26+ has been removed.
struct LiquidHover: ViewModifier {
    let isActive: Bool
    var cornerRadius: CGFloat = 5

    func body(content: Content) -> some View {
        content
            .background(isActive ? Color("HoverColor") : .clear)
            .cornerRadius(cornerRadius)
    }
}

extension View {
    /// Applies the flat macOS hover highlight when `isActive` is true.
    func liquidHover(_ isActive: Bool, cornerRadius: CGFloat = 5) -> some View {
        modifier(LiquidHover(isActive: isActive, cornerRadius: cornerRadius))
    }

    /// Renders the view's region as Liquid Glass on macOS 26+, clipped to a
    /// rounded rectangle. On older systems the view is left unchanged
    /// (callers provide their own fallback background).
    func glassCard(cornerRadius: CGFloat = 8, interactive: Bool = false) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, interactive: interactive))
    }
}

// MARK: - GlassCard

/// Turns any view into a Liquid Glass surface on macOS 26+ (identity on older
/// systems). Used for cards nested inside an already-glass panel, where a
/// full `NSGlassEffectView` background would double up the effect.
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 8
    var interactive: Bool = false

    func body(content: Content) -> some View {
        cardBody(content)
    }

    @ViewBuilder
    private func cardBody(_ content: Content) -> some View {
        if #available(macOS 26.0, *) {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            content.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            content
        }
    }
}
