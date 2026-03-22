import SwiftUI
import SwiftData
import UIKit

struct ShareActivitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var appLanguage
    @StateObject private var profileState = ProfileState.shared

    let session: Session
    let activity: ActivityType?
    let isRejoyed: Bool

    @State private var selectedPage = 0
    @State private var isCopied = false

    private let stickerCount = 5

    private var stickerData: StickerData {
        StickerData.from(session: session, activity: activity, isRejoyed: isRejoyed, language: appLanguage, avatarImage: profileState.avatarImage)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stickerPreviewSection
                Spacer(minLength: 0)
                copySection
            }
            .background(AppColors.background)
            .navigationTitle(L.string("share_activity", language: appLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.string("close", language: appLanguage)) {
                        dismiss()
                    }
                }
            }
            .presentationDetents([.height(560)])
        }
    }

    private var stickerCarousel: some View {
        GeometryReader { geo in
            let maxStickerWidth = geo.size.width - 32
            TabView(selection: $selectedPage) {
                stickerPage(StickerV1View(data: stickerData, language: appLanguage), maxWidth: maxStickerWidth, designSize: CGSize(width: 332, height: 130))
                    .tag(0)
                stickerPage(StickerV2View(data: stickerData, language: appLanguage), maxWidth: maxStickerWidth, designSize: CGSize(width: 310, height: 215))
                    .tag(1)
                stickerPage(StickerV3View(data: stickerData, language: appLanguage), maxWidth: maxStickerWidth, designSize: CGSize(width: 258, height: 210))
                    .tag(2)
                stickerPage(StickerV4View(data: stickerData, language: appLanguage), maxWidth: maxStickerWidth, designSize: CGSize(width: 310, height: 215))
                    .tag(3)
                stickerPage(StickerV5View(data: stickerData, language: appLanguage), maxWidth: maxStickerWidth, designSize: CGSize(width: 380, height: 330))
                    .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .frame(height: 280)
        .padding(.top, 24)
        .padding(.bottom, 12)
    }

    private func stickerPage<V: View>(_ view: V, maxWidth: CGFloat, designSize: CGSize) -> some View {
        let maxHeight: CGFloat = 200
        let scaleW = maxWidth / designSize.width
        let scaleH = maxHeight / designSize.height
        let scale = min(1, scaleW, scaleH)
        return HStack {
            Spacer(minLength: 0)
            view
                .frame(width: designSize.width, height: designSize.height)
                .scaleEffect(scale, anchor: .center)
                .frame(width: designSize.width * scale, height: designSize.height * scale)
            Spacer(minLength: 0)
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<stickerCount, id: \.self) { i in
                Circle()
                    .fill(selectedPage == i ? Color.white : Color.white.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    private var stickerPreviewSection: some View {
        VStack(spacing: 0) {
            stickerCarousel
            pageIndicator
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(CheckerboardBackground())
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var copySection: some View {
        VStack(spacing: 16) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                copyToClipboard()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 20))
                    Text(isCopied ? L.string("copied", language: appLanguage) : L.string("copy_image", language: appLanguage))
                        .font(AppFont.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppColors.rejoyOrange)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(isCopied)

            Text(L.string("copy_sticker_hint", language: appLanguage))
                .font(AppFont.footnote)
                .foregroundStyle(AppColors.dotsSecondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 20)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 32)
    }

    @MainActor
    private func currentStickerView() -> some View {
        Group {
            switch selectedPage {
            case 0: StickerV1View(data: stickerData, language: appLanguage)
            case 1: StickerV2View(data: stickerData, language: appLanguage)
            case 2: StickerV3View(data: stickerData, language: appLanguage)
            case 3: StickerV4View(data: stickerData, language: appLanguage)
            default: StickerV5View(data: stickerData, language: appLanguage)
            }
        }
    }

    private func stickerSize(for page: Int) -> CGSize {
        switch page {
        case 0: return CGSize(width: 332, height: 130)
        case 1: return CGSize(width: 310, height: 215)
        case 2: return CGSize(width: 258, height: 210)
        case 3: return CGSize(width: 310, height: 215)
        default: return CGSize(width: 380, height: 330)
        }
    }

    @MainActor
    private func renderCurrentSticker() -> UIImage? {
        let size = stickerSize(for: selectedPage)
        let padding: CGFloat = 16
        let paddedSize = CGSize(width: size.width + padding * 2, height: size.height + padding * 2)
        let view = currentStickerView()
            .frame(width: size.width, height: size.height)
            .padding(padding)
        let imgRenderer = ImageRenderer(content: view)
        imgRenderer.scale = UIScreen.main.scale
        imgRenderer.isOpaque = false
        imgRenderer.proposedSize = ProposedViewSize(paddedSize)

        var resultImage: UIImage?
        imgRenderer.render { renderSize, draw in
            let format = UIGraphicsImageRendererFormat()
            format.opaque = false
            format.scale = UIScreen.main.scale
            let bounds = CGRect(origin: .zero, size: renderSize)
            let uiRenderer = UIGraphicsImageRenderer(bounds: bounds, format: format)
            resultImage = uiRenderer.image { ctx in
                let cgContext = ctx.cgContext
                cgContext.translateBy(x: 0, y: renderSize.height)
                cgContext.scaleBy(x: 1, y: -1)
                draw(cgContext)
            }
        }
        return resultImage
    }

    private func copyToClipboard() {
        guard let image = renderCurrentSticker(),
              let pngData = image.pngData() else { return }
        UIPasteboard.general.setData(pngData, forPasteboardType: "public.png")
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        isCopied = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run { isCopied = false }
        }
    }
}

private struct CheckerboardBackground: View {
    private let squareSize: CGFloat = 8
    private let darkColor = Color(red: 0.10, green: 0.10, blue: 0.11)
    private let lightColor = Color(red: 0.16, green: 0.16, blue: 0.17)

    var body: some View {
        Canvas { context, size in
            let cols = Int(ceil(size.width / squareSize)) + 1
            let rows = Int(ceil(size.height / squareSize)) + 1
            for row in 0..<rows {
                for col in 0..<cols {
                    let rect = CGRect(
                        x: CGFloat(col) * squareSize,
                        y: CGFloat(row) * squareSize,
                        width: squareSize,
                        height: squareSize
                    )
                    let color = (row + col) % 2 == 0 ? darkColor : lightColor
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}
