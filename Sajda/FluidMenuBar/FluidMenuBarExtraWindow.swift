// Salin dan tempel SELURUH kode ini ke dalam file FluidMenuBar/FluidMenuBarExtraWindow.swift

import AppKit
import SwiftUI

final class FluidMenuBarExtraWindow<Content: View>: NSPanel {
    private let content: () -> Content

    private lazy var visualEffectView: NSVisualEffectView = {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .popover
        view.translatesAutoresizingMaskIntoConstraints = true
        return view
    }()

    private var rootView: some View {
        content()
            .modifier(RootViewModifier(windowTitle: title))
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
        
        // ==========================================================
        // PERBAIKAN ANTI-GLITCH DIMULAI DI SINI
        // ==========================================================
        
        // 1. Memerintahkan jendela agar TIDAK menggambar latar belakangnya sendiri.
        // Ini memaksa jendela untuk selalu transparan dari dasarnya.
        isOpaque = false
        backgroundColor = .clear
        
        // ==========================================================
        // PERBAIKAN ANTI-GLITCH SELESAI
        // ==========================================================

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

        contentView = visualEffectView
        visualEffectView.addSubview(hostingView)
        setContentSize(hostingView.intrinsicContentSize)

        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor)
        ])
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
