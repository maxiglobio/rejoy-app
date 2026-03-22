import Foundation
import Supabase
import AuthenticationServices
import SwiftData
import UIKit

enum PlanType: String {
    case free
    case dip
}

@MainActor
final class SupabaseService: ObservableObject {
    static let shared = SupabaseService()

    private let client = SupabaseClient.rejoy

    @Published private(set) var isSignedIn: Bool
    @Published private(set) var planType: PlanType = .free
    @Published private(set) var teacherPortraitURL: String?

    private init() {
        isSignedIn = client.auth.currentSession != nil
    }

    var currentUserId: UUID? {
        guard let id = client.auth.currentUser?.id else { return nil }
        return UUID(uuidString: id.uuidString)
    }

    /// Deep feature (Altar, upgrade) is available only for specific users.
    private static let deepAllowedUserIds: Set<UUID> = [
        UUID(uuidString: "1fc38daa-8ab5-4f9c-b265-fb0b0ba57c86")!,
        UUID(uuidString: "7885a7c7-e2d9-4a98-a9e5-9abef28dbe2e")!
    ]
    var isDeepFeatureAvailable: Bool {
        guard let userId = currentUserId else { return false }
        return Self.deepAllowedUserIds.contains(userId)
    }

    // MARK: - Auth: Sign in with Apple

