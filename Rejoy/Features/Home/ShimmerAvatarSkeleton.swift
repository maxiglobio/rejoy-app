import SwiftUI

/// Shimmer skeleton for avatar placeholder. Matches SanghaAvatarStrip avatar size.
struct ShimmerAvatarSkeleton: View {
    let size: CGFloat
    @State private var opacity: CGFloat = 0.3

    private let innerSize: CGFloat = 67
    private let outerRingWidth: CGFloat = 2.5
    private let innerRingWidth: CGFloat = 1

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray4), lineWidth: outerRingWidth)
                .frame(width: size, height: size)
            Circle()
                .stroke(Color.white, lineWidth: innerRingWidth)
                .frame(width: innerSize, height: innerSize)
            Circle()
                .fill(AppColors.rejoyOrange.opacity(opacity))
                .frame(width: innerSize, height: innerSize)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                opacity = 0.5
            }
        }
    }
}
