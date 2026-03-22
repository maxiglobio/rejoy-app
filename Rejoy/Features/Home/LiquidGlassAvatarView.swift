import SwiftUI
import UIKit

/// Avatar with Apple Fitness–style liquid glass effect: frosted spherical overlay with subtle highlight.
struct LiquidGlassAvatarView: View {
    @ObservedObject var profileState: ProfileState
    var size: CGFloat = 36
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap?()
        } label: {
            ZStack {
                avatarContent
                    .frame(width: size, height: size)
                    .clipShape(Circle())

                // Liquid glass: subtle frosted spherical overlay
                Circle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.55)
                    .frame(width: size, height: size)

                // Convex highlight (top-left light reflection, glass bead effect)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.6),
                                Color.white.opacity(0.2),
                                Color.clear
                            ],
                            center: UnitPoint(x: 0.3, y: 0.3),
                            startRadius: 0,
                            endRadius: size * 0.7
                        )
                    )
                    .blendMode(.overlay)
                    .frame(width: size, height: size)

                // Subtle inner edge highlight
                Circle()
                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
                    .frame(width: size, height: size)
            }
            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var avatarContent: some View {
        if let image = profileState.avatarImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Circle()
                    .fill(AppColors.rejoyOrange.opacity(0.2))
                let initials = ProfileState.initials()
                if initials == "?" {
                    Image(systemName: "person.circle.fill")
                        .font(AppFont.rounded(size: size * 0.55))
                        .foregroundStyle(AppColors.rejoyOrange)
                } else {
                    Text(initials)
                        .font(AppFont.rounded(size: size * 0.4, weight: .semibold))
                        .foregroundStyle(AppColors.rejoyOrange)
                }
            }
        }
    }
}

#Preview {
    LiquidGlassAvatarView(profileState: ProfileState.shared, size: 44)
        .padding()
}
