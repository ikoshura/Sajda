// MARK: - GANTI SELURUH FILE: Sajda/NavigationAnimation+Custom.swift

import NavigationStack
import SwiftUI

extension NavigationAnimation {
    /// Animasi cross-fade yang sangat ringan dan mulus, dikombinasikan dengan sedikit efek skala untuk ilusi kedalaman.
    /// Dirancang untuk performa maksimal pada view yang kompleks.
    static let sajdaCrossfade: NavigationAnimation = NavigationAnimation(
        animation: .easeInOut(duration: 0.25),
        defaultViewTransition: .opacity.combined(with: .scale(scale: 0.97)),
        alternativeViewTransition: .opacity.combined(with: .scale(scale: 1.0))
    )
}
