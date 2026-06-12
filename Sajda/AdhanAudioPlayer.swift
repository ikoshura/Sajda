import AVFoundation
import AppKit

class AdhanAudioPlayer: NSObject, AVAudioPlayerDelegate, NSSoundDelegate {
    static let shared = AdhanAudioPlayer()

    private var player: AVAudioPlayer?
    private var sound: NSSound?
    private var playedPrayers: Set<String> = []
    private var activityToken: NSObjectProtocol?

    private(set) var currentPrayerName: String?

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

    func preview(adhanType: AdhanType, customFilePath: String? = nil, duration: TimeInterval = 5.0) {
        stop()

        switch adhanType {
        case .none:
            return
        case .defaultBeep:
            playSystemBeep()
            return
        case .custom:
            guard let path = customFilePath,
                  !path.isEmpty,
                  let url = URL(string: path),
                  FileManager.default.fileExists(atPath: url.path) else { return }
            playURL(url, autoStopAfter: duration)
        default:
            guard let fileName = adhanType.bundleFileName,
                  let url = bundleURL(forResource: fileName) else { return }
            playURL(url, autoStopAfter: duration)
        }
    }

    func markPrayerPlayed(_ prayerName: String) {
        playedPrayers.insert(prayerName)
    }

    func resetPlayedPrayers() {
        playedPrayers.removeAll()
    }

    private func playURL(_ url: URL, autoStopAfter: TimeInterval? = nil) {
        // Use NSSound as primary player — more reliable for long-form audio on macOS.
        // byReference: false loads the entire file into memory, preventing mid-playback
        // buffering issues that can occur with AVAudioPlayer for files longer than ~15s.
        if let snd = NSSound(contentsOf: url, byReference: false) {
            snd.delegate = self
            self.sound = snd
            if snd.play() {
                print("AdhanAudioPlayer: playing \(url.lastPathComponent) via NSSound")
                if let duration = autoStopAfter {
                    DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                        self?.stop()
                    }
                }
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
                if let duration = autoStopAfter {
                    DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                        self?.stop()
                    }
                }
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
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Audio decode error: \(error?.localizedDescription ?? "unknown")")
    }
}
