import SwiftUI
import PhotosUI
import AVKit
import UniformTypeIdentifiers
import UIKit

/// Shared altar scene: `AltarForeground` is drawn first; teacher media is **above** it, aligned to the inner mat (opaque PNG).
struct AltarEditorContent: View {
    @Environment(\.appLanguage) private var appLanguage
    @ObservedObject private var supabaseService = SupabaseService.shared
    @ObservedObject private var offeringState = OfferingBowlsState.shared
    @State private var selectedItem: PhotosPickerItem?
    /// Forces `PhotosPicker` to treat the next pick as new (same library asset can reuse item identity).
    @State private var photosPickerIdentity = UUID()
    @State private var isUploading = false
    /// Signed or public URL suitable for `AsyncImage` / video (see `SupabaseService.resolvedTeacherMediaURL()`).
    @State private var resolvedMediaURL: URL?

    /// Pixel size of `AltarForeground` / `altar_foreground.png` in the asset catalog.
    private static let altarSourceSize = CGSize(width: 1024, height: 965)

    /// Inner white mat — normalized (0…1) in altar image space; calibrated for 1024×965 art.
    private static let teacherPortraitNormalizedInSource = CGRect(x: 0.349, y: 0.201, width: 0.302, height: 0.38)

    /// Pushes the altar + portrait down slightly under the nav/segmented control.
    private static let altarContentTopOffset: CGFloat = 32

    /// Horizontal inset for the bowls section so it lines up with the main altar art.
    private static let bowlsHorizontalPadding: CGFloat = 0

    private var altarForegroundAssetName: String {
        offeringState.filled.allSatisfy { $0 } ? "AltarForegroundActivated" : "AltarForeground"
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    altarMainSection(width: w)
                        .frame(width: w)
                    AltBowlsShelvesView(contentWidth: w - Self.bowlsHorizontalPadding * 2)
                        .padding(.horizontal, Self.bowlsHorizontalPadding)
                        .padding(.top, -68)
                        .padding(.bottom, 0)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .task(id: "\(supabaseService.teacherPortraitURL ?? "")-\(supabaseService.teacherPortraitRevision)") {
            resolvedMediaURL = await supabaseService.resolvedTeacherMediaURL()
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                guard let item = newItem else {
                    await MainActor.run { selectedItem = nil }
                    return
                }
                await MainActor.run { isUploading = true }
                defer { Task { @MainActor in
                    selectedItem = nil
                    isUploading = false
                    photosPickerIdentity = UUID()
                } }
                do {
                    let isVideo = item.supportedContentTypes.contains { type in
                        type.conforms(to: .movie) || type.conforms(to: .video)
                    }
                    if isVideo {
                        guard let video = try await item.loadTransferable(type: VideoTransferable.self) else {
                            return
                        }
                        let data = try Data(contentsOf: video.url)
                        let ext = video.url.pathExtension.lowercased().isEmpty ? "mp4" : video.url.pathExtension.lowercased()
                        let mime = ext == "mov" ? "video/quicktime" : "video/mp4"
                        try await supabaseService.uploadTeacherMedia(data: data, contentType: mime, pathExtension: ext)
                        try? FileManager.default.removeItem(at: video.url)
                    } else {
                        guard let data = try await item.loadTransferable(type: Data.self),
                              let image = UIImage(data: data) else {
                            return
                        }
                        try await supabaseService.uploadTeacherPortrait(image)
                    }
                    await MainActor.run {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                } catch {
                    // Best-effort; errors surfaced elsewhere if needed
                }
            }
        }
    }

