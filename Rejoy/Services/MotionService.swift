import Foundation
import CoreMotion

@MainActor
final class MotionService: ObservableObject {
    private let pedometer = CMPedometer()

    var isAvailable: Bool {
        CMPedometer.isStepCountingAvailable()
    }

    func requestAuthorization() async -> Bool {
        // CoreMotion doesn't require explicit permission for step counting
        return isAvailable
    }

    func fetchTodayTotals() async -> [String: Double] {
        guard isAvailable else { return [:] }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let now = Date()

        return await withCheckedContinuation { cont in
            pedometer.queryPedometerData(from: startOfDay, to: now) { data, error in
                var result: [String: Double] = [:]
                if let data = data {
                    let steps = data.numberOfSteps.doubleValue
                    // ~2000 steps ≈ 15 min walking
                    let walkingMinutes = steps / 2000 * 15
                    if walkingMinutes > 0 {
                        result["Walking/Running", default: 0] = walkingMinutes
                    }
                }
                cont.resume(returning: result)
            }
        }
    }
}
