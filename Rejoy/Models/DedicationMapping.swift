import Foundation
import SwiftData

@Model
final class DedicationMapping {
    var sourceTypeRaw: String
    var sourceLabel: String
    var intentionId: UUID

    init(sourceType: DataSourceType, sourceLabel: String, intentionId: UUID) {
        self.sourceTypeRaw = sourceType.rawValue
        self.sourceLabel = sourceLabel
        self.intentionId = intentionId
    }

    var sourceType: DataSourceType {
        get { DataSourceType(rawValue: sourceTypeRaw) ?? .manualEntry }
        set { sourceTypeRaw = newValue.rawValue }
    }
}
