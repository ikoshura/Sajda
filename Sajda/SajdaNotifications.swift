// MARK: - Sajda/SajdaNotifications.swift

import Foundation

extension Notification.Name {
    static let popoverDidClose = Notification.Name("com.sajda.popoverDidClose")
    static let popoverDidOpen = Notification.Name("com.sajda.popoverDidOpen")
    static let prayerTimesUpdated = Notification.Name("prayerTimesUpdated")
    static let adhanDidStart = Notification.Name("com.sajda.adhanDidStart")
    static let adhanDidStop = Notification.Name("com.sajda.adhanDidStop")
    /// A Settings sound-check (`AdhanAudioPlayer.preview`) finished on its own.
    /// A sample has no prayer to report, so it cannot reuse `.adhanDidStop` —
    /// the Adhan Sound page listens here to flip its stop glyph back to play.
    static let adhanPreviewDidFinish = Notification.Name("com.sajda.adhanPreviewDidFinish")
}
