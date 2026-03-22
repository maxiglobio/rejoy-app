import SwiftUI
import UIKit
import AVKit

struct HowToUseRejoyCarouselSheet: View {
    @Environment(\.appLanguage) private var appLanguage
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    @ObservedObject private var slide2Preloader = Slide2VideoPreloader.shared

    private let slides: [(imageName: String, videoName: String?, titleKey: String, descKey: String)] = [
        ("ExplainerSlide1", nil, "how_to_use_slide_1_title", "how_to_use_slide_1_desc"),
        ("ExplainerSlide2", "slide2", "how_to_use_slide_2_title", "how_to_use_slide_2_desc"),
        ("ExplainerSlide3", "slide3", "how_to_use_slide_3_title", "how_to_use_slide_3_desc"),
        ("ExplainerSlide4", nil, "how_to_use_slide_4_title", "how_to_use_slide_4_desc"),
        ("ExplainerSlide5", "slide5", "how_to_use_slide_5_title", "how_to_use_slide_5_desc"),
        ("ExplainerSlide6", nil, "how_to_use_slide_6_title", "how_to_use_slide_6_desc"),
        ("ExplainerSlide7", nil, "how_to_use_slide_7_title", "how_to_use_slide_7_desc"),
        ("ExplainerSlide8", nil, "how_to_use_slide_8_title", "how_to_use_slide_8_desc"),
        ("ExplainerSlide9", nil, "how_to_use_slide_9_title", "how_to_use_slide_9_desc"),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(0..<slides.count, id: \.self) { index in
                        slideContent(for: index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(minHeight: 720)
                .onChange(of: currentPage) { _, _ in
                    UISelectionFeedbackGenerator().selectionChanged()
                }

                paginationDots
                    .padding(.top, 24)
                    .padding(.bottom, 16)
            }
            .navigationTitle(L.string("how_to_use_rejoy", language: appLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.string("done", language: appLanguage)) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    }
                }
            }
            .onAppear {
                slide2Preloader.preload()
            }
        }
    }

    private func slideContent(for index: Int) -> some View {
        let slide = slides[index]
        return VStack(spacing: 24) {
            Group {
                if let videoName = slide.videoName {
                    ExplainerVideoPlayer(videoName: videoName, isActive: currentPage == index, preloadedPlayer: videoName == "slide2" ? slide2Preloader.player : nil)
                } else {
                    Image(slide.imageName)
                        .resizable()
                        .scaledToFit()
                }
            }
            .frame(maxHeight: 520)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Text(L.string(slide.titleKey, language: appLanguage))
                .font(AppFont.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text(L.string(slide.descKey, language: appLanguage))
                .font(AppFont.body)
                .foregroundStyle(AppColors.dotsSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 32)
    }

    private var paginationDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<slides.count, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? AppColors.rejoyOrange : AppColors.rejoyOrange.opacity(0.3))
                    .frame(width: index == currentPage ? 10 : 8, height: index == currentPage ? 10 : 8)
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
            }
        }
    }
}

// MARK: - Slide2VideoPreloader

final class Slide2VideoPreloader: ObservableObject {
    static let shared = Slide2VideoPreloader()
    @Published private(set) var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?

    func preload() {
        guard player == nil,
              let url = Bundle.main.url(forResource: "slide2", withExtension: "mp4", subdirectory: nil) else { return }
        let item = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer(playerItem: item)
        looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        queuePlayer.isMuted = true
        queuePlayer.actionAtItemEnd = .none
        // Store player immediately; preroll requires player to be readyToPlay and can crash if called too early.
        // The player will buffer when created; by the time user reaches slide 2, it's usually ready.
        player = queuePlayer
    }
}
