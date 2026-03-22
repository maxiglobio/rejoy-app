import SwiftUI
import UIKit
import AVKit

// Figma: exact sizes and colors from node 40022939:7634
private let introOrange = AppColors.rejoyOrange
private let subtitleGray = Color(red: 0x89/255, green: 0x89/255, blue: 0x8b/255)
private let horizontalPadding: CGFloat = 33
private let visualWidth: CGFloat = 375
private let visualHeight: CGFloat = 539
private let visualTop: CGFloat = 48  // Push composition down to fill bottom space
private let visualToTextGap: CGFloat = 56  // Figma: gap between visual and text+button block
private let bottomPadding: CGFloat = 43
private let bottomContentGap: CGFloat = 24
private let titleSubtitleGap: CGFloat = 12
private let titleSize: CGFloat = 30
private let subtitleSize: CGFloat = 20
private let continueButtonSize: CGFloat = 76
private let paginationWidth: CGFloat = 139
private let paginationHeight: CGFloat = 11

/// Intro carousel matching Figma design exactly: placements, sizes, layout.
struct IntroCarouselView: View {
    let onComplete: () -> Void
    @Environment(\.appLanguage) private var appLanguage
    @ObservedObject private var slide2Preloader = Slide2VideoPreloader.shared

    @State private var currentPage = 0
    private let slides = StoryItem.all

    var body: some View {
        GeometryReader { geo in
            let contentWidth = min(visualWidth, geo.size.width - horizontalPadding * 2)
            let scale = contentWidth / visualWidth

            ZStack {
                AppColors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Visual: 375x539, horizontal 33pt — fade transition instead of slide
                    ZStack {
                        slidePage(slide: slides[currentPage], index: currentPage)
                    }
                    .frame(width: contentWidth, height: visualHeight * scale)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, visualTop)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 50)
                            .onEnded { value in
                                if value.translation.width < -50 {
                                    goNextPage()
                                } else if value.translation.width > 50 {
                                    goPreviousPage()
                                }
                            }
                    )
                    .id(currentPage)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: currentPage)
                    .onChange(of: currentPage) { _, _ in
                        UISelectionFeedbackGenerator().selectionChanged()
                    }

                    // Figma: gap-[56px] between visual and text block
                    Color.clear
                        .frame(height: visualToTextGap)

                    // Title + subtitle — variable height
                    VStack(alignment: .leading, spacing: titleSubtitleGap) {
                        Text(L.string(slides[currentPage].titleKey, language: appLanguage))
                            .font(AppFont.rounded(size: titleSize, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Text(L.string(slides[currentPage].subtitleKey, language: appLanguage))
                            .font(AppFont.rounded(size: subtitleSize, weight: .medium))
                            .foregroundStyle(subtitleGray)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(width: contentWidth)
                    .padding(.horizontal, horizontalPadding)

                    // Spacer absorbs variable text height — keeps pagination+button pinned to bottom
                    Spacer(minLength: bottomContentGap)

                    // Pagination (left) + Continue button (right) — always at bottom
                    HStack {
                        paginationDots
                            .frame(width: paginationWidth, height: paginationHeight)

                        Spacer(minLength: 0)

                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            goNextPage()
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(AppFont.rounded(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: continueButtonSize, height: continueButtonSize)
                                .background(introOrange)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(width: contentWidth)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, bottomPadding)
                }
            }
        }
        .onAppear {
            slide2Preloader.preload()
        }
    }

    private func goNextPage() {
        guard currentPage < slides.count - 1 else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onComplete()
            return
        }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentPage += 1
        }
    }

    private func goPreviousPage() {
        guard currentPage > 0 else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentPage -= 1
        }
    }

    private func slidePage(slide: StoryItem, index: Int) -> some View {
        Group {
            if let videoName = slide.videoName {
                ExplainerVideoPlayer(
                    videoName: videoName,
                    isActive: currentPage == index,
                    preloadedPlayer: videoName == "slide2" ? slide2Preloader.player : nil,
                    useTransparentBackground: true
                )
            } else {
                Image(slide.imageName)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 40))
    }

    private var paginationDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<slides.count, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? introOrange : Color.primary.opacity(0.25))
                    .frame(width: index == currentPage ? 10 : 8, height: index == currentPage ? 10 : 8)
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
            }
        }
    }
}
