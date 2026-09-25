// MARK: - GANTI FILE: Sajda/FluidMenuBar/FluidMenuBarExtraWindow.swift (LIQUID GLASS REVAMP)
//
// Menu bar panel background:
// - macOS 26+: NSGlassEffectView (.regular, interactive) wrapping the hosting
//   view — the same technique as the Sunray-xdr reference implementation.
// - Older systems: the previous NSVisualEffectView + border look.

import AppKit
import SwiftUI

// MARK: - AccentPanelTintOverlay

/// Translucent Accent Panel tint for the whole menu bar panel.
///
/// Attached at the window root (see `rootView`) — *outside* the content's
/// `fixedSize()` — so the tinted rectangle is always the hosting view's live
/// bounds: it follows the panel's `setFrame(..., animate: true)` movement
/// frame-by-frame instead of lagging one SwiftUI layout pass behind. The
/// colour math is shared with `PrayerTimeViewModel`, and `@AppStorage` keeps
/// it live when the toggle or a highlight swatch changes. The stored alpha
/// (ColorSelector opacity slider) drives the tint's transparency; anything
/// without one uses the default translucency.
struct AccentPanelTintOverlay: View {
    @AppStorage("accentPanelTheme") private var accentPanelTheme = false
    @AppStorage("customHighlightColorHex") private var customHighlightColorHex = ""

    var body: some View {
        if accentPanelTheme {
            let base = PrayerTimeViewModel.accentPanelTint(fromHighlightHex: customHighlightColorHex)
            let opacity = PrayerTimeViewModel.accentPanelOpacity(fromHighlightHex: customHighlightColorHex)
            base.opacity(opacity)
        }
    }
}

final class FluidMenuBarExtraWindow<Content: View>: NSPanel {
    private let content: () -> Content

    private lazy var visualEffectView: NSVisualEffectView = {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .popover
        view.translatesAutoresizingMaskIntoConstraints = true

        // --- TAMBAHAN UNTUK BORDER NATIVE ---
        view.wantsLayer = true
        view.layer?.cornerRadius = GlassConstants.panelCornerRadius
        view.layer?.masksToBounds = true
        view.layer?.borderWidth = 0.5
        // Mengganti "SecondaryTextColor" dengan "BorderColor" yang baru dan lebih subtle.
        view.layer?.borderColor = NSColor(named: "BorderColor")?.cgColor
        // --- AKHIR PERUBAHAN ---

        return view
    }()

    /// Liquid Glass container factory for macOS 26+. Draws its own specular
    /// edge, so no manual border layer is needed.
    @available(macOS 26.0, *)
    private func makeGlassEffectView() -> NSGlassEffectView {
        let view = NSGlassEffectView()
        view.autoresizingMask = [.width, .height]
        view.style = .regular
        view.cornerRadius = GlassConstants.panelCornerRadius
        // The panel hosts interactive controls, so enable interactive glass
        // feedback where the OS supports it (macOS 27+).
        if #available(macOS 27.0, *) {
            view.effectIsInteractive = true
        }
        return view
    }

    private var rootView: some View {
        content()
            .modifier(RootViewModifier(windowTitle: title))
            // Accent tint behind everything, sized by the window's own
            // proposal (after RootViewModifier's fixedSize) so its rectangle
            // can't lag the panel's animated resize movement.
            .background {
                AccentPanelTintOverlay()
                    .ignoresSafeArea()
            }
            .onSizeUpdate { [weak self] size in
                self?.contentSizeDidUpdate(to: size)
            }
    }

    private lazy var hostingView: NSHostingView<some View> = {
        let view = NSHostingView(rootView: rootView)
        if #available(macOS 13.0, *) {
            view.sizingOptions = []
        }
        view.isVerticalContentSizeConstraintActive = false
        view.isHorizontalContentSizeConstraintActive = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    init(title: String, content: @escaping () -> Content) {
        self.content = content

        super.init(
            contentRect: CGRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.titled, .nonactivatingPanel, .utilityWindow, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.title = title
        isOpaque = false
        backgroundColor = .clear
        isMovable = false
        isMovableByWindowBackground = false
        isFloatingPanel = true
        level = .statusBar
        titleVisibility = .hidden
        titlebarAppearsTransparent = true

        animationBehavior = .none
        if #available(macOS 13.0, *) {
            collectionBehavior = [.auxiliary, .stationary, .moveToActiveSpace, .fullScreenAuxiliary]
        } else {
            collectionBehavior = [.stationary, .moveToActiveSpace, .fullScreenAuxiliary]
        }
        isReleasedWhenClosed = false
        hidesOnDeactivate = false

        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        if #available(macOS 26.0, *) {
            // Liquid Glass path (mirrors the Sunray-xdr reference): the hosting
            // view lives in the glass view's contentView — the only placement
            // NSGlassEffectView guarantees relative to the glass effect.
            // Frame + autoresizing keeps it filling the panel as it resizes.
            let glassView = makeGlassEffectView()
            hostingView.translatesAutoresizingMaskIntoConstraints = true
            hostingView.autoresizingMask = [.width, .height]
            hostingView.frame = glassView.bounds
            glassView.contentView = hostingView
            contentView = glassView
        } else {
            // Fallback path for macOS 13.3–25.x: blur + border, as before.
            contentView = visualEffectView
            visualEffectView.addSubview(hostingView)

            NSLayoutConstraint.activate([
                hostingView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
                hostingView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
                hostingView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor),
                hostingView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor)
            ])
        }

        setContentSize(hostingView.intrinsicContentSize)
    }

    private func contentSizeDidUpdate(to size: CGSize) {
        var nextFrame = frame
        let previousContentSize = contentRect(forFrameRect: frame).size
        let deltaX = size.width - previousContentSize.width
        let deltaY = size.height - previousContentSize.height
        nextFrame.origin.y -= deltaY
        nextFrame.size.width += deltaX
        nextFrame.size.height += deltaY
        guard frame != nextFrame else { return }
        DispatchQueue.main.async { [weak self] in
            self?.setFrame(nextFrame, display: true, animate: true)
        }
    }
}
