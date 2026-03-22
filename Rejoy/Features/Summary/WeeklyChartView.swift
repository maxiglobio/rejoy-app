import SwiftUI
import Charts

struct WeeklyChartView: View {
    let data: [(Date, Double)]

    private var chartData: [(String, Double)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return data.map { (formatter.string(from: $0.0), $0.1) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This Week")
                .font(AppFont.headline)
            if chartData.isEmpty || chartData.allSatisfy({ $0.1 == 0 }) {
                Text("No data yet")
                    .font(AppFont.subheadline)
                    .foregroundStyle(AppColors.dotsSecondaryText)
            } else {
                Chart(chartData, id: \.0) { item in
                    BarMark(
                        x: .value("Day", item.0),
                        y: .value("Minutes", item.1)
                    )
                    .foregroundStyle(AppColors.rejoyOrange.gradient)
                }
                .frame(height: 120)
            }
        }
    }
}
