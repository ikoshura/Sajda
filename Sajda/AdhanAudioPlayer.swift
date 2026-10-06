import AVFoundation
import AppKit

class AdhanAudioPlayer: NSObject, AVAudioPlayerDelegate, NSSoundDelegate {
    static let shared = AdhanAudioPlayer()

    private var player: AVAudioPlayer?
    private var sound: NSSound?
    private var playedPrayers: Set<String> = []
    private var activityToken: NSObjectProtocol?

    private(set) var currentPrayerName: String?
    /// True while a Settings sound-check sample owns the output. Set by
    /// `preview()`, cleared by any `stop()` (the row's stop glyph, a real
    /// adhan taking over) or by the sample finishing naturally — which is
    /// what turns the finish into `.adhanPreviewDidFinish` rather than
    /// `.adhanDidStop` (a sample has no prayer to report). Read by the Adhan
    /// Sound page so leaving the page can end only *its* sample, never a real
    /// adhan playing over a stale preview state.
    private(set) var isPreviewPlayback = false

    private static let supportedAudioExtensions = ["caf", "mp3", "m4a", "aiff", "wav"]

    private override init() {
        super.init()
        disableAppNap()
    }

    private func disableAppNap() {
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Playing adhan and monitoring prayer times"
        )
    }

    private func playSystemBeep() {
        let systemSoundURL = URL(fileURLWithPath: "/System/Library/Sounds/Submarine.aiff")
        if let snd = NSSound(contentsOf: systemSoundURL, byReference: true) {
            self.sound = snd
            snd.delegate = self
            snd.play()
            return
        }
        if let snd = NSSound(named: "Submarine") {
            self.sound = snd
            snd.delegate = self
            snd.play()
        }
    }

    private func bundleURL(forResource name: String) -> URL? {
        for ext in Self.supportedAudioExtensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                return url
            }
        }
        return nil
    }

    func play(adhanType: AdhanType, customFilePath: String? = nil, prayerName: String? = nil) {
        guard adhanType != .none else { return }

        if let prayer = prayerName, playedPrayers.contains(prayer) { return }
        if let prayer = prayerName { playedPrayers.insert(prayer) }

        stop()
        currentPrayerName = prayerName

        switch adhanType {
        case .defaultBeep:
            playSystemBeep()
        case .custom:
            if let path = customFilePath,
               !path.isEmpty,
               let url = URL(string: path),
               FileManager.default.fileExists(atPath: url.path) {
                playURL(url)
            } else {
                playSystemBeep()
            }
        default:
            if let fileName = adhanType.bundleFileName,
               let url = bundleURL(forResource: fileName) {
                playURL(url)
            } else {
                playSystemBeep()
            }
        }
        postAdhanDidStart()
    }

    func stop() {
        let wasPlaying = player != nil || sound != nil
        isPreviewPlayback = false
        player?.stop()
        player = nil
        sound?.stop()
        sound = nil
        if wasPlaying {
            let stoppedPrayer = currentPrayerName
            currentPrayerName = nil
            if stoppedPrayer != nil {
                NotificationCenter.default.post(name: .adhanDidStop, object: self, userInfo: ["prayerName": stoppedPrayer!])
            }
        }
    }

    private func postAdhanDidStart() {
        guard let prayer = currentPrayerName else { return }
        NotificationCenter.default.post(name: .adhanDidStart, object: self, userInfo: ["prayerName": prayer])
    }

    /// Plays a full-length sound check from Settings → Adhan Sound, exactly as
    /// the adhan will sound at prayer time — it runs to the end of the file
    /// with no auto-stop. The old fixed cut showed only the opening seconds,
    /// and worse: every restart left the *previous* sample's pending auto-stop
    /// alive to kill the new one, so consecutive taps cut the sample shorter
    /// and shorter. The row reverts its stop glyph when `.adhanPreviewDidFinish`
    /// arrives; any `stop()` ends the sample silently instead.
    func preview(adhanType: AdhanType, customFilePath: String? = nil) {
        stop()

        switch adhanType {
        case .none:
            return
        case .defaultBeep:
            isPreviewPlayback = true
            playSystemBeep()
        case .custom:
            guard let path = customFilePath,
                  !path.isEmpty,
                  let url = URL(string: path),
                  FileManager.default.fileExists(atPath: url.path) else { return }
            isPreviewPlayback = true
            playURL(url)
        default:
            guard let fileName = adhanType.bundleFileName,
                  let url = bundleURL(forResource: fileName) else { return }
            isPreviewPlayback = true
            playURL(url)
        }
    }

    func markPrayerPlayed(_ prayerName: String) {
        playedPrayers.insert(prayerName)
    }

    /// Re-arms one prayer: forget it already played so its next trigger can
    /// sound. Called when a prayer's scheduled instant moves (a time
    /// correction or recalculation) — a moved instant is a *new occurrence*,
    /// not a replay of the one that already played. See
    /// `PrayerTimeViewModel.scheduleAdhanTriggers`.
    func rearmPrayer(_ prayerName: String) {
        playedPrayers.remove(prayerName)
    }

    func resetPlayedPrayers() {
        playedPrayers.removeAll()
    }

    private func playURL(_ url: URL) {
        // Use NSSound as primary player — more reliable for long-form audio on macOS.
        // byReference: false loads the entire file into memory, preventing mid-playback
        // buffering issues that can occur with AVAudioPlayer for files longer than ~15s.
        if let snd = NSSound(contentsOf: url, byReference: false) {
            snd.delegate = self
            self.sound = snd
            if snd.play() {
                print("AdhanAudioPlayer: playing \(url.lastPathComponent) via NSSound")
                return
            }
            self.sound = nil
        }

        // Fallback to AVAudioPlayer
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            player?.volume = 1.0

            if player?.play() == true {
                print("AdhanAudioPlayer: playing \(url.lastPathComponent) via AVAudioPlayer")
                return
            }
        } catch {
            print("AdhanAudioPlayer: AVAudioPlayer failed: \(error)")
        }

        print("AdhanAudioPlayer: all playback methods failed for \(url.lastPathComponent)")
    }

    // MARK: - NSSoundDelegate

    func sound(_ sound: NSSound, didFinishPlaying flag: Bool) {
        if !flag {
            print("NSSound finished playing unsuccessfully")
        }
        if sound === self.sound {
            self.sound = nil
            let finishedPrayer = currentPrayerName
            currentPrayerName = nil
            if let prayer = finishedPrayer {
                NotificationCenter.default.post(name: .adhanDidStop, object: self, userInfo: ["prayerName": prayer])
            } else if isPreviewPlayback {
                // A sound check has no prayer to report — announce the finish
                // on its own channel so the row's stop glyph reverts to play.
                isPreviewPlayback = false
                NotificationCenter.default.post(name: .adhanPreviewDidFinish, object: self)
            }
        }
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if !flag {
            print("Audio playback finished unsuccessfully")
        }
        let finishedPrayer = currentPrayerName
        currentPrayerName = nil
        if let prayer = finishedPrayer {
            NotificationCenter.default.post(name: .adhanDidStop, object: self, userInfo: ["prayerName": prayer])
        } else if isPreviewPlayback {
            // A sound check has no prayer to report — announce the finish on
            // its own channel so the row's stop glyph reverts to play.
            isPreviewPlayback = false
            NotificationCenter.default.post(name: .adhanPreviewDidFinish, object: self)
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Audio decode error: \(error?.localizedDescription ?? "unknown")")
    }
}
