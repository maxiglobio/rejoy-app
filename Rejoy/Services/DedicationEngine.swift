import Foundation
import SwiftData

struct TimeBlock: Identifiable {
    let id = UUID()
    let sourceLabel: String
    let sourceType: DataSourceType
    let minutes: Double
    let intentionId: UUID?
    let intentionName: String?
    var isRejoyed: Bool
}

struct DailySummary {
    let bySource: [TimeBlock]
    let byIntention: [String: Double]
    let totalMinutes: Double
}

@MainActor
final class DedicationEngine: ObservableObject {
    private let healthKit = HealthKitService()
    private let calendar = CalendarService()
    private let motion = MotionService()
    private let location = LocationService()

    private var modelContext: ModelContext?

    func setModelContext(_ context: ModelContext) {
        modelContext = context
    }

    func refreshAll() async -> DailySummary {
        var allBlocks: [TimeBlock] = []

        let startOfToday = Calendar.current.startOfDay(for: Date())
        let rejoyedRecords = (try? modelContext?.fetch(FetchDescriptor<RejoyedSource>(
            predicate: #Predicate<RejoyedSource> { r in r.date >= startOfToday }
        ))) ?? []
        let rejoyedSet = Set(rejoyedRecords.map { "\($0.sourceTypeRaw)::\($0.sourceLabel)" })

        func isRejoyed(_ type: DataSourceType, _ label: String) -> Bool {
            rejoyedSet.contains("\(type.rawValue)::\(label)")
        }

        // HealthKit
        let healthData = await healthKit.fetchTodayTotals()
        for (label, minutes) in healthData where minutes > 0 {
            let type: DataSourceType = switch label {
            case "Sleep": .healthKitSleep
            case "Mindful Sessions": .healthKitMindful
            case "Exercise Time": .healthKitExercise
            case "Steps (walking)": .healthKitSteps
            default: .healthKitWorkout
            }
            allBlocks.append(TimeBlock(sourceLabel: label, sourceType: type, minutes: minutes, intentionId: nil, intentionName: nil, isRejoyed: isRejoyed(type, label)))
        }

        // Calendar
        let calData = await calendar.fetchTodayEvents()
        for (label, minutes) in calData where minutes > 0 {
            allBlocks.append(TimeBlock(sourceLabel: label, sourceType: .calendarEvents, minutes: minutes, intentionId: nil, intentionName: nil, isRejoyed: isRejoyed(.calendarEvents, label)))
        }

        // Motion (skip if HealthKit already has steps - same pedometer data)
        let hasHealthKitSteps = allBlocks.contains { $0.sourceType == .healthKitSteps }
        if !hasHealthKitSteps {
            let motionData = await motion.fetchTodayTotals()
            for (label, minutes) in motionData where minutes > 0 {
                allBlocks.append(TimeBlock(sourceLabel: label, sourceType: .motionPedometer, minutes: minutes, intentionId: nil, intentionName: nil, isRejoyed: isRejoyed(.motionPedometer, label)))
            }
        }

        // Load manual entries only (persisted service data is for weekly chart, not for display)
        if let context = modelContext {
            let descriptor = FetchDescriptor<DailyRecord>(
                predicate: #Predicate<DailyRecord> { record in
                    record.date >= startOfToday && record.sourceTypeRaw == "manualEntry"
                }
            )
            let records = (try? context.fetch(descriptor)) ?? []
            for record in records {
                allBlocks.append(TimeBlock(
                    sourceLabel: record.sourceLabel,
                    sourceType: record.sourceType,
                    minutes: record.minutes,
                    intentionId: record.intentionId,
                    intentionName: nil,
                    isRejoyed: isRejoyed(record.sourceType, record.sourceLabel)
                ))
            }
        }

        // Apply mappings
        let mappings = (try? modelContext?.fetch(FetchDescriptor<DedicationMapping>())) ?? []
        let intentions = (try? modelContext?.fetch(FetchDescriptor<Intention>())) ?? []
        let intentionMap = Dictionary(uniqueKeysWithValues: intentions.map { ($0.id, $0) })

