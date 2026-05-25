import AVFoundation
import Combine
import ComposableArchitecture

/// Manages a single AVPlayer for 30 s iTunes preview streams.
final class AudioPlayer: ObservableObject {
    @Published var isPlaying  = false
    @Published var progress   = 0.0
    @Published var currentURL = ""
    @Published var errorMsg:  String? = nil

    private var player:     AVPlayer?
    private var observer:   Any?
    private var statusObs:  NSKeyValueObservation?

    func play(url: String) {
        guard let u = URL(string: url), !url.isEmpty else { return }
        stop()
        errorMsg = nil

        // Activate audio session
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default,
                                                            options: [.defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Non-fatal on Simulator; continue anyway
        }

        let item  = AVPlayerItem(url: u)
        player    = AVPlayer(playerItem: item)
        currentURL = url

        // Wait for player item to be ready before playback
        statusObs = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay:
                    self.isPlaying = true
                    self.player?.play()
                case .failed:
                    let desc = item.error?.localizedDescription ?? "Unknown error"
                    self.errorMsg = "Preview failed: \(desc)"
                    self.stop()
                default: break
                }
            }
        }

        // Progress tracking
        observer = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main
        ) { [weak self] t in
            guard let self,
                  let dur = self.player?.currentItem?.duration,
                  dur.isNumeric, dur.seconds > 0 else { return }
            self.progress = t.seconds / dur.seconds
            if self.progress >= 0.99 { self.stop() }
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(didFinish),
            name: .AVPlayerItemDidPlayToEndTime, object: item
        )
    }

    func pause() { player?.pause(); isPlaying = false }

    func stop() {
        statusObs?.invalidate(); statusObs = nil
        if let o = observer { player?.removeTimeObserver(o); observer = nil }
        NotificationCenter.default.removeObserver(
            self, name: .AVPlayerItemDidPlayToEndTime, object: nil
        )
        player?.pause(); player = nil
        isPlaying = false; progress = 0; currentURL = ""
        // Keep errorMsg so the UI can show it; caller clears on next play()
    }

    @objc private func didFinish() {
        DispatchQueue.main.async { self.stop() }
    }

    deinit { stop() }
}
