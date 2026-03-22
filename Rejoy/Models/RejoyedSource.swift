import Foundation
import SwiftData

@Model
final class RejoyedSource {
    var date: Date
    var sourceTypeRaw: String
    var sourceLabel: String

    init(date: Date, sourceType: DataSourceType, sourceLabel: String) {
        self.date = date
        self.sourceTypeRaw = sourceType.rawValue
        self.sourceLabel = sourceLabel
    }

    var sourceType: DataSourceType {
        DataSourceType(rawValue: sourceTypeRaw) ?? .manualEntry
    }
}
