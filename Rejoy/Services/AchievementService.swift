import Foundation

enum AchievementService {
    private static let unlockedIdsKey = "achievement_unlocked_ids"
    private static let unlockCountsKey = "achievement_unlock_counts"
    private static let unlockDatesKey = "achievement_unlock_dates"
    private static let lastShownDateKey = "achievement_last_shown_date"

    static func loadAchievements() -> [Achievement] {
        guard let url = Bundle.main.url(forResource: "achievements", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(AchievementsCatalog.self, from: data) else {
            return []
        }
        return catalog.achievements
    }

    /// Full catalog sorted for gallery: section, then sort_order (matches Supabase / JSON order).
    static func catalogSortedForDisplay() -> [Achievement] {
        loadAchievements().sorted {
            if $0.section != $1.section { return $0.section < $1.section }
            return $0.sortOrder < $1.sortOrder
        }
    }

    static var catalogTotalCount: Int { catalogSortedForDisplay().count }

    static func randomAchievement(from achievements: [Achievement]) -> Achievement? {
        achievements.randomElement()
    }

    static func shouldShowAchievementToday() -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        let lastShown = UserDefaults.standard.string(forKey: lastShownDateKey)
        return lastShown != today
    }

    static func markAchievementShownToday() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        UserDefaults.standard.set(formatter.string(from: Date()), forKey: lastShownDateKey)
    }

    /// Clears device-local unlock history (e.g. after account deletion).
    static func clearLocalUnlockStorage() {
        UserDefaults.standard.removeObject(forKey: unlockedIdsKey)
        UserDefaults.standard.removeObject(forKey: unlockCountsKey)
        UserDefaults.standard.removeObject(forKey: unlockDatesKey)
        UserDefaults.standard.removeObject(forKey: lastShownDateKey)
    }

    private static func unlockCounts() -> [UUID: Int] {
        if let data = UserDefaults.standard.data(forKey: unlockCountsKey),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            return Dictionary(uniqueKeysWithValues: decoded.compactMap { key, value in
                guard let uuid = UUID(uuidString: key) else { return nil }
                return (uuid, value)
            })
        }
        // Migrate from old ids format
        let raw = UserDefaults.standard.string(forKey: unlockedIdsKey) ?? ""
        let ids = raw.split(separator: ",").compactMap { UUID(uuidString: String($0)) }
        let migrated = Dictionary(uniqueKeysWithValues: ids.map { ($0, 1) })
        if !migrated.isEmpty {
            saveUnlockCounts(migrated)
            UserDefaults.standard.removeObject(forKey: unlockedIdsKey)
        }
        return migrated
    }

    private static func saveUnlockCounts(_ counts: [UUID: Int]) {
        let encoded = Dictionary(uniqueKeysWithValues: counts.map { ($0.key.uuidString, $0.value) })
        if let data = try? JSONEncoder().encode(encoded) {
            UserDefaults.standard.set(data, forKey: unlockCountsKey)
        }
    }

    static func unlockedAchievementIds() -> Set<UUID> {
        Set(unlockCounts().filter { $0.value > 0 }.map(\.key))
    }

    static func unlockCount(for achievementId: UUID) -> Int {
        unlockCounts()[achievementId] ?? 0
    }

    static func unlockAchievement(_ achievementId: UUID, unlockedAt: Date = Date()) {
        var counts = unlockCounts()
        counts[achievementId, default: 0] += 1
        saveUnlockCounts(counts)
        var dates = unlockDates()
        dates[achievementId] = unlockedAt
        saveUnlockDates(dates)
    }

    private static func unlockDates() -> [UUID: Date] {
        guard let data = UserDefaults.standard.data(forKey: unlockDatesKey),
              let decoded = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: decoded.compactMap { key, value in
            guard let uuid = UUID(uuidString: key) else { return nil }
            return (uuid, value)
        })
    }

    private static func saveUnlockDates(_ dates: [UUID: Date]) {
        let encoded = Dictionary(uniqueKeysWithValues: dates.map { ($0.key.uuidString, $0.value) })
        if let data = try? JSONEncoder().encode(encoded) {
            UserDefaults.standard.set(data, forKey: unlockDatesKey)
        }
    }

    static func unlockDate(for achievementId: UUID) -> Date? {
        unlockDates()[achievementId]
    }

    @MainActor
    static func saveUnlock(achievementId: UUID) async {
        unlockAchievement(achievementId)
        let service = SupabaseService.shared
        if service.isSignedIn, let userId = service.currentUserId {
            try? await service.insertUserAchievement(achievementId: achievementId, userId: userId)
        }
    }

    static func fetchUnlockedAchievements(achievements: [Achievement]) -> [Achievement] {
        let ids = unlockedAchievementIds()
        return achievements.filter { ids.contains($0.id) }
    }

    /// Sync achievement counts from Supabase (user_achievements has one row per unlock).
    @MainActor
    static func syncCountsFromSupabase() async {
        let service = SupabaseService.shared
        guard service.isSignedIn, let userId = service.currentUserId else { return }
        guard let rows = try? await service.fetchUserAchievements(userId: userId) else { return }
        let remoteCounts = Dictionary(grouping: rows, by: \.achievementId).mapValues { $0.count }
        var local = unlockCounts()
        var updated = false
        for (id, count) in remoteCounts {
            if (local[id] ?? 0) < count {
                local[id] = count
                updated = true
            }
        }
        if updated {
            saveUnlockCounts(local)
        }

        // Fill missing local unlock dates from server rows (counts-only sync used to omit this).
        var dates = unlockDates()
        var datesUpdated = false
        let byAchievement = Dictionary(grouping: rows, by: \.achievementId)
        for (id, group) in byAchievement {
            guard let remoteLatest = group.map(\.unlockedAt).max() else { continue }
            if let existing = dates[id] {
                if remoteLatest > existing {
                    dates[id] = remoteLatest
                    datesUpdated = true
                }
            } else {
                dates[id] = remoteLatest
                datesUpdated = true
            }
        }
        if datesUpdated {
            saveUnlockDates(dates)
        }
    }
}
