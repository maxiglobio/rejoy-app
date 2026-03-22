import SwiftUI
import PhotosUI

struct ProfileAvatarView: View {
    @ObservedObject var profileState: ProfileState
    var size: CGFloat = 100

    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            ZStack {
                if let image = profileState.avatarImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(AppColors.rejoyOrange.opacity(0.2))
                        .frame(width: size, height: size)
                    let initials = ProfileState.initials()
                    if initials == "?" {
                        Image(systemName: "person.circle.fill")
                            .font(AppFont.rounded(size: size * 0.6))
                            .foregroundStyle(AppColors.rejoyOrange)
                    } else {
                        Text(initials)
                            .font(AppFont.rounded(size: size * 0.4, weight: .semibold))
                            .foregroundStyle(AppColors.rejoyOrange)
                    }
                }
                Circle()
                    .stroke(AppColors.rejoyOrange.opacity(0.5), lineWidth: 2)
                    .frame(width: size, height: size)
            }
        }
        .buttonStyle(.plain)
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        profileState.saveAvatar(image)
                    }
                    if SupabaseService.shared.isSignedIn {
                        try? await SupabaseService.shared.uploadProfileAvatar(image)
                    }
                }
                await MainActor.run {
                    selectedItem = nil
                }
            }
        }
    }
}
