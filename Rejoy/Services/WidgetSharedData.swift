import Foundation

/// Shared data between the app and widget via App Group.
enum WidgetSharedData {
    static let appGroupId = "group.com.globio.rejoy"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    static func update(todaySeeds: Int, todayMinutes: Int) {
        defaults?.set(todaySeeds, forKey: "todaySeeds")
        defaults?.set(todayMinutes, forKey: "todayMinutes")
        defaults?.set(Date(), forKey: "lastUpdated")
    }

    static var todaySeeds: Int {
        defaults?.integer(forKey: "todaySeeds") ?? 0
    }

    static var todayMinutes: Int {
        defaults?.integer(forKey: "todayMinutes") ?? 0
    }
}
