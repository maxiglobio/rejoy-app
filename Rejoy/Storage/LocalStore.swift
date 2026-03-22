import Foundation
import SwiftData

/// Local storage using SwiftData
final class LocalStore {
    static let shared = LocalStore()

    let modelContainer: ModelContainer

    private init() {
        let schema = Schema([
            ActivityType.self,
            Session.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        modelContainer = try! ModelContainer(for: schema, configurations: [config])
    }

    var modelContext: ModelContext {
        ModelContext(modelContainer)
    }

    func save() {
        try? modelContext.save()
    }
}