    func signInWithApple(authorization: ASAuthorization, nonce: String) async throws {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = appleIDCredential.identityToken,
              let idToken = String(data: identityTokenData, encoding: .utf8) else {
            throw SupabaseAuthError.missingIdentityToken
        }

        _ = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )
        isSignedIn = true
        await fetchProfile()
        await restoreFromSupabaseIfNeeded()
        // Note: Apple provides fullName only on first sign-in. You can save it via updateUser if needed.
    }

    func signOut() async throws {
        try await client.auth.signOut()
        isSignedIn = false
        planType = .free
        teacherPortraitURL = nil
    }

    // MARK: - Sessions

    func insertSession(_ session: Session) async throws {
        let row = SessionRow(
            id: session.id,
            activityTypeId: session.activityTypeId,
            startDate: session.startDate,
            endDate: session.endDate,
            durationSeconds: session.durationSeconds,
            seeds: session.seeds,
            dedicationText: session.dedicationText,
            createdAt: session.createdAt
        )
        try await client.from("sessions").insert(row).execute()
    }

    func fetchSessions(userId: UUID, date: Date? = nil) async throws -> [SessionRow] {
        let rows: [SessionRow] = try await client
            .from("sessions")
            .select()
            .eq("user_id", value: userId.uuidString.lowercased())
            .order("start_date", ascending: false)
            .execute()
            .value
        guard let date = date else { return rows }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return rows.filter { calendar.isDate($0.startDate, inSameDayAs: startOfDay) }
    }

    func deleteSession(id: UUID) async throws {
        try await client.from("sessions").delete().eq("id", value: id.uuidString.lowercased()).execute()
    }

    /// Uploads custom activity types that are missing from Supabase. Must run before session sync
    /// because sessions reference activity_types (foreign key).
    func syncLocalActivityTypesToSupabase() async {
        guard currentUserId != nil else { return }
        let context = LocalStore.shared.modelContext

        let descriptor = FetchDescriptor<ActivityType>()
        guard let localTypes = try? context.fetch(descriptor) else { return }
        let customTypes = localTypes.filter { !$0.isBuiltIn }
        guard !customTypes.isEmpty else { return }

        do {
            struct IdOnly: Decodable { let id: UUID }
            let remoteRows: [IdOnly] = try await client
                .from("activity_types")
                .select("id")
                .eq("user_id", value: client.auth.currentUser!.id.uuidString.lowercased())
                .execute()
                .value
            let remoteIds = Set(remoteRows.map(\.id))

            for activity in customTypes where !remoteIds.contains(activity.id) {
                try? await insertActivityType(activity)
            }
        } catch {
            // Best-effort
        }
    }

    /// Uploads local sessions that are missing from Supabase (e.g. after failed insert, app kill, or offline save).
    /// Runs on app launch to keep Karma Partners view in sync with local data.
    func syncLocalSessionsToSupabase() async {
        guard let userId = currentUserId else { return }
        let context = LocalStore.shared.modelContext

        await syncLocalActivityTypesToSupabase()

        let descriptor = FetchDescriptor<Session>()
        guard let localSessions = try? context.fetch(descriptor), !localSessions.isEmpty else { return }

        do {
            struct IdOnly: Decodable { let id: UUID }
            let remoteRows: [IdOnly] = try await client
                .from("sessions")
                .select("id")
                .eq("user_id", value: userId.uuidString.lowercased())
                .execute()
                .value
            let remoteIds = Set(remoteRows.map(\.id))

            for session in localSessions where !remoteIds.contains(session.id) {
                try? await insertSession(session)
            }
        } catch {
            // Best-effort; don't block or surface to user
        }
    }

    // MARK: - Session Reactions

    func fetchReactions(sessionIds: [UUID]) async throws -> [SessionReactionRow] {
        guard !sessionIds.isEmpty else { return [] }
        let ids = sessionIds.map { $0.uuidString.lowercased() }
        let rows: [SessionReactionRow] = try await client
            .from("session_reactions")
            .select()
            .in("session_id", values: ids)
            .execute()
            .value
        return rows
    }

    func insertReaction(sessionId: UUID) async throws {
        guard let userId = currentUserId else { return }
        let row = SessionReactionRow(
            sessionId: sessionId,
            reactorUserId: userId,
            createdAt: Date()
        )
        try await client.from("session_reactions").insert(row).execute()
    }

    // MARK: - Activity Nudges

    func insertNudge(receiverUserId: UUID) async throws {
        guard let senderId = currentUserId else { return }
        let row = ActivityNudgeRow(
            id: UUID(),
            senderUserId: senderId,
            receiverUserId: receiverUserId,
            createdAt: Date(),
            seenAt: nil
        )
        try await client.from("activity_nudges").insert(row).execute()
    }

    func fetchUnreadNudges() async throws -> [ActivityNudgeRow] {
        guard currentUserId != nil else { return [] }
        let rows: [ActivityNudgeRow] = try await client
            .from("activity_nudges")
            .select()
            .eq("receiver_user_id", value: client.auth.currentUser!.id.uuidString.lowercased())
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows.filter { $0.seenAt == nil }
    }

    func markNudgeSeen(nudgeId: UUID) async throws {
        struct NudgeSeenUpdate: Encodable {
            let seenAt: Date
            enum CodingKeys: String, CodingKey { case seenAt = "seen_at" }
        }
        try await client
            .from("activity_nudges")
            .update(NudgeSeenUpdate(seenAt: Date()))
            .eq("id", value: nudgeId.uuidString.lowercased())
            .eq("receiver_user_id", value: client.auth.currentUser!.id.uuidString.lowercased())
            .execute()
    }

    // MARK: - Activity Types (custom only; built-in stay local)

    func insertActivityType(_ activity: ActivityType) async throws {
        guard let userId = currentUserId else { return }
        let row = ActivityTypeRow(
            id: activity.id,
            name: activity.name,
            symbolName: activity.symbolName,
            sortOrder: activity.sortOrder,
            isBuiltIn: activity.isBuiltIn,
            userId: userId,
            createdAt: Date()
        )
        try await client.from("activity_types").insert(row).execute()
    }

    func fetchActivityTypes() async throws -> [ActivityTypeRow] {
        let userId = client.auth.currentUser?.id.uuidString ?? ""
        let rows: [ActivityTypeRow] = try await client
            .from("activity_types")
            .select()
            .or("user_id.is.null,user_id.eq.\(userId)")
            .order("sort_order", ascending: true)
            .execute()
            .value
        return rows
    }

    /// Fetches activity types by ID. Used by Karma Partners to resolve custom activity types of sangha members.
    func fetchActivityTypesByIds(_ ids: [UUID]) async throws -> [ActivityTypeRow] {
        guard !ids.isEmpty else { return [] }
        let idStrings = ids.map { $0.uuidString.lowercased() }
        let rows: [ActivityTypeRow] = try await client
            .from("activity_types")
            .select()
            .in("id", values: idStrings)
            .execute()
            .value
        return rows
    }

    // MARK: - User Achievements

    func insertUserAchievement(achievementId: UUID, userId: UUID) async throws {
        let row = UserAchievementRow(
            achievementId: achievementId,
            userId: userId,
            unlockedAt: Date()
        )
        try await client.from("user_achievements").insert(row).execute()
    }

    func fetchUserAchievements(userId: UUID) async throws -> [UserAchievementRow] {
        let rows: [UserAchievementRow] = try await client
            .from("user_achievements")
            .select()
            .eq("user_id", value: userId.uuidString.lowercased())
            .order("unlocked_at", ascending: false)
            .execute()
            .value
        return rows
    }

    // MARK: - Profiles (Deep plan, teacher portrait)

    func fetchProfile() async {
        guard let userId = currentUserId else {
            planType = .free
            teacherPortraitURL = nil
            return
        }
        do {
            let rows: [ProfileRow] = try await client
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString.lowercased())
                .execute()
                .value
            if let profile = rows.first {
                planType = PlanType(rawValue: profile.planType) ?? .free
                teacherPortraitURL = profile.teacherPortraitUrl
                if let name = profile.displayName, !name.isEmpty, ProfileState.displayName == nil {
                    ProfileState.displayName = name
                }
                if let urlString = profile.avatarUrl,
                   !urlString.isEmpty,
                   ProfileState.shared.avatarImage == nil,
                   let url = URL(string: urlString) {
                    do {
                        let (data, _) = try await AvatarImageCache.sharedAvatarURLSession.data(from: url)
                        if let image = UIImage(data: data) {
                            ProfileState.shared.saveAvatar(image)
                        }
                    } catch {
                        // Avatar restore is best-effort; don't fail fetchProfile
                    }
                }
            } else {
                planType = .free
                teacherPortraitURL = nil
            }
        } catch {
            planType = .free
            teacherPortraitURL = nil
        }
    }

    /// Fetches profiles for the given user IDs (e.g. Sangha members). Requires RLS allowing Sangha members to read each other.
    func fetchProfiles(userIds: [UUID]) async throws -> [ProfileRow] {
        guard !userIds.isEmpty else { return [] }
        let rows: [ProfileRow] = try await client
            .from("profiles")
            .select()
            .in("id", values: userIds.map { $0.uuidString.lowercased() })
            .execute()
            .value
        return rows
    }

    func activateDeep() async throws {
        guard let userId = currentUserId else { return }
        // Simulate payment delay
        try await Task.sleep(nanoseconds: 1_500_000_000)
        let existing = try await client.from("profiles").select().eq("id", value: userId.uuidString.lowercased()).execute().value as [ProfileRow]
        let existingAvatar = existing.first?.avatarUrl
        let row = ProfileRow(
            id: userId,
            planType: PlanType.dip.rawValue,
            teacherPortraitUrl: teacherPortraitURL,
            avatarUrl: existingAvatar,
            displayName: existing.first?.displayName ?? ProfileState.displayName,
            updatedAt: Date()
        )
        try await client
            .from("profiles")
            .upsert(row, onConflict: "id")
            .execute()
        planType = .dip
    }

    func uploadTeacherPortrait(_ image: UIImage) async throws {
        guard let userId = currentUserId else { return }
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        try await uploadTeacherMedia(data: data, contentType: "image/jpeg", pathExtension: "jpg")
    }

    /// Uploads user profile avatar (Sangha avatars). Uses avatar_url, separate from teacher_portrait_url (Altar).
    func uploadProfileAvatar(_ image: UIImage) async throws {
        guard let userId = currentUserId else { return }
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let path = "avatars/\(userId.uuidString.lowercased()).jpg"
        _ = try await client.storage
            .from("teacher-portraits")
            .upload(path: path, file: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
        let publicURL = try client.storage.from("teacher-portraits").getPublicURL(path: path)
        let urlString = publicURL.absoluteString
        let row = ProfileRow(
            id: userId,
            planType: planType.rawValue,
            teacherPortraitUrl: teacherPortraitURL,
            avatarUrl: urlString,
            displayName: ProfileState.displayName,
            updatedAt: Date()
        )
        try await client.from("profiles").upsert(row, onConflict: "id").execute()
    }

    /// Upload teacher portrait (photo or short video). Supports .jpg, .mp4, .mov.
    func uploadTeacherMedia(data: Data, contentType: String, pathExtension: String) async throws {
        guard let userId = currentUserId else { return }
        let path = "\(userId.uuidString.lowercased()).\(pathExtension)"
        _ = try await client.storage
            .from("teacher-portraits")
            .upload(path: path, file: data, options: FileOptions(contentType: contentType, upsert: true))
        let publicURL = try client.storage.from("teacher-portraits").getPublicURL(path: path)
        let urlString = publicURL.absoluteString
        let existing: [ProfileRow] = try await client.from("profiles").select().eq("id", value: userId.uuidString.lowercased()).execute().value
        let row = ProfileRow(
            id: userId,
            planType: planType.rawValue,
            teacherPortraitUrl: urlString,
            avatarUrl: existing.first?.avatarUrl,
            displayName: existing.first?.displayName ?? ProfileState.displayName,
            updatedAt: Date()
        )
        try await client.from("profiles").upsert(row, onConflict: "id").execute()
        teacherPortraitURL = urlString
    }

    /// Saves the APNs device token to profiles for remote push (e.g. nudge notifications).
    func savePushToken(_ token: String) async {
        guard let userId = currentUserId else { return }
        do {
            struct PushTokenUpdate: Encodable {
                let pushToken: String
                let updatedAt: Date
                enum CodingKeys: String, CodingKey {
                    case pushToken = "push_token"
                    case updatedAt = "updated_at"
                }
            }
            try await client
                .from("profiles")
                .update(PushTokenUpdate(pushToken: token, updatedAt: Date()))
                .eq("id", value: userId.uuidString.lowercased())
                .execute()
        } catch {
            // Best-effort; profile may not exist yet for new users
        }
    }

    /// Updates only display_name in profiles. Use when user edits their name in Settings.
    func upsertProfileDisplayName(_ name: String?) async throws {
        guard let userId = currentUserId else { return }
        let existing: [ProfileRow] = try await client.from("profiles").select().eq("id", value: userId.uuidString.lowercased()).execute().value
        let row = ProfileRow(
            id: userId,
            planType: existing.first?.planType ?? PlanType.free.rawValue,
            teacherPortraitUrl: existing.first?.teacherPortraitUrl,
            avatarUrl: existing.first?.avatarUrl,
            displayName: name,
            updatedAt: Date()
        )
        try await client.from("profiles").upsert(row, onConflict: "id").execute()
    }

    // MARK: - Restore from Supabase (after reinstall)

    /// Restores sessions, activity types, and user settings from Supabase into local storage when local is empty.
    func restoreFromSupabaseIfNeeded() async {
        guard let userId = currentUserId else { return }
        let context = LocalStore.shared.modelContext

        // Check if local sessions are empty (heuristic for "fresh install")
        let sessionDescriptor = FetchDescriptor<Session>()
        let existingSessions = (try? context.fetch(sessionDescriptor)) ?? []
        guard existingSessions.isEmpty else { return }

        do {
            // 1. Restore sessions
            let sessionRows = try await fetchSessions(userId: userId, date: nil)
            for row in sessionRows {
                let session = Session(
                    id: row.id,
                    activityTypeId: row.activityTypeId,
                    startDate: row.startDate,
                    endDate: row.endDate,
                    durationSeconds: row.durationSeconds,
                    seeds: row.seeds,
                    dedicationText: row.dedicationText,
                    createdAt: row.createdAt
                )
                context.insert(session)
            }

            // 2. Seed built-in activity types, then restore custom ones from Supabase
            ActivityType.seedDefaultActivitiesIfNeeded(modelContext: context)
            try? context.save()

            let activityRows = try await fetchActivityTypes()
            let customRows = activityRows.filter { $0.userId != nil }
            for row in customRows {
                let activity = ActivityType(
                    id: row.id,
                    name: row.name,
                    symbolName: row.symbolName,
                    sortOrder: row.sortOrder,
                    isBuiltIn: row.isBuiltIn
                )
                context.insert(activity)
            }

            // 3. Restore user settings
            if let settings = try? await fetchUserSettings(userId: userId) {
                if let time = settings.rejoyMeditationTime, !time.isEmpty {
                    AppSettings.rejoyMeditationTime = parseRejoyTime(time)
                }
                if let ids = settings.rejoyedSessionIds, !ids.isEmpty {
                    UserDefaults.standard.set(ids, forKey: "rejoyedSessionIds")
                }
                if let ids = settings.hiddenActivityTypeIds, !ids.isEmpty {
                    UserDefaults.standard.set(ids, forKey: "hiddenActivityTypeIds")
                }
            }

            try? context.save()
        } catch {
            // Restore is best-effort; don't fail sign-in
        }
    }

    private func parseRejoyTime(_ raw: String) -> DateComponents? {
        let parts = raw.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]), let m = Int(parts[1]),
              (0..<24).contains(h), (0..<60).contains(m) else { return nil }
        var dc = DateComponents()
        dc.hour = h
        dc.minute = m
        return dc
    }

    // MARK: - User Settings (for restore)

    func fetchUserSettings(userId: UUID) async throws -> UserSettingsRow? {
        let rows: [UserSettingsRow] = try await client
            .from("user_settings")
            .select()
            .eq("user_id", value: userId.uuidString.lowercased())
            .execute()
            .value
        return rows.first
    }

    func upsertUserSettings(
        rejoyMeditationTime: String?,
        rejoyedSessionIds: String?,
        hiddenActivityTypeIds: String?
    ) async throws {
        guard let userId = currentUserId else { return }
        let row = UserSettingsRow(
            userId: userId,
            rejoyMeditationTime: rejoyMeditationTime,
            rejoyedSessionIds: rejoyedSessionIds,
            hiddenActivityTypeIds: hiddenActivityTypeIds,
            updatedAt: Date()
        )
        try await client.from("user_settings").upsert(row, onConflict: "user_id").execute()
    }

    /// Syncs current UserDefaults/AppSettings to Supabase. Call when app goes to background.
    func syncUserSettingsToSupabase() async {
        guard isSignedIn else { return }
        let rejoyTime: String? = {
            guard let dc = AppSettings.rejoyMeditationTime, let h = dc.hour, let m = dc.minute else { return nil }
            return String(format: "%02d:%02d", h, m)
        }()
        let rejoyedIds = UserDefaults.standard.string(forKey: "rejoyedSessionIds")
        let hiddenIds = UserDefaults.standard.string(forKey: "hiddenActivityTypeIds")
        try? await upsertUserSettings(
            rejoyMeditationTime: rejoyTime,
            rejoyedSessionIds: rejoyedIds,
            hiddenActivityTypeIds: hiddenIds
        )
    }
}

