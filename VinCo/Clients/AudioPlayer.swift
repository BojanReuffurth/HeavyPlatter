import AVFoundation
import Combine
import ComposableArchitecture

/// Manages a single AVPlayer for 30s iTunes previews.
final class AudioPlayer: ObservableObject {
    @Published var isPlaying  = false
    @Published var progress   = 0.0
    @Published var currentURL = ""
    private var player:   AVPlayer?
    private var observer: Any?

    func play(url: String) {
        guard let u = URL(string: url) else { return }
        stop()
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        let item = AVPlayerItem(url: u)
        player = AVPlayer(playerItem: item)
        currentURL = url; isPlaying = true
        player?.play()
        observer = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] t in
            guard let self, let dur = self.player?.currentItem?.duration,
                  dur.isNumeric, dur.seconds > 0 else { return }
            self.progress = t.seconds / dur.seconds
            if self.progress >= 0.99 { self.stop() }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(didFinish),
            name: .AVPlayerItemDidPlayToEndTime, object: item)
    }
    func pause() { player?.pause(); isPlaying = false }
    func stop()  {
        if let o = observer { player?.removeTimeObserver(o); observer = nil }
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        player?.pause(); player = nil; isPlaying = false; progress = 0; currentURL = ""
    }
    @objc private func didFinish() { DispatchQueue.main.async { self.stop() } }
    deinit { stop() }
}
