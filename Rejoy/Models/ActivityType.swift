import Foundation
import SwiftData

/// Fixed UUIDs for built-in activities (must match Supabase migration seed).
enum BuiltInActivity {
    static let meditation = UUID(uuidString: "a1000001-0000-0000-0000-000000000001")!
    static let yoga = UUID(uuidString: "a1000002-0000-0000-0000-000000000002")!
    static let walking = UUID(uuidString: "a1000003-0000-0000-0000-000000000003")!
    static let running = UUID(uuidString: "a1000004-0000-0000-0000-000000000004")!
    static let work = UUID(uuidString: "a1000005-0000-0000-0000-000000000005")!
    static let cooking = UUID(uuidString: "a1000006-0000-0000-0000-000000000006")!
    static let reading = UUID(uuidString: "a1000007-0000-0000-0000-000000000007")!
    static let family = UUID(uuidString: "a1000008-0000-0000-0000-000000000008")!
    static let study = UUID(uuidString: "a1000009-0000-0000-0000-000000000009")!
}

@Model
final class ActivityType: Identifiable {
    var id: UUID
    var name: String
    var symbolName: String
    var sortOrder: Int
    var isBuiltIn: Bool = false

    init(id: UUID = UUID(), name: String, symbolName: String, sortOrder: Int = 0, isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.sortOrder = sortOrder
        self.isBuiltIn = isBuiltIn
    }

    /// Seed built-in activities if none exist. Call from ActivityPickerView or SettingsView.
    static func seedDefaultActivitiesIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<ActivityType>()
        guard let existing = try? modelContext.fetch(descriptor), existing.isEmpty else { return }
        let defaults: [(UUID, String, String)] = [
            (BuiltInActivity.meditation, "Meditation", "brain.head.profile"),
            (BuiltInActivity.yoga, "Yoga", "figure.yoga"),
            (BuiltInActivity.walking, "Walking", "figure.walk"),
            (BuiltInActivity.running, "Running", "figure.run"),
            (BuiltInActivity.work, "Work", "briefcase.fill"),
            (BuiltInActivity.cooking, "Cooking", "frying.pan.fill"),
            (BuiltInActivity.reading, "Reading", "book.fill"),
            (BuiltInActivity.family, "Family", "heart.fill"),
            (BuiltInActivity.study, "Study", "book.closed.fill"),
        ]
        for (index, (id, name, symbol)) in defaults.enumerated() {
            let activity = ActivityType(id: id, name: name, symbolName: symbol, sortOrder: index, isBuiltIn: true)
            modelContext.insert(activity)
        }
        try? modelContext.save()
    }
}
