// MARK: - GANTI SELURUH FILE: Sajda/NavigationAnimation+Custom.swift

import NavigationStack
import MacControlCenterUI
import SwiftUI

extension Animation {
    /// The Control Center menu pace — literally `macControlCenterMenuResize`
    /// (`.smooth(duration: 0.2, extraBounce: 0.25)`). Used for every Sajda
    /// navigation curve so page transitions and the panel's height resize
    /// move as one motion instead of two speeds racing each other.
    static let sajdaResizePace: Animation = .macControlCenterMenuResize
}

extension NavigationAnimation {
    /// Animasi cross-fade yang sangat ringan dan mulus, dikombinasikan dengan sedikit efek skala untuk ilusi kedalaman.
    /// Dirancang untuk performa maksimal pada view yang kompleks.
    ///
    /// Runs at the Control Center pace (`sajdaResizePace`) so the crossfade
    /// and the window's height resize share one spring. The panel-height jump
    /// seen earlier in 4.2.1 was traced to the settings panel carrying an
    /// extra row (Display was one row taller than 4.2.0), not to this curve —
    /// with the height restored the spring no longer has anything to overshoot
    /// against. Non-navigation resizes (toggles, text size, language) keep the
    /// same pace via the keyed
    /// `.animation(.macControlCenterMenuResize, value: panelLayoutSignature)`
    /// in `SajdaControlCenterMenu`.
    static let sajdaCrossfade: NavigationAnimation = NavigationAnimation(
        animation: .sajdaResizePace,
        defaultViewTransition: .opacity.combined(with: .scale(scale: 0.97)),
        alternativeViewTransition: .opacity.combined(with: .scale(scale: 1.0))
    )

    /// Slide-forward ("Animation Style: Slide") at the same Control Center
    /// pace — the package's `.push`, re-curved. Kept as its own static so the
    /// pace can be tuned for navigation without touching the resize key.
    static let sajdaPush: NavigationAnimation = NavigationAnimation(
        animation: .sajdaResizePace,
        defaultViewTransition: .move(edge: .leading),
        alternativeViewTransition: .move(edge: .trailing)
    )

    /// Slide-back counterpart of `sajdaPush`, mirroring the package's `.pop`.
    static let sajdaPop: NavigationAnimation = NavigationAnimation(
        animation: .sajdaResizePace,
        defaultViewTransition: .move(edge: .leading),
        alternativeViewTransition: .move(edge: .trailing)
    )
}
