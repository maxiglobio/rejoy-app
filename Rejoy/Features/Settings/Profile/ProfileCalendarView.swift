import SwiftUI
import SwiftData

/// Day color state for the activity calendar.
enum DayActivityState {
    case empty    // no sessions → gray
    case partial  // sessions exist, not all Rejoyed → orange
    case complete // all sessions Rejoyed → green
}

/// Dot-based activity calendar for the Profile page. Shows Past, Current, and Next month.
struct ProfileCalendarView: View {
    let allSessions: [Session]
    let rejoyedSessionIds: Set<UUID>
    @Binding var visibleMonthStart: Date?
    @Binding var scrollToCurrentTrigger: Bool
    var onDayTapped: ((Date) -> Void)? = nil
    var calendar: Calendar = .current
    @Environment(\.appLanguage) private var appLanguage

    private var todayStart: Date {
        calendar.startOfDay(for: Date())
    }

    private var currentMonthStart: Date? {
        calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))
    }

    private var displayLocale: Locale {
        AppLanguage(rawValue: appLanguage)?.locale ?? Locale.current
    }

    private let dotSize: CGFloat = 15
    private let horizontalSpacing: CGFloat = 22
    private let verticalSpacing: CGFloat = 15
    private let dotCornerRadius: CGFloat = 7

    private static let greenColor = Color(red: 0.196, green: 0.808, blue: 0.373)  // #32ce5f
    private static let orangeColor = AppColors.rejoyOrange
    private static let grayColor = Color(red: 0.169, green: 0.169, blue: 0.18)    // #2b2b2e
    private static let dayLabelColor = Color(red: 0.529, green: 0.529, blue: 0.537)  // #878789

    private var rejoyedIds: Set<UUID> { rejoyedSessionIds }

    @State private var scrollPosition: Date?
    @State private var lastHapticMonth: Date?

    private func state(for date: Date) -> DayActivityState {
        let startOfDay = calendar.startOfDay(for: date)
        let sessions = allSessions.filter {
            SessionDayAttribution.sessionPortion($0, on: startOfDay, calendar: calendar).seconds > 0
        }
        if sessions.isEmpty { return .empty }
        if sessions.allSatisfy({ rejoyedIds.contains($0.id) }) { return .complete }
        return .partial
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 20) {
                    ForEach(displayedMonths, id: \.self) { monthStart in
                        MonthCalendarGrid(
                            monthStart: monthStart,
                            todayStart: todayStart,
                            allSessions: allSessions,
                            rejoyedSessionIds: rejoyedSessionIds,
                            calendar: calendar,
                            locale: displayLocale,
                            dotSize: dotSize,
                            horizontalSpacing: horizontalSpacing,
                            verticalSpacing: verticalSpacing,
                            dotCornerRadius: dotCornerRadius,
                            greenColor: Self.greenColor,
                            orangeColor: Self.orangeColor,
                            grayColor: Self.grayColor,
                            dayLabelColor: Self.dayLabelColor,
                            stateForDate: state(for:),
                            onDayTapped: onDayTapped
                        )
                        .id(monthStart)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 16)
            }
            .scrollPosition(id: $scrollPosition, anchor: .center)
            .scrollTargetBehavior(.viewAligned)
            .onAppear {
                if let current = currentMonthStart {
                    scrollPosition = current
                    visibleMonthStart = current
                }
            }
            .onChange(of: scrollPosition) { _, newMonth in
                if let m = newMonth {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        visibleMonthStart = m
                    }
                    if lastHapticMonth != m {
                        lastHapticMonth = m
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }
            .onChange(of: scrollToCurrentTrigger) { _, triggered in
                if triggered, let current = currentMonthStart {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        scrollPosition = current
                        visibleMonthStart = current
                    }
                    scrollToCurrentTrigger = false
                }
            }
        }
        .frame(minHeight: 180)
    }

    private var displayedMonths: [Date] {
        let now = Date()
        guard let currentStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            return [now]
        }
        var months: [Date] = []
        for i in -6...0 {
            if let m = calendar.date(byAdding: .month, value: i, to: currentStart) {
                months.append(m)
            }
        }
        return months
    }
}

