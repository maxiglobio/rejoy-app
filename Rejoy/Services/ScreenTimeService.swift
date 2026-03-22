import Foundation

/// Screen Time / DeviceActivity - requires Family Controls entitlement (Apple approval).
/// Returns empty until entitlement is available.
@MainActor
final class ScreenTimeService: ObservableObject {
    var isAvailable: Bool { false }

    func requestAuthorization() async -> Bool {
        false
    }

    func fetchTodayTotals() async -> [String: Double] {
        [:]
    }
}