// MARK: - DTOs for Supabase

struct SessionRow: Codable {
    let id: UUID
    let activityTypeId: UUID
    let startDate: Date
    let endDate: Date
    let durationSeconds: Int
    let seeds: Int
    let dedicationText: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case activityTypeId = "activity_type_id"
        case startDate = "start_date"
        case endDate = "end_date"
        case durationSeconds = "duration_seconds"
        case seeds
        case dedicationText = "dedication_text"
        case createdAt = "created_at"
    }
}

struct SessionReactionRow: Codable {
    let sessionId: UUID
    let reactorUserId: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case reactorUserId = "reactor_user_id"
        case createdAt = "created_at"
    }
}

struct ActivityNudgeRow: Codable {
    let id: UUID
    let senderUserId: UUID
    let receiverUserId: UUID
    let createdAt: Date
    let seenAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case senderUserId = "sender_user_id"
        case receiverUserId = "receiver_user_id"
        case createdAt = "created_at"
        case seenAt = "seen_at"
    }
}

struct ActivityTypeRow: Codable {
    let id: UUID
    let name: String
    let symbolName: String
    let sortOrder: Int
    let isBuiltIn: Bool
    let userId: UUID?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case symbolName = "symbol_name"
        case sortOrder = "sort_order"
        case isBuiltIn = "is_built_in"
        case userId = "user_id"
        case createdAt = "created_at"
    }
}

struct UserAchievementRow: Codable {
    let achievementId: UUID
    let userId: UUID
    let unlockedAt: Date

    enum CodingKeys: String, CodingKey {
        case achievementId = "achievement_id"
        case userId = "user_id"
        case unlockedAt = "unlocked_at"
    }
}

struct ProfileRow: Codable {
    let id: UUID
    var planType: String
    var teacherPortraitUrl: String?
    var avatarUrl: String?
    var displayName: String?
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case planType = "plan_type"
        case teacherPortraitUrl = "teacher_portrait_url"
        case avatarUrl = "avatar_url"
        case displayName = "display_name"
        case updatedAt = "updated_at"
    }
}

struct UserSettingsRow: Codable {
    let userId: UUID
    var rejoyMeditationTime: String?
    var rejoyedSessionIds: String?
    var hiddenActivityTypeIds: String?
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case rejoyMeditationTime = "rejoy_meditation_time"
        case rejoyedSessionIds = "rejoyed_session_ids"
        case hiddenActivityTypeIds = "hidden_activity_type_ids"
        case updatedAt = "updated_at"
    }
}

enum SupabaseAuthError: Error {
    case missingIdentityToken
}
