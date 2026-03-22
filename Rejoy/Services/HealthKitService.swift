import Foundation
import HealthKit

@MainActor
final class HealthKitService: ObservableObject {
    private let healthStore = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }

        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKObjectType.categoryType(forIdentifier: .mindfulSession)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]

        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            return true
        } catch {
            return false
        }
    }

    func fetchTodayTotals() async -> [String: Double] {
        guard isAvailable else { return [:] }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let now = Date()

        var result: [String: Double] = [:]

        // Workouts
        let workoutType = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let workouts: [HKWorkout] = try! await withCheckedThrowingContinuation { cont in
            let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
                    if let error = error {
                        cont.resume(throwing: error)
                        return
                    }
                cont.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            healthStore.execute(query)
        }

        for workout in workouts {
            let minutes = workout.duration / 60
            let name = workoutActivityName(workout.workoutActivityType)
            result[name, default: 0] += minutes
        }

        // Steps -> approximate walking time (2000 steps ≈ 15 min walking)
        if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
            let stats = try? await withCheckedThrowingContinuation { (cont: CheckedContinuation<HKStatistics?, Error>) in
                let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                    cont.resume(returning: stats)
                }
                healthStore.execute(query)
            }
            if let sum = stats?.sumQuantity()?.doubleValue(for: .count()) {
                let walkingMinutes = sum / 2000 * 15 // rough estimate
                result["Steps (walking)", default: 0] += walkingMinutes
            }
        }

        // Exercise time
        if let exerciseType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
            let stats = try? await withCheckedThrowingContinuation { (cont: CheckedContinuation<HKStatistics?, Error>) in
                let query = HKStatisticsQuery(quantityType: exerciseType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                    cont.resume(returning: stats)
                }
                healthStore.execute(query)
            }
            if let sum = stats?.sumQuantity()?.doubleValue(for: .minute()) {
                result["Exercise Time", default: 0] += sum
            }
        }

        // Mindful sessions
        if let mindfulType = HKCategoryType.categoryType(forIdentifier: .mindfulSession) {
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
            let samples: [HKCategorySample] = try! await withCheckedThrowingContinuation { cont in
                let query = HKSampleQuery(sampleType: mindfulType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                    if let error = error {
                        cont.resume(throwing: error)
                        return
                    }
                    cont.resume(returning: (samples as? [HKCategorySample]) ?? [])
                }
                healthStore.execute(query)
            }
            let total = samples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) / 60 }
            if total > 0 {
                result["Mindful Sessions", default: 0] += total
            }
        }

        // Sleep
        if let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
            let samples: [HKCategorySample] = try! await withCheckedThrowingContinuation { cont in
                let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                    if let error = error {
                        cont.resume(throwing: error)
                        return
                    }
                    cont.resume(returning: (samples as? [HKCategorySample]) ?? [])
                }
                healthStore.execute(query)
            }
            let total = samples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) / 60 }
            if total > 0 {
                result["Sleep", default: 0] += total
            }
        }

        return result
    }

    private func workoutActivityName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining: return "Strength Training"
        case .traditionalStrengthTraining: return "Strength Training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .coreTraining: return "Core Training"
        case .dance: return "Dance"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        case .stairClimbing: return "Stair Climbing"
        case .hiking: return "Hiking"
        case .pilates: return "Pilates"
        default: return "Workout"
        }
    }
}
