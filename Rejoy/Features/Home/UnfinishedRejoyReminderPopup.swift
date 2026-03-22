import SwiftUI
import UIKit

struct UnfinishedRejoyReminderPopup: View {
    let onRejoyNow: () -> Void
    let onLater: () -> Void
    @Environment(\.appLanguage) private var appLanguage
    @State private var appeared = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(AppColors.rejoyOrange.opacity(0.03))
                .ignoresSafeArea()
                .onTapGesture { }

            VStack(spacing: 0) {
                VStack(spacing: 24) {
                    Image(systemName: "leaf.fill")
                        .font(AppFont.rounded(size: 64))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppColors.rejoyOrange, AppColors.rejoyOrange.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(appeared ? 1 : 0.5)

                    VStack(spacing: 8) {
                        Text(L.string("unfinished_rejoy_reminder_title", language: appLanguage))
                            .font(AppFont.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.primary)

                        Text(L.string("unfinished_rejoy_reminder_body", language: appLanguage))
                            .font(AppFont.body)
                            .foregroundStyle(AppColors.dotsSecondaryText)
                            .multilineTextAlignment(.center)
                            .lineLimit(4)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)

                    VStack(spacing: 12) {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            onRejoyNow()
                        } label: {
                            Text(L.string("unfinished_rejoy_reminder_action", language: appLanguage))
                                .font(AppFont.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [.orange, Color.orange.opacity(0.9)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                        }
                        .buttonStyle(.plain)

                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onLater()
                        } label: {
                            Text(L.string("unfinished_rejoy_reminder_skip", language: appLanguage))
                                .font(AppFont.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(AppColors.dotsSecondaryText)
                        }
                        .buttonStyle(.plain)
                    }
                    .opacity(appeared ? 1 : 0)
                }
                .padding(32)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .scaleEffect(appeared ? 1 : 0.85)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                appeared = true
            }
        }
    }
}
