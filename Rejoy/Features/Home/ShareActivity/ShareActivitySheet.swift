import SwiftUI
import SwiftData
import UIKit

// MARK: - Embedded sticker + copy (session detail, share sheet)

/// Sticker carousel, copy control, and full hint — used on the session page and in the share sheet.
struct ActivityStickerSharePanel: View {
    @Environment(\.appLanguage) private var appLanguage
    @StateObject private var profileState = ProfileState.shared

    let session: Session
    let activity: ActivityType?
    let isRejoyed: Bool
    /// When true (e.g. share sheet), inserts a flexible spacer so the Copy block sits toward the bottom.
    var separateCopyWithSpacer: Bool = false
    /// When embedded in `List` (session detail), omit extra horizontal padding so the checkerboard matches other sections’ width.
    var listEmbedded: Bool = false

    @State private var selectedPage = 0
    @State private var isCopied = false

    private let stickerCount = 5

    private var stickerData: StickerData {
        StickerData.from(session: session, activity: activity, isRejoyed: isRejoyed, language: appLanguage, avatarImage: profileState.avatarImage)
    }

    private var horizontalGutter: CGFloat { listEmbedded ? 0 : 16 }
    /// Inner padding inside the checkerboard; list rows use 0 so the chess area matches Time / Dedication width.
    private var stickerPreviewInnerHorizontal: CGFloat { listEmbedded ? 0 : 16 }
    /// Inner checkerboard corners; list row uses the same system grouped cell as Dedication / Time when embedded.
    private var checkerboardCornerRadius: CGFloat { listEmbedded ? 12 : 20 }

    var body: some View {
        VStack(spacing: 0) {
            stickerPreviewSection
            if separateCopyWithSpacer {
                Spacer(minLength: 0)
            }
            copySection
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: separateCopyWithSpacer ? .infinity : nil)
    }

    private var stickerCarousel: some View {
        GeometryReader { geo in
            // Page-style TabView adds ~12–16pt horizontal inset per side; pull pages flush so the card matches Dedication width.
            let pageHorizontalPull: CGFloat = listEmbedded ? 14 : 0
            let maxStickerWidth = geo.size.width + (listEmbedded ? pageHorizontalPull * 2 : 0) - (listEmbedded ? 0 : 32)
            TabView(selection: $selectedPage) {
                stickerPage(StickerV1View(data: stickerData, language: appLanguage), maxWidth: maxStickerWidth, designSize: CGSize(width: 332, height: 130), maxHeight: 108)
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
            .padding(.horizontal, listEmbedded ? -pageHorizontalPull : 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private func stickerPage<V: View>(_ view: V, maxWidth: CGFloat, designSize: CGSize, maxHeight: CGFloat = 132) -> some View {
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
        .padding(.horizontal, listEmbedded ? 0 : 24)
        .padding(.bottom, 8)
    }

    private var stickerPreviewSection: some View {
        VStack(spacing: 0) {
            stickerCarousel
            pageIndicator
        }
        .padding(.vertical, 6)
        .padding(.horizontal, stickerPreviewInnerHorizontal)
        .frame(maxWidth: .infinity)
        .background(CheckerboardBackground())
        .clipShape(RoundedRectangle(cornerRadius: checkerboardCornerRadius, style: .continuous))
        .padding(.horizontal, horizontalGutter)
        // Match vertical breathing room with other grouped cells (Dedication has comfortable top inset).
        .padding(.top, listEmbedded ? 12 : 4)
    }

    private var copySection: some View {
        VStack(spacing: 10) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                copyToClipboard()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 16, weight: .semibold))
                    Text(isCopied ? L.string("copied", language: appLanguage) : L.string("copy_badge", language: appLanguage))
                        .font(AppFont.rounded(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(AppColors.rejoyOrange)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(isCopied)

            Text(L.string("copy_sticker_hint", language: appLanguage))
                .font(AppFont.footnote)
                .foregroundStyle(AppColors.dotsSecondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        }
        .padding(.horizontal, horizontalGutter)
        .padding(.top, listEmbedded ? 12 : 10)
        .padding(.bottom, listEmbedded ? 4 : 4)
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

// MARK: - Sheet wrapper

struct ShareActivitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var appLanguage

    let session: Session
    let activity: ActivityType?
    let isRejoyed: Bool

    var body: some View {
        NavigationStack {
            ActivityStickerSharePanel(session: session, activity: activity, isRejoyed: isRejoyed, separateCopyWithSpacer: true)
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
