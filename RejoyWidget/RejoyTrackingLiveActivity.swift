import ActivityKit
import WidgetKit
import SwiftUI

/// Lock screen / Dynamic Island must use SwiftUI-only views. `UIViewRepresentable` (e.g. `UILabel`) can render as a placeholder / “no” glyph on the lock screen.
/// Time uses system `Text(timerInterval:)`; seeds use `seedsSnapshot` from each `Activity.update` (~1 Hz while the app session timer is running).
///
/// **Always-On Display:** For running timers, iOS often replaces the seconds digit with `--` on AOD to save power (same idea as Apple’s Timer live activity). Full MM:SS returns when the screen is fully awake.
struct RejoyTrackingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RejoyTrackingAttributes.self) { activityContext in
            lockScreenBody(activityContext)
        } dynamicIsland: { activityContext in
            dynamicIslandBody(activityContext)
        }
    }

    @ViewBuilder
    private func lockScreenBody(_ context: ActivityViewContext<RejoyTrackingAttributes>) -> some View {
        let state = context.state
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

            if state.isPaused {
                pausedStatsRow(state: state)
            } else {
                runningStatsRow(state: state)
            }
        }
        .padding(16)
        // System accessory background reads as neutral on the lock screen; a tinted orange fill
        // often mixes with wallpaper + materials and looks like an odd blue-grey band.
        .containerBackground(for: .widget) {
            AccessoryWidgetBackground()
        }
    }

    private func pausedStatsRow(state: RejoyTrackingAttributes.ContentState) -> some View {
        let elapsed = state.accumulatedSeconds
        return HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 2) {
                Text(formattedTime(elapsed))
                    .font(.system(size: 28, weight: .light, design: .monospaced))
                    .monospacedDigit()
                Text("Time")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(state.seedsSnapshot, format: .number.grouping(.never))
                    .font(.system(size: 28, weight: .light, design: .monospaced))
                    .monospacedDigit()
                Text("Seeds")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func runningStatsRow(state: RejoyTrackingAttributes.ContentState) -> some View {
        let anchor = state.virtualElapsedAnchor
        let farEnd = anchor.addingTimeInterval(86400 * 365 * 30)
        return HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 2) {
                Text(timerInterval: anchor...farEnd, pauseTime: nil, countsDown: false, showsHours: true)
                    .font(.system(size: 28, weight: .light, design: .monospaced))
                    .monospacedDigit()
                Text("Time")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(state.seedsSnapshot, format: .number.grouping(.never))
                    .font(.system(size: 28, weight: .light, design: .monospaced))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("Seeds")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    /// Compact presentation uses only `compactLeading`, `compactTrailing`, and `minimal` — no hidden/clear `Text` (they have caused lock-screen glitches before).
    /// The empty middle of the pill is reserved for camera hardware; `DynamicIslandExpandedRegion(.center)` / `.bottom` run only when the user expands the activity.
    private func dynamicIslandBody(_ context: ActivityViewContext<RejoyTrackingAttributes>) -> DynamicIsland {
        let state = context.state
        let anchor = state.virtualElapsedAnchor
        let farEnd = anchor.addingTimeInterval(86400 * 365 * 30)
        return DynamicIsland {
            DynamicIslandExpandedRegion(.leading) {
                Image(systemName: context.attributes.symbolName)
                    .foregroundStyle(AppColors.rejoyOrange)
            }
            DynamicIslandExpandedRegion(.trailing) {
                if state.isPaused {
                    Text(formattedTime(state.accumulatedSeconds))
                        .font(.system(.body, design: .monospaced))
                        .monospacedDigit()
                } else {
                    Text(timerInterval: anchor...farEnd, pauseTime: nil, countsDown: false, showsHours: true)
                        .font(.system(.body, design: .monospaced))
                        .monospacedDigit()
                }
            }
            DynamicIslandExpandedRegion(.center) {
                Text(context.attributes.activityName)
                    .font(.subheadline)
            }
            DynamicIslandExpandedRegion(.bottom) {
                if state.isPaused {
                    Text("\(state.seedsSnapshot) seeds")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(state.seedsSnapshot) seeds")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            }
        } compactLeading: {
            Image(systemName: context.attributes.symbolName)
                .foregroundStyle(AppColors.rejoyOrange)
        } compactTrailing: {
            // Home-screen compact: keep trailing narrow (similar to Apple’s “Work” style) — a live dot, not a wide timer.
            // Elapsed time still updates on the lock screen card and in the expanded Dynamic Island.
            if state.isPaused {
                Text(formattedTime(state.accumulatedSeconds))
                    .font(.system(.caption2, design: .monospaced))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            } else {
                Circle()
                    .fill(Color.red)
                    .frame(width: 9, height: 9)
                    .accessibilityLabel("Tracking active")
            }
        } minimal: {
            if state.isPaused {
                Image(systemName: context.attributes.symbolName)
                    .foregroundStyle(AppColors.rejoyOrange)
            } else {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .accessibilityLabel("Tracking active")
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
