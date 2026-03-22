import SwiftUI
import UIKit
import AVKit

// MARK: - ExplainerVideoPlayer

struct ExplainerVideoPlayer: View {
    let videoName: String
    let isActive: Bool
    var preloadedPlayer: AVQueuePlayer?
    var useTransparentBackground: Bool = false

    var body: some View {
        ExplainerVideoPlayerRepresentable(videoName: videoName, isActive: isActive, preloadedPlayer: preloadedPlayer, useTransparentBackground: useTransparentBackground)
    }
}

struct ExplainerVideoPlayerRepresentable: UIViewRepresentable {
    let videoName: String
    let isActive: Bool
    var preloadedPlayer: AVQueuePlayer?
    var useTransparentBackground: Bool = false

    func makeUIView(context: Context) -> UIView {
        let view = ExplainerVideoPlayerView()
        view.configure(videoName: videoName, preloadedPlayer: preloadedPlayer, useTransparentBackground: useTransparentBackground)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let playerView = uiView as? ExplainerVideoPlayerView else { return }
        playerView.usePreloadedPlayerIfNeeded(preloadedPlayer)
        if isActive {
            playerView.play()
        } else {
            playerView.pause()
        }
    }
}

final class ExplainerVideoPlayerView: UIView {
    private var playerLayer: AVPlayerLayer?
    private var player: AVPlayer?
    private var looper: AVPlayerLooper?
    private var isUsingPreloadedPlayer = false

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(videoName: String, preloadedPlayer: AVQueuePlayer? = nil, useTransparentBackground: Bool = false) {
        let queuePlayer: AVQueuePlayer
        if let preloaded = preloadedPlayer {
            queuePlayer = preloaded
            queuePlayer.isMuted = true
            queuePlayer.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            isUsingPreloadedPlayer = true
        } else {
            guard let url = Bundle.main.url(forResource: videoName, withExtension: "mp4", subdirectory: nil) else { return }
            let playerItem = AVPlayerItem(url: url)
            queuePlayer = AVQueuePlayer(playerItem: playerItem)
            looper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
            queuePlayer.isMuted = true
            queuePlayer.actionAtItemEnd = .none
            isUsingPreloadedPlayer = false
        }

        backgroundColor = useTransparentBackground ? .clear : .white
        let layer = AVPlayerLayer(player: queuePlayer)
        layer.videoGravity = .resizeAspect
        layer.frame = bounds
        layer.backgroundColor = useTransparentBackground ? UIColor.clear.cgColor : UIColor.white.cgColor
        self.layer.addSublayer(layer)

        player = queuePlayer
        playerLayer = layer
    }

    func usePreloadedPlayerIfNeeded(_ preloaded: AVQueuePlayer?) {
        guard let preloaded = preloaded, !isUsingPreloadedPlayer, let layer = playerLayer else { return }
        player?.pause()
        preloaded.isMuted = true
        preloaded.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        layer.player = preloaded
        player = preloaded
        isUsingPreloadedPlayer = true
    }

    func play() {
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }
}