/// Single month grid with day labels and dots.
private struct MonthCalendarGrid: View {
    let monthStart: Date
    let todayStart: Date
    let allSessions: [Session]
    let rejoyedSessionIds: Set<UUID>
    let calendar: Calendar
    let locale: Locale
    let dotSize: CGFloat
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat
    let dotCornerRadius: CGFloat
    let greenColor: Color
    let orangeColor: Color
    let grayColor: Color
    let dayLabelColor: Color
    let stateForDate: (Date) -> DayActivityState
    let onDayTapped: ((Date) -> Void)?

    /// Weekday symbols Mon–Sun for display (localized: en, ru, uk).
    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "EEE"
        guard let monday = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1)) else { return ["M","T","W","T","F","S","S"] }
        return (0..<7).map { i in
            guard let d = calendar.date(byAdding: .day, value: i, to: monday) else { return "" }
            return formatter.string(from: d).uppercased()
        }
    }

    private var numberOfDaysInMonth: Int {
        calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 0
    }

    /// Leading empty cells so the first day aligns with its weekday (Mon=0, Tue=1, …, Sun=6).
    private var firstWeekdayOffset: Int {
        guard let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: monthStart)) else { return 0 }
        let weekday = calendar.component(.weekday, from: firstDay)
        return (weekday - 2 + 7) % 7
    }

    private var cellDates: [Date?] {
        var result: [Date?] = []
        let offset = firstWeekdayOffset
        for _ in 0..<offset {
            result.append(nil)
        }
        for day in 1...numberOfDaysInMonth {
            if let d = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                result.append(d)
            }
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: verticalSpacing) {
            HStack(spacing: horizontalSpacing) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(AppFont.rounded(size: 11, weight: .semibold))
                        .foregroundStyle(dayLabelColor)
                        .frame(width: 26, height: dotSize)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }

            let labelCellWidth: CGFloat = 26
            let rows = stride(from: 0, to: cellDates.count, by: 7).map { Array(cellDates[$0..<min($0 + 7, cellDates.count)]) }

            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: horizontalSpacing) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, dateOpt in
                        let dotView = DayDotView(
                            state: dateOpt.map { stateForDate($0) } ?? .empty,
                            isEmpty: dateOpt == nil,
                            isToday: dateOpt.map { calendar.isDate($0, inSameDayAs: todayStart) } ?? false,
                            isFuture: dateOpt.map { calendar.startOfDay(for: $0) > todayStart } ?? false,
                            size: dotSize,
                            cornerRadius: dotCornerRadius,
                            greenColor: greenColor,
                            orangeColor: orangeColor,
                            grayColor: grayColor
                        )
                        .frame(width: labelCellWidth)

                        if let date = dateOpt, let onTap = onDayTapped {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                onTap(calendar.startOfDay(for: date))
                            } label: {
                                dotView
                            }
                            .buttonStyle(.plain)
                        } else {
                            dotView
                        }
                    }
                }
            }
        }
        .frame(width: 7 * 26 + 6 * horizontalSpacing)
    }
}

/// Single dot cell.
private struct DayDotView: View {
    let state: DayActivityState
    let isEmpty: Bool
    let isToday: Bool
    let isFuture: Bool
    let size: CGFloat
    let cornerRadius: CGFloat
    let greenColor: Color
    let orangeColor: Color
    let grayColor: Color

    @Environment(\.colorScheme) private var colorScheme

    private var fillColor: Color {
        if isEmpty { return .clear }
        switch state {
        case .empty:
            if colorScheme == .light {
                return isFuture
                    ? Color(white: 0.88).opacity(0.55)
                    : Color(white: 0.76)
            }
            return grayColor
        case .partial: return orangeColor
        case .complete: return greenColor
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(fillColor)
            .frame(width: size, height: size)
            .overlay {
                if !isEmpty {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                }
            }
            .overlay {
                if isToday && !isEmpty {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.primary, lineWidth: 2)
                }
            }
    }
}
