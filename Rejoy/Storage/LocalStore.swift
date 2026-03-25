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

    /// Removes sessions, custom activities, and related defaults after the user deletes their account.
    @MainActor
    static func wipeAfterAccountDeletion(modelContext: ModelContext) throws {
        let sessions = try modelContext.fetch(FetchDescriptor<Session>())
        for s in sessions { modelContext.delete(s) }
        let types = try modelContext.fetch(FetchDescriptor<ActivityType>())
        for t in types where !t.isBuiltIn { modelContext.delete(t) }
        ActivityType.seedDefaultActivitiesIfNeeded(modelContext: modelContext)
        try modelContext.save()

        AppSettings.rejoyMeditationTime = nil
        AppSettings.hiddenActivityTypeIds = []
        UserDefaults.standard.removeObject(forKey: "rejoyedSessionIds")
        UserDefaults.standard.removeObject(forKey: "rejoyReminderLastShownDate")
        UserDefaults.standard.removeObject(forKey: "viewedSanghaStories")
        UserDefaults.standard.removeObject(forKey: "hasSeenNudgePermissionPrompt")
        UserDefaults.standard.removeObject(forKey: "hasSeenRejoyButtonHint")

        AchievementService.clearLocalUnlockStorage()
        ProfileState.shared.clearAvatar()
        ProfileState.clearDisplayName()
        ActiveTrackingPersistence.clear()
        WidgetSharedData.update(todaySeeds: 0, todayMinutes: 0)
    }
}
