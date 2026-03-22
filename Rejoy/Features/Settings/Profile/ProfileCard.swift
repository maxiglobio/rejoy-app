import SwiftUI

/// Card background. Light: #f2f2f6, Dark: #2C2C2E (friendlier than pure black).
struct ProfileCard<Content: View>: View {
    @ViewBuilder let content: () -> Content
    private let cornerRadius: CGFloat = 30

    var body: some View {
        content()
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

/// Section header style (20px, gray #8a8a8d).
struct ProfileSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(AppFont.rounded(size: 20, weight: .semibold))
            .foregroundStyle(AppColors.sectionHeader)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
    }
}

/// Divider between rows in grouped cards.
struct ProfileRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppColors.rowDivider)
            .frame(height: 1)
    }
}
