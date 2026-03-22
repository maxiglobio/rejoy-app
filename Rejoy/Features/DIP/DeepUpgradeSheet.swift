import SwiftUI
import UIKit

struct DeepUpgradeSheet: View {
    @Environment(\.appLanguage) private var appLanguage
    @Environment(\.dismiss) private var dismiss
    @State private var isActivating = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(L.string("deep_upgrade_description", language: appLanguage))
                        .font(AppFont.body)
                        .foregroundStyle(.primary)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(L.string("deep_benefits_altar", language: appLanguage))
                            .font(AppFont.body)
                        Text(L.string("deep_benefits_future", language: appLanguage))
                            .font(AppFont.body)
                        Text(L.string("deep_benefits_enhanced", language: appLanguage))
                            .font(AppFont.body)
                    }
                    .padding(.leading, 8)

                    Text(L.string("deep_price_monthly", language: appLanguage))
                        .font(AppFont.title3)
                        .foregroundStyle(.primary)
                        .padding(.top, 8)

                    Spacer(minLength: 24)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        Task {
                            isActivating = true
                            do {
                                try await SupabaseService.shared.activateDeep()
                                await MainActor.run {
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                    dismiss()
                                }
                            } catch {
                                await MainActor.run {
                                    isActivating = false
                                }
                            }
                        }
                    } label: {
                        Text(L.string("activate_deep", language: appLanguage))
                            .font(AppFont.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppColors.rejoyOrange)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(isActivating)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    } label: {
                        Text(L.string("cancel", language: appLanguage))
                            .font(AppFont.body)
                            .foregroundStyle(AppColors.sectionHeader)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }
                .padding(24)
            }
            .background(AppColors.background)
            .navigationTitle(L.string("deep_upgrade_title", language: appLanguage))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
