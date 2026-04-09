import SwiftUI

struct SettingsRow: View {
    let icon: String
    let title: String
    var trailingValue: String? = nil
    var showChevron: Bool = true

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(AppFont.rounded(size: 20, weight: .medium))
                .foregroundStyle(Color(red: 1, green: 0.45, blue: 0.008))
                .frame(width: 28)
            Text(title)
                .font(AppFont.rounded(size: 18, weight: .regular))
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
            if let value = trailingValue {
                Text(value)
                    .font(AppFont.rounded(size: 16, weight: .medium))
                    .foregroundStyle(AppColors.trailing)
            }
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(AppFont.rounded(size: 16, weight: .medium))
                    .foregroundStyle(AppColors.trailing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
