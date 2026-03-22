import ActivityKit
import Foundation

/// Live Activity attributes for active tracking (lock screen / Dynamic Island).
struct RejoyTrackingAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int
        var seeds: Int
        var isPaused: Bool
    }

    var activityName: String
    var symbolName: String
}
