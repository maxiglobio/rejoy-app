import SwiftUI
import SwiftData

struct SeedsStatsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var appLanguage
    @Query(sort: \Session.startDate, order: .reverse) private var allSessions: [Session]

    private let monthsToShow = 12
    private let calendar = Calendar.current

    private var monthlyData: [(month: Date, seeds: Int)] {
        var result: [(Date, Int)] = []
        let now = Date()
        guard let startOfCurrentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else { return [] }
        for i in 0..<monthsToShow {
            guard let monthStart = calendar.date(byAdding: .month, value: -i, to: startOfCurrentMonth),
                  let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else { continue }
            let seeds = allSessions
                .filter { $0.startDate >= monthStart && $0.startDate < monthEnd }
                .reduce(0) { $0 + $1.seeds }
            result.append((monthStart, seeds))
        }
        return result
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(monthlyData, id: \.month) { item in
                    HStack {
                        Text(String(format: L.string("seeds_for_month_year_format", language: appLanguage), monthLabel(item.month)))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(item.seeds.formatted(.number))
                            .foregroundStyle(AppColors.dotsSecondaryText)
                    }
                    .listRowBackground(AppColors.listRowBackground)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle(L.string("seeds_stats", language: appLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.string("done", language: appLanguage)) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func monthLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        // LLLL = standalone/nominative month (март, березень) for "Семян за март 2026"
        formatter.dateFormat = "LLLL yyyy"
        formatter.locale = AppLanguage(rawValue: appLanguage)?.locale ?? Locale.current
        return formatter.string(from: date)
    }
}