    /// Main altar + teacher portrait + picker (scrolls with offerings below).
    @ViewBuilder
    private func altarMainSection(width: CGFloat) -> some View {
        let fitted = Self.fittedAltarImageRect(forWidth: width)
        let portraitRect = Self.teacherPortraitRect(forWidth: width)
        let blockHeight = fitted.minY + fitted.height

        ZStack(alignment: .topLeading) {
            Color.white

            ZStack(alignment: .topLeading) {
                Image(altarForegroundAssetName)
                    .resizable()
                    .frame(width: fitted.width, height: fitted.height)
                    .offset(x: fitted.minX, y: fitted.minY)
                    .allowsHitTesting(false)

                teacherPortraitFill(width: portraitRect.width, height: portraitRect.height)
                    .frame(width: portraitRect.width, height: portraitRect.height)
                    .clipped()
                    .offset(x: portraitRect.minX, y: portraitRect.minY)

                PhotosPicker(
                    selection: $selectedItem,
                    matching: .any(of: [.images, .videos]),
                    label: {
                        Color.clear
                            .frame(width: portraitRect.width, height: portraitRect.height)
                            .contentShape(Rectangle())
                    }
                )
                .id(photosPickerIdentity)
                .buttonStyle(.plain)
                .disabled(isUploading)
                .offset(x: portraitRect.minX, y: portraitRect.minY)
            }

            LinearGradient(
                colors: [Color.white, Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 48)
            .allowsHitTesting(false)
        }
        .frame(width: width, height: blockHeight, alignment: .topLeading)
    }

    /// Full-width altar bitmap height from width only (scroll view handles vertical overflow).
    private static func fittedAltarImageRect(forWidth width: CGFloat) -> CGRect {
        let iw = altarSourceSize.width
        let ih = altarSourceSize.height
        guard iw > 0, ih > 0, width > 0 else { return .zero }
        let scale = width / iw
        let w = width
        let h = ih * scale
        let y = altarContentTopOffset
        return CGRect(x: 0, y: y, width: w, height: h)
    }

    private static func teacherPortraitRect(forWidth width: CGFloat) -> CGRect {
        let fitted = fittedAltarImageRect(forWidth: width)
        let n = teacherPortraitNormalizedInSource
        return CGRect(
            x: fitted.minX + n.origin.x * fitted.width,
            y: fitted.minY + n.origin.y * fitted.height,
            width: n.width * fitted.width,
            height: n.height * fitted.height
        )
    }

    @ViewBuilder
    private func teacherPortraitFill(width: CGFloat, height: CGFloat) -> some View {
        Group {
            if let url = resolvedMediaURL {
                teacherMediaView(url: url, width: width, height: height)
                    .id("\(url.absoluteString)-\(supabaseService.teacherPortraitRevision)")
            } else if supabaseService.teacherPortraitURL != nil {
                teacherPortraitLoadingView()
            } else {
                teacherPortraitEmptyView()
            }
        }
    }

    /// Resolving signed URL or waiting on network — distinct from “add photo” empty.
    private func teacherPortraitLoadingView() -> some View {
        VStack(spacing: 10) {
            ProgressView()
                .tint(AppColors.rejoyOrange)
                .controlSize(.regular)
            Text(L.string("altar_teacher_loading", language: appLanguage))
                .font(AppFont.caption)
                .foregroundStyle(AppColors.rejoyOrange.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.96))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L.string("altar_teacher_loading", language: appLanguage))
    }

    private func teacherMediaView(url: URL, width: CGFloat, height: CGFloat) -> some View {
        let ext = url.pathExtension.lowercased()
        if ext == "mp4" || ext == "mov" {
            return AnyView(
                LoopingVideoPlayer(url: url)
                    .frame(width: width, height: height)
                    .clipped()
            )
        } else {
            return AnyView(
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        teacherPortraitLoadingView()
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        teacherPortraitLoadFailedView()
                    @unknown default:
                        teacherPortraitLoadingView()
                    }
                }
                .frame(width: width, height: height)
                .clipped()
            )
        }
    }

    private func teacherPortraitLoadFailedView() -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(AppFont.rounded(size: 28, weight: .regular))
                .foregroundStyle(AppColors.rejoyOrange.opacity(0.7))
            Text(L.string("altar_teacher_load_failed", language: appLanguage))
                .font(AppFont.caption2)
                .foregroundStyle(AppColors.rejoyOrange.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.96))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L.string("altar_teacher_load_failed", language: appLanguage))
    }

    /// No portrait saved — prompt to add (or upload in progress).
    private func teacherPortraitEmptyView() -> some View {
        VStack(spacing: 8) {
            if isUploading {
                ProgressView()
                    .tint(AppColors.rejoyOrange)
                Text(L.string("altar_teacher_loading", language: appLanguage))
                    .font(AppFont.caption2)
                    .foregroundStyle(AppColors.rejoyOrange.opacity(0.85))
            } else {
                Image(systemName: "person.crop.rectangle")
                    .font(AppFont.rounded(size: 32, weight: .light))
                    .foregroundStyle(AppColors.rejoyOrange.opacity(0.6))
                Text(L.string("add_photo_or_video", language: appLanguage))
                    .font(AppFont.caption2)
                    .foregroundStyle(AppColors.rejoyOrange)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.96))
    }
}

// MARK: - Video Transferable (required for loading videos from PhotosPicker)

private struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension.isEmpty ? "mp4" : received.file.pathExtension)
            if FileManager.default.fileExists(atPath: copy.path) {
                try FileManager.default.removeItem(at: copy)
            }
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self(url: copy)
        }
    }
}

// MARK: - Looping Video Player

private struct LoopingVideoPlayer: View {
    let url: URL
    @State private var queuePlayer: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?

    var body: some View {
        ZStack {
            Color(white: 0.96)
            if let player = queuePlayer {
                VideoPlayer(player: player)
                    .allowsHitTesting(false)
            } else {
                ProgressView()
                    .tint(AppColors.rejoyOrange)
            }
        }
        .onAppear {
            let item = AVPlayerItem(url: url)
            let player = AVQueuePlayer(playerItem: item)
            player.isMuted = true
            let loop = AVPlayerLooper(player: player, templateItem: item)
            player.play()
            queuePlayer = player
            looper = loop
        }
        .onDisappear {
            queuePlayer?.pause()
            queuePlayer = nil
            looper = nil
        }
    }
}
