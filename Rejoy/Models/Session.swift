import Foundation
import SwiftData

@Model
final class Session: Identifiable {
    var id: UUID
    var activityTypeId: UUID
    var startDate: Date
    var endDate: Date
    var durationSeconds: Int
    var seeds: Int
    var dedicationText: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        activityTypeId: UUID,
        startDate: Date,
        endDate: Date,
        durationSeconds: Int,
        seeds: Int,
        dedicationText: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.activityTypeId = activityTypeId
        self.startDate = startDate
        self.endDate = endDate
        self.durationSeconds = durationSeconds
        self.seeds = seeds
        self.dedicationText = dedicationText
        self.createdAt = createdAt
    }
}
