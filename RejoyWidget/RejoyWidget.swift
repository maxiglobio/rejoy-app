import WidgetKit
import SwiftUI

struct RejoyWidget: Widget {
    let kind: String = "RejoyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            RejoyWidgetView(entry: entry)
        }
        .configurationDisplayName("Rejoy Seeds")
        .description("See your seeds planted today at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> RejoyEntry {
        RejoyEntry(date: Date(), seeds: 1950, minutes: 30)
    }

    func getSnapshot(in context: Context, completion: @escaping (RejoyEntry) -> Void) {
        let seeds = WidgetSharedData.todaySeeds
        let minutes = WidgetSharedData.todayMinutes
        completion(RejoyEntry(date: Date(), seeds: seeds, minutes: minutes))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RejoyEntry>) -> Void) {
        let seeds = WidgetSharedData.todaySeeds
        let minutes = WidgetSharedData.todayMinutes
        let entry = RejoyEntry(date: Date(), seeds: seeds, minutes: minutes)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct RejoyEntry: TimelineEntry {
    let date: Date
    let seeds: Int
    let minutes: Int
}

struct RejoyWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: RejoyEntry

    private let dotsPerHour = 24
    private let maxMinutes = 24 * 60    // 24h max
    private var maxDots: Int { family == .systemSmall ? 28 : 48 }

    private var dotCount: Int {
        let cappedMinutes = min(entry.minutes, maxMinutes)
        return max(0, min(maxDots, cappedMinutes * dotsPerHour / 60))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Seeds count
            Text("\(entry.seeds)")
                .font(.system(size: family == .systemSmall ? 26 : 32, weight: .bold))
                .foregroundStyle(.primary)

            Text("seeds planted")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 6)

            // Dots (particles) – like the app's jar
            dotGrid
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(16)
        .containerBackground(for: .widget) {
            AppColors.rejoyOrange.opacity(0.12)
        }
        .widgetURL(URL(string: "rejoy://home"))
    }

    private var dotGrid: some View {
        let dotSize: CGFloat = family == .systemSmall ? 4 : 5
        let cols = family == .systemSmall ? 8 : 10
        let baseSpacing: CGFloat = family == .systemSmall ? 8 : 9

        return ZStack(alignment: .topLeading) {
            ForEach(0..<dotCount, id: \.self) { i in
                let col = i % cols
                let row = i / cols
                // Chaotic jitter: deterministic but scattered like seeds in a jar
                let jitterX = CGFloat(((i * 7 + 3) % 11) - 5) * 1.5
                let jitterY = CGFloat(((i * 13 + 5) % 9) - 4) * 1.5
                Circle()
                    .fill(AppColors.rejoyOrange)
                    .frame(width: dotSize, height: dotSize)
                    .offset(
                        x: CGFloat(col) * baseSpacing + jitterX,
                        y: CGFloat(row) * (baseSpacing - 1) + jitterY
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

#Preview(as: .systemSmall) {
    RejoyWidget()
} timeline: {
    RejoyEntry(date: .now, seeds: 1950, minutes: 30)
}
