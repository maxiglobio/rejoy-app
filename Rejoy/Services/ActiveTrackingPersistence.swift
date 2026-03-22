import Foundation

/// Persists active tracking session so it survives app termination.
/// Uses App Group for consistency with widgets.
enum ActiveTrackingPersistence {
    private static let suiteName = WidgetSharedData.appGroupId
    private static let activityIdKey = "activeTracking_activityId"
    private static let startDateKey = "activeTracking_startDate"
    private static let totalPausedSecondsKey = "activeTracking_totalPausedSeconds"
    private static let isPausedKey = "activeTracking_isPaused"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    struct PersistedSession {
        let activityId: UUID
        let startDate: Date
        let totalPausedSeconds: Int
        let isPaused: Bool
    }

    static func save(activityId: UUID, startDate: Date, totalPausedSeconds: Int, isPaused: Bool) {
        defaults?.set(activityId.uuidString, forKey: activityIdKey)
        defaults?.set(startDate.timeIntervalSince1970, forKey: startDateKey)
        defaults?.set(totalPausedSeconds, forKey: totalPausedSecondsKey)
        defaults?.set(isPaused, forKey: isPausedKey)
    }

    static func load() -> PersistedSession? {
        guard let idStr = defaults?.string(forKey: activityIdKey),
              let id = UUID(uuidString: idStr),
              let startInterval = defaults?.object(forKey: startDateKey) as? TimeInterval else {
            return nil
        }
        let totalPaused = defaults?.integer(forKey: totalPausedSecondsKey) ?? 0
        let isPaused = defaults?.bool(forKey: isPausedKey) ?? false
        return PersistedSession(
            activityId: id,
            startDate: Date(timeIntervalSince1970: startInterval),
            totalPausedSeconds: totalPaused,
            isPaused: isPaused
        )
    }

    static func clear() {
        defaults?.removeObject(forKey: activityIdKey)
        defaults?.removeObject(forKey: startDateKey)
        defaults?.removeObject(forKey: totalPausedSecondsKey)
        defaults?.removeObject(forKey: isPausedKey)
    }
}
