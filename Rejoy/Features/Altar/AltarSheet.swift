import SwiftUI
import PhotosUI
import AVKit
import UniformTypeIdentifiers
import UIKit

struct AltarSheet: View {
    @Environment(\.appLanguage) private var appLanguage
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var supabaseService = SupabaseService.shared
    @State private var selectedItem: PhotosPickerItem?
    @State private var isUploading = false

    // Frame position from Figma design (440×954): left 135, top 608, size 170×181
    private static let frameLeftRatio: CGFloat = 135 / 440
    private static let frameTopRatio: CGFloat = 608 / 954
    private static let frameWidthRatio: CGFloat = 170 / 440
    private static let frameHeightRatio: CGFloat = 181 / 954

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let frameW = geo.size.width * Self.frameWidthRatio
                let frameH = geo.size.height * Self.frameHeightRatio
                let frameX = geo.size.width * Self.frameLeftRatio
                let frameY = geo.size.height * Self.frameTopRatio

                ZStack {
                    Image("AltarBackground")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .overlay(alignment: .topLeading) {
                            portraitFrameOverlay(width: frameW, height: frameH)
                                .offset(x: frameX, y: frameY)
                        }
                    // Soft gradient at top and bottom to blend edges
                    VStack {
                        LinearGradient(
                            colors: [Color(white: 0.97), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 80)
                        Spacer(minLength: 0)
                        LinearGradient(
                            colors: [Color.clear, Color(white: 0.97)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 80)
                    }
                    .allowsHitTesting(false)
                }
            }
            .background(Color(white: 0.97))
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(L.string("altar_title", language: appLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(white: 0.97), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.string("done", language: appLanguage)) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    }
                }
            }
            .presentationDetents([.large])
            .onAppear {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    guard let item = newItem else {
                        await MainActor.run { selectedItem = nil }
                        return
                    }
                    await MainActor.run { isUploading = true }
                    defer { Task { @MainActor in selectedItem = nil; isUploading = false } }
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
                        // Silently fail for now
                    }
                }
            }
        }
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
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure, .empty:
                        placeholderContent
                    @unknown default:
                        placeholderContent
                    }
                }
                .frame(width: width, height: height)
                .clipped()
            )
        }
    }

    private func portraitFrameOverlay(width: CGFloat, height: CGFloat) -> some View {
        PhotosPicker(
            selection: $selectedItem,
            matching: .any(of: [.images, .videos]),
            label: {
                Group {
                    if let urlString = supabaseService.teacherPortraitURL,
                       let url = URL(string: urlString) {
                        teacherMediaView(url: url, width: width, height: height)
                    } else {
                        placeholderContent
                    }
                }
                .frame(width: width, height: height)
                .clipped()
                .contentShape(Rectangle())
            }
        )
        .buttonStyle(.plain)
        .disabled(isUploading)
    }

    private var placeholderContent: some View {
        VStack(spacing: 8) {
            if isUploading {
                ProgressView()
                    .tint(AppColors.rejoyOrange)
            } else {
                Image(systemName: "person.crop.rectangle")
                    .font(AppFont.rounded(size: 32, weight: .light))
                    .foregroundStyle(AppColors.rejoyOrange.opacity(0.6))
                Text(L.string("add_photo_or_video", language: appLanguage))
                    .font(AppFont.caption2)
                    .foregroundStyle(AppColors.rejoyOrange)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        Group {
            if let player = queuePlayer {
                VideoPlayer(player: player)
                    .allowsHitTesting(false)
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