        var mappedBlocks: [TimeBlock] = []
        for block in allBlocks {
            let mapping = mappings.first { $0.sourceType == block.sourceType && $0.sourceLabel == block.sourceLabel }
            let intentionId = mapping?.intentionId ?? block.intentionId
            let intentionName = intentionId.flatMap { intentionMap[$0]?.name }
            mappedBlocks.append(TimeBlock(
                sourceLabel: block.sourceLabel,
                sourceType: block.sourceType,
                minutes: block.minutes,
                intentionId: intentionId,
                intentionName: intentionName,
                isRejoyed: block.isRejoyed
            ))
        }

        // By intention
        var byIntention: [String: Double] = [:]
        for block in mappedBlocks {
            let name = block.intentionName ?? "Unmapped"
            byIntention[name, default: 0] += block.minutes
        }

        let total = mappedBlocks.reduce(0.0) { $0 + $1.minutes }

        // Persist today's data for weekly chart (replace non-manual records)
        if let context = modelContext {
            let startOfToday = Calendar.current.startOfDay(for: Date())
            let deleteDescriptor = FetchDescriptor<DailyRecord>(
                predicate: #Predicate<DailyRecord> { record in
                    record.date >= startOfToday && record.sourceTypeRaw != "manualEntry"
                }
            )
            let toDelete = (try? context.fetch(deleteDescriptor)) ?? []
            for r in toDelete { context.delete(r) }
            for block in mappedBlocks where block.sourceType != .manualEntry {
                let record = DailyRecord(date: startOfToday, sourceType: block.sourceType, sourceLabel: block.sourceLabel, minutes: block.minutes, intentionId: block.intentionId)
                context.insert(record)
            }
            try? context.save()
        }

        return DailySummary(bySource: mappedBlocks, byIntention: byIntention, totalMinutes: total)
    }

    func addManualEntry(minutes: Double, label: String, intentionId: UUID?) {
        guard let context = modelContext else { return }
        let record = DailyRecord(date: Date(), sourceType: .manualEntry, sourceLabel: label, minutes: minutes, intentionId: intentionId)
        context.insert(record)
        try? context.save()
    }

    func saveRitualCompletion(message: String) {
        guard let context = modelContext else { return }
        let completion = RitualCompletion(date: Date(), message: message)
        context.insert(completion)
        try? context.save()
    }

    func markSourceRejoyed(sourceType: DataSourceType, sourceLabel: String) {
        guard let context = modelContext else { return }
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let existing = try? context.fetch(FetchDescriptor<RejoyedSource>(
            predicate: #Predicate<RejoyedSource> { r in
                r.date >= startOfToday && r.sourceTypeRaw == sourceType.rawValue && r.sourceLabel == sourceLabel
            }
        ))
        if (existing ?? []).isEmpty {
            let rejoyed = RejoyedSource(date: Date(), sourceType: sourceType, sourceLabel: sourceLabel)
            context.insert(rejoyed)
            try? context.save()
        }
    }

    func ritualCompletionCount() -> Int {
        guard let context = modelContext else { return 0 }
        let descriptor = FetchDescriptor<RitualCompletion>()
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    func weeklyData() -> [(Date, Double)] {
        guard let context = modelContext else { return [] }
        let calendar = Calendar.current
        var result: [(Date, Double)] = []
        for i in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -i, to: Date()) else { continue }
            let start = calendar.startOfDay(for: date)
            var end = start
            if let e = calendar.date(byAdding: .day, value: 1, to: start) { end = e }
            let descriptor = FetchDescriptor<DailyRecord>(
                predicate: #Predicate<DailyRecord> { record in
                    record.date >= start && record.date < end
                }
            )
            let records = (try? context.fetch(descriptor)) ?? []
            let total = records.reduce(0.0) { $0 + $1.minutes }
            result.append((start, total))
        }
        return result
    }
}
