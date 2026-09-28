// MARK: - GANTI SELURUH FILE: Sajda/NavigationAnimation+Custom.swift

import NavigationStack
import MacControlCenterUI
import SwiftUI

extension NavigationModel {
    /// Pushes a page, but only when the model is not already showing that stack.
    ///
    /// The package treats a second push onto a stack that is up as a programming
    /// error and stops the process — "Replacing showing navigation view '…' not
    /// allowed" (`NavigationStackModel.enqueueNewNode`). It also keeps the
    /// outgoing view alive and hittable for the length of a transition, so a
    /// second tap really can arrive while the first push is still playing: the
    /// row that started it is still under the user's cursor, folded or not.
    ///
    /// Asking the model first is what turns that window into a no-op, and it is
    /// the same check the package documents for this ("True when it's safe to
    /// navigate to the ID"). A stale node that is *not* showing needs no guard:
    /// the package drops those itself as it walks the chain.
    ///
    /// - Returns: whether the push was requested. `false` means the page was
    ///   already up and nothing was pushed.
    @discardableResult
    func showPageIfNotShowing<Content: View>(
        _ identifier: String,
        animation: NavigationAnimation? = nil,
        @ViewBuilder alternativeView: @escaping () -> Content
    ) -> Bool {
        guard !isAlternativeViewShowing(identifier) else { return false }
        showView(identifier, animation: animation, alternativeView: alternativeView)
        return true
    }
}

extension Animation {
    /// The Control Center menu pace — literally `macControlCenterMenuResize`
    /// (`.smooth(duration: 0.2, extraBounce: 0.25)`). Used for every Sajda
    /// navigation curve so page transitions and the panel's height resize
    /// move as one motion instead of two speeds racing each other.
    static let sajdaResizePace: Animation = .macControlCenterMenuResize

    /// Slow, calm expand/collapse curve for the panel's location accordion —
    /// the location row on MainView and the inline searches nested in
    /// `FavoritesSection` — so a reveal feels smooth rather than shocking.
    /// Deliberately slower than the snappy `.macControlCenterMenuResize`
    /// (0.2 s) window snap — the panel window tracks the animating content
    /// size frame-by-frame, so stretching the SwiftUI animation stretches the
    /// whole resize with it.
    ///
    /// The settings accordions do not use it: `SettingsAccordion` (About >
    /// Acknowledgements, Location & Calculation > Calculation, Adhan Sound >
    /// Per Prayer) toggles with no animation at all, so those sections snap.
    static let sajdaAccordion: Animation = .smooth(duration: 0.38, extraBounce: 0)
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
