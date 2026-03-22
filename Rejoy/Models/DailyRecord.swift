import Foundation
import SwiftData

@Model
final class DailyRecord {
    var date: Date
    var sourceTypeRaw: String
    var sourceLabel: String
    var minutes: Double
    var intentionId: UUID?

    init(date: Date, sourceType: DataSourceType, sourceLabel: String, minutes: Double, intentionId: UUID? = nil) {
        self.date = date
        self.sourceTypeRaw = sourceType.rawValue
        self.sourceLabel = sourceLabel
        self.minutes = minutes
        self.intentionId = intentionId
    }

    var sourceType: DataSourceType {
        DataSourceType(rawValue: sourceTypeRaw) ?? .manualEntry
    }
}

extension DailyRecord {
    static func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
}

@Model
final class RitualCompletion {
    var date: Date
    var message: String

    init(date: Date = Date(), message: String = "") {
        self.date = date
        self.message = message
    }
}
