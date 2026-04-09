import SwiftUI
import SwiftData
import UIKit

enum ActivityBalanceAggregation {
    static func totalSecondsPerActivity(sessions: [Session]) -> [UUID: Int] {
        var totals: [UUID: Int] = [:]
        for session in sessions {
            totals[session.activityTypeId, default: 0] += session.durationSeconds
        }
        return totals
    }

    struct Row: Identifiable {
        let id: UUID
        let activity: ActivityType
        let totalSeconds: Int
    }

    /// Non-zero rows by descending duration, then zero rows by `sortOrder` (same as activity list).
    static func rows(activityTypes: [ActivityType], totals: [UUID: Int]) -> [Row] {
        let mapped: [Row] = activityTypes.map { type in
            Row(id: type.id, activity: type, totalSeconds: totals[type.id] ?? 0)
        }
        let nonZero = mapped.filter { $0.totalSeconds > 0 }.sorted { $0.totalSeconds > $1.totalSeconds }
        let zero = mapped.filter { $0.totalSeconds == 0 }.sorted { $0.activity.sortOrder > $1.activity.sortOrder }
        return nonZero + zero
    }

    static func maxSecondsForBars(rows: [Row]) -> Int {
        let maxAmong = rows.map(\.totalSeconds).max() ?? 0
        return max(1, maxAmong)
    }
}

struct ActivityBalanceSection: View {
    let sessions: [Session]
    let activityTypes: [ActivityType]
    let appLanguage: String

    @State private var showInfoSheet = false

    private var totals: [UUID: Int] {
        ActivityBalanceAggregation.totalSecondsPerActivity(sessions: sessions)
    }

    private var rows: [ActivityBalanceAggregation.Row] {
        ActivityBalanceAggregation.rows(activityTypes: activityTypes, totals: totals)
    }

    private var maxBarSeconds: Int {
        ActivityBalanceAggregation.maxSecondsForBars(rows: rows)
    }

    private var showEmptyState: Bool {
        activityTypes.isEmpty || sessions.isEmpty || rows.allSatisfy { $0.totalSeconds == 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                Text(L.string("activity_balance_section", language: appLanguage))
                    .font(AppFont.rounded(size: 20, weight: .semibold))
                    .foregroundStyle(AppColors.sectionHeader)
                Spacer(minLength: 8)
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showInfoSheet = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(AppFont.rounded(size: 20, weight: .semibold))
                        .foregroundStyle(AppColors.rejoyOrange)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L.string("activity_balance_info_title", language: appLanguage))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            ProfileCard {
                if showEmptyState {
                    Text(L.string("activity_balance_empty", language: appLanguage))
                        .font(AppFont.rounded(size: 14, weight: .regular))
                        .foregroundStyle(AppColors.sectionHeader)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(rows) { row in
                            activityBalanceRow(row: row, maxSeconds: maxBarSeconds)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showInfoSheet) {
            activityBalanceInfoSheet
        }
    }

    private var activityBalanceInfoSheet: some View {
        NavigationStack {
            ScrollView {
                Text(L.string("activity_balance_info_body", language: appLanguage))
                    .font(AppFont.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(AppColors.background)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(L.string("activity_balance_info_title", language: appLanguage))
                        .font(AppFont.headline)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.88)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.string("done", language: appLanguage)) {
                        showInfoSheet = false
                    }
                }
            }
        }
    }

    private func activityBalanceRow(row: ActivityBalanceAggregation.Row, maxSeconds: Int) -> some View {
        let name = L.activityName(row.activity.name, language: appLanguage)
        let fraction = CGFloat(row.totalSeconds) / CGFloat(maxSeconds)
        let durationText = Self.formatPracticeDuration(seconds: row.totalSeconds, language: appLanguage)
        let isZero = row.totalSeconds == 0

        return HStack(alignment: .center, spacing: 10) {
            Image(systemName: row.activity.symbolName)
                .font(AppFont.rounded(size: 18, weight: .semibold))
                .foregroundStyle(isZero ? AppColors.sectionHeader.opacity(0.55) : AppColors.rejoyOrange)
                .frame(width: 26, alignment: .center)

            VStack(alignment: .leading, spacing: 6) {
                Text(name)
                    .font(AppFont.rounded(size: 15, weight: .semibold))
                    .foregroundStyle(isZero ? AppColors.sectionHeader : .primary)
                    .lineLimit(1)

                GeometryReader { geo in
                    let width = max(2, geo.size.width * fraction)
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppColors.rowDivider.opacity(0.65))
                        Capsule()
                            .fill(AppColors.rejoyOrange.opacity(isZero ? 0.14 : 1))
                            .frame(width: isZero ? 2 : width)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(durationText)
                .font(AppFont.rounded(size: 13, weight: .medium))
                .foregroundStyle(AppColors.sectionHeader)
                .monospacedDigit()
                .frame(minWidth: 56, alignment: .trailing)
        }
    }

    private static func formatPracticeDuration(seconds: Int, language: String) -> String {
        guard seconds > 0 else {
            return L.string("activity_balance_duration_none", language: language)
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = AppLanguage(rawValue: language)?.locale ?? Locale.current
        let formatter = DateComponentsFormatter()
        formatter.calendar = calendar
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: TimeInterval(seconds)) ?? "\(seconds)s"
    }
}
