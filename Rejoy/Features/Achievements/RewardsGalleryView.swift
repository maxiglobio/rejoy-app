import SwiftUI
import UIKit

/// Full-screen grid of all catalog rewards (locked + unlocked), catalog order.
struct RewardsGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var appLanguage

    @State private var sortedCatalog: [Achievement] = []
    @State private var unlockedIds: Set<UUID> = []
    @State private var selectedAchievement: Achievement?
    @State private var selectedUnlockedAt: Date?
    @State private var showExplainer = false

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    private var totalCount: Int { sortedCatalog.count }
    private var unlockedCount: Int { unlockedIds.count }

    private var progressLine: String {
        let loc = AppLanguage(rawValue: appLanguage)?.locale ?? Locale.current
        return String(
            format: L.string("rewards_achieved_progress", language: appLanguage),
            locale: loc,
            arguments: [unlockedCount, totalCount]
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(progressLine)
                    .font(AppFont.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(AppColors.sectionHeader)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(sortedCatalog) { achievement in
                            let isUnlocked = unlockedIds.contains(achievement.id)
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                if isUnlocked {
                                    selectedAchievement = achievement
                                    selectedUnlockedAt = AchievementService.unlockDate(for: achievement.id)
                                }
                            } label: {
                                galleryCell(achievement: achievement, isUnlocked: isUnlocked)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle(L.string("rewards_gallery_title", language: appLanguage))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L.string("done", language: appLanguage)) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showExplainer = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .accessibilityLabel(L.string("rewards_explainer_title", language: appLanguage))
                }
            }
            .task {
                await AchievementService.syncCountsFromSupabase()
                sortedCatalog = AchievementService.catalogSortedForDisplay()
                unlockedIds = AchievementService.unlockedAchievementIds()
            }
            .sheet(isPresented: $showExplainer) {
                rewardsExplainerSheet
            }
            .sheet(item: $selectedAchievement) { achievement in
                AchievementPopupView(achievement: achievement, unlockedAt: selectedUnlockedAt) {
                    selectedAchievement = nil
                    selectedUnlockedAt = nil
                }
            }
        }
    }

    @ViewBuilder
    private func galleryCell(achievement: Achievement, isUnlocked: Bool) -> some View {
        VStack(spacing: 6) {
            AchievementBadgeView(
                achievement: achievement,
                count: isUnlocked ? max(1, AchievementService.unlockCount(for: achievement.id)) : 1,
                showTitle: false,
                size: 76,
                shimmer: false,
                isLocked: !isUnlocked
            )
            if isUnlocked {
                Text(unlockSubtitle(for: achievement.id))
                    .font(AppFont.rounded(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Color.clear.frame(height: 14)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func unlockDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = AppLanguage(rawValue: appLanguage)?.locale ?? Locale.current
        return formatter.string(from: date)
    }

    /// Shown under earned badges when we have no stored date (legacy data, or not yet merged from the server).
    private func unlockSubtitle(for achievementId: UUID) -> String {
        if let date = AchievementService.unlockDate(for: achievementId) {
            return unlockDateString(date)
        }
        return L.string("rewards_unlock_date_unknown", language: appLanguage)
    }

    private var rewardsExplainerSheet: some View {
        NavigationStack {
            ScrollView {
                Text(L.string("rewards_explainer_body", language: appLanguage))
                    .font(AppFont.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(L.string("rewards_explainer_title", language: appLanguage))
                        .font(AppFont.headline)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.88)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.string("done", language: appLanguage)) {
                        showExplainer = false
                    }
                }
            }
        }
    }
}
