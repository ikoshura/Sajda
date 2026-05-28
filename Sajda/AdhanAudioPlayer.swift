import AVFoundation
import AppKit

class AdhanAudioPlayer {
    static let shared = AdhanAudioPlayer()

    private var player: AVAudioPlayer?
    private var playedPrayers: Set<String> = []

    private init() {}

    func play(adhanType: AdhanType, customFilePath: String? = nil, prayerName: String? = nil) {
        guard adhanType != .none else { return }

        if let prayer = prayerName, playedPrayers.contains(prayer) { return }
        if let prayer = prayerName { playedPrayers.insert(prayer) }

        stop()

        switch adhanType {
        case .defaultBeep:
            NSSound(named: .init("Submarine"))?.play()
            return
        case .custom:
            guard let path = customFilePath?.removingPercentEncoding,
                  let url = URL(string: path),
                  FileManager.default.fileExists(atPath: url.path) else {
                NSSound(named: .init("Submarine"))?.play()
                return
            }
            playURL(url)
        default:
            guard let fileName = adhanType.bundleFileName,
                  let url = Bundle.main.url(forResource: fileName, withExtension: "mp3") else {
                NSSound(named: .init("Submarine"))?.play()
                return
            }
            playURL(url)
        }
    }

    func stop() {
        player?.stop()
        player = nil
    }

    func preview(adhanType: AdhanType, customFilePath: String? = nil, duration: TimeInterval = 5.0) {
        stop()

        switch adhanType {
        case .none:
            return
        case .defaultBeep:
            NSSound(named: .init("Submarine"))?.play()
            return
        case .custom:
            guard let path = customFilePath?.removingPercentEncoding,
                  let url = URL(string: path),
                  FileManager.default.fileExists(atPath: url.path) else { return }
            playURL(url, autoStopAfter: duration)
        default:
            guard let fileName = adhanType.bundleFileName,
                  let url = Bundle.main.url(forResource: fileName, withExtension: "mp3") else { return }
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
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            player?.play()

            if let duration = autoStopAfter {
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                    self?.stop()
                }
            }
        } catch {
            print("Failed to play audio: \(error)")
        }
    }
}
