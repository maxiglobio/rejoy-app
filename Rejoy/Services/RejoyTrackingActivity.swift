import ActivityKit
import Foundation

/// Live Activity attributes for active tracking (lock screen / Dynamic Island).
struct RejoyTrackingAttributes: ActivityAttributes {
    /// Elapsed time is derived in the widget from wall-clock fields so the counter keeps moving while the app is suspended
    /// (ActivityKit updates are still sent on pause/resume and when returning to the foreground).
    struct ContentState: Codable, Hashable {
        /// Completed seconds before the current running segment (same meaning as `ActiveTrackingSession.totalPausedSeconds`).
        var accumulatedSeconds: Int
        /// Wall-clock start of the current running segment; ignored when `isPaused` is true.
        var segmentStartDate: Date
        var isPaused: Bool
        var seedsPerSecond: Int
        /// Total seeds at last `Activity.update` from the app. Live Activity UI must stay SwiftUI-only (`UIViewRepresentable` breaks on lock screen).
        var seedsSnapshot: Int
    }

    var activityName: String
    var symbolName: String
}

extension RejoyTrackingAttributes.ContentState {
    /// Wall-clock instant such that `Date().timeIntervalSince(virtualElapsedAnchor)` matches total elapsed while running.
    var virtualElapsedAnchor: Date {
        segmentStartDate.addingTimeInterval(-Double(accumulatedSeconds))
    }

    func displayedElapsed(at date: Date) -> Int {
        if isPaused { return accumulatedSeconds }
        return accumulatedSeconds + max(0, Int(date.timeIntervalSince(segmentStartDate)))
    }

    func displayedSeeds(at date: Date) -> Int {
        displayedElapsed(at: date) * seedsPerSecond
    }
}
