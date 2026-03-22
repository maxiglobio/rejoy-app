import SwiftUI
import UIKit

struct AchievementPopupView: View {
    let achievement: Achievement
    var unlockedAt: Date? = nil
    let onDismiss: () -> Void
    @Environment(\.appLanguage) private var appLanguage
    @State private var appeared = false

    private var displayedUnlockDate: Date? {
        unlockedAt ?? AchievementService.unlockDate(for: achievement.id)
    }

    var body: some View {
        ZStack {
            // Soft frosted backdrop — warmer and less flat than solid gray
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(AppColors.rejoyOrange.opacity(0.03))
                .ignoresSafeArea()
                .onTapGesture { }

            VStack(spacing: 0) {
                // Card
                ZStack {
                    VStack(spacing: 24) {
                        // Top: Unlocked + Date
                        VStack(spacing: 4) {
                            Text(L.string("achievement_unlocked", language: appLanguage))
                                .font(AppFont.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppColors.rejoyOrange)
                                .textCase(.uppercase)
                                .tracking(1.2)
                                .opacity(appeared ? 1 : 0)

                            if let date = displayedUnlockDate {
                                Text(date, style: .date)
                                    .font(AppFont.caption)
                                    .foregroundStyle(AppColors.rejoyOrange)
                                    .opacity(appeared ? 1 : 0)
                            } else {
                                Text(L.string("rewards_unlock_date_unknown", language: appLanguage))
                                    .font(AppFont.caption)
                                    .foregroundStyle(AppColors.rejoyOrange.opacity(0.85))
                                    .opacity(appeared ? 1 : 0)
                            }
                        }

                        // Hexagon badge (same as profile, larger, with shimmer)
                        AchievementBadgeView(achievement: achievement, showTitle: false, size: 160, shimmer: true)
                            .scaleEffect(appeared ? 1 : 0.5)

                        // Title + Description
                        VStack(spacing: 8) {
                            Text(achievement.title(for: appLanguage))
                                .font(AppFont.title)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.primary)

                            Text(achievement.description(for: appLanguage))
                                .font(AppFont.body)
                                .foregroundStyle(AppColors.dotsSecondaryText)
                                .multilineTextAlignment(.center)
                                .lineLimit(4)
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .scaleEffect(appeared ? 1 : 0.85)
                }

                // Done button
                Button {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    onDismiss()
                } label: {
                    Text(L.string("achievement_save", language: appLanguage))
                        .font(AppFont.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [AppColors.rejoyOrange, AppColors.rejoyOrange.opacity(0.9)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                appeared = true
            }
        }
    }
}
