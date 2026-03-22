import ActivityKit
import WidgetKit
import SwiftUI

struct RejoyTrackingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RejoyTrackingAttributes.self) { context in
            // Lock screen / banner UI – run tracker style
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: context.attributes.symbolName)
                        .font(.title2)
                        .foregroundStyle(AppColors.rejoyOrange)
                    Text(context.attributes.activityName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                }

                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formattedTime(context.state.elapsedSeconds))
                            .font(.system(size: 28, weight: .light, design: .monospaced))
                        Text("Time")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(context.state.seeds)")
                            .font(.system(size: 28, weight: .light, design: .monospaced))
                        Text("Seeds")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
            }
            .padding(16)
            .containerBackground(for: .widget) {
                AppColors.rejoyOrange.opacity(0.15)
            }
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.attributes.symbolName)
                        .foregroundStyle(AppColors.rejoyOrange)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(formattedTime(context.state.elapsedSeconds))
                        .font(.system(.body, design: .monospaced))
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.activityName)
                        .font(.subheadline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(context.state.seeds) seeds")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: context.attributes.symbolName)
                    .foregroundStyle(AppColors.rejoyOrange)
            } compactTrailing: {
                Text(formattedTime(context.state.elapsedSeconds))
                    .font(.system(.caption, design: .monospaced))
            } minimal: {
                Image(systemName: context.attributes.symbolName)
                    .foregroundStyle(AppColors.rejoyOrange)
            }
        }
    }

    private func formattedTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h >= 1 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
}
