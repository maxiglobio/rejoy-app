import SwiftUI

/// Loads and caches avatar images for instant display. Uses memory + disk cache.
struct CachedAvatarImage: View {
    let url: URL
    let size: CGFloat
    let placeholder: () -> AnyView

    @State private var loadedImage: UIImage?

    init(url: URL, size: CGFloat = 67, placeholder: @escaping () -> some View) {
        self.url = url
        self.size = size
        self.placeholder = { AnyView(placeholder()) }
    }

    var body: some View {
        if let img = loadedImage ?? AvatarImageCache.image(for: url) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .transition(.opacity)
        } else {
            placeholder()
                .transition(.opacity)
                .task { await loadImage() }
        }
    }

    private func loadImage() async {
        if let cached = AvatarImageCache.image(for: url) {
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.22)) {
                    loadedImage = cached
                }
            }
            return
        }
        let urlsToTry: [URL] = {
            if let thumb = AvatarImageCache.thumbnailURL(for: url) { return [thumb, url] }
            return [url]
        }()
        for tryURL in urlsToTry {
            do {
                let (data, _) = try await AvatarImageCache.sharedAvatarURLSession.data(from: tryURL)
                if let full = UIImage(data: data) {
                    let targetPx = size * UIScreen.main.scale
                    let img = full.size.width > targetPx || full.size.height > targetPx
                        ? resize(full, to: targetPx) : full
                    AvatarImageCache.set(img, for: url)
                    await MainActor.run {
                        withAnimation(.easeOut(duration: 0.22)) {
                            loadedImage = img
                        }
                    }
                    return
                }
            } catch { }
        }
    }

    private func resize(_ image: UIImage, to maxPx: CGFloat) -> UIImage {
        let scale = min(maxPx / image.size.width, maxPx / image.size.height, 1)
        guard scale < 1 else { return image }
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }
}

