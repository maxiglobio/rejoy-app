import Foundation
import Supabase

/// Posted when active_tracking_state table changes (INSERT/DELETE). Observers should refetch.
extension Notification.Name {
    static let activeTrackingStateDidChange = Notification.Name("activeTrackingStateDidChange")
}

/// Service for Sangha (group) CRUD, members, invites, and active tracking state.
@MainActor
final class SanghaService: ObservableObject {
    static let shared = SanghaService()

    private let client = SupabaseClient.rejoy
    private var activeTrackingChannel: RealtimeChannelV2?

    private init() {}

    private var currentUserId: UUID? {
        guard let id = client.auth.currentUser?.id else { return nil }
        return UUID(uuidString: id.uuidString)
    }

    // MARK: - Sangha CRUD

    /// Creates a new Sangha and adds the current user as creator.
    func createSangha(name: String) async throws -> SanghaRow {
        guard let userId = currentUserId else { throw SanghaError.notSignedIn }
        let inviteCode = Self.generateInviteCode()
        let sangha = SanghaRow(
            id: UUID(),
            name: name,
            createdBy: userId,
            createdAt: Date(),
            inviteCode: inviteCode
        )
        try await client.from("sanghas").insert(sangha).execute()
        let member = SanghaMemberRow(
            sanghaId: sangha.id,
            userId: userId,
            joinedAt: Date(),
            role: "creator",
            isVisible: true
        )
        try await client.from("sangha_members").insert(member).execute()
        return sangha
    }

    /// Renames a Sangha (creator only; enforced by RLS).
    func updateSanghaName(sanghaId: UUID, name: String) async throws -> SanghaRow {
        guard currentUserId != nil else { throw SanghaError.notSignedIn }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SanghaError.emptyGroupName }
        try await client
            .from("sanghas")
            .update(["name": trimmed])
            .eq("id", value: sanghaId.uuidString.lowercased())
            .execute()
        guard let updated = try await fetchSangha(id: sanghaId) else { throw SanghaError.sanghaNotFound }
        return updated
    }

    /// Joins a Sangha by invite code. Uses RPC for security.
    func joinSangha(inviteCode: String) async throws -> SanghaRow {
        guard currentUserId != nil else { throw SanghaError.notSignedIn }
        let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else { throw SanghaError.invalidInviteCode }
        struct JoinParams: Encodable { let p_invite_code: String }
        let result: UUID = try await client.rpc("join_sangha_by_code", params: JoinParams(p_invite_code: code)).execute().value
        guard let sangha = try await fetchSangha(id: result) else { throw SanghaError.sanghaNotFound }
        return sangha
    }

    /// Fetches the Sangha the current user belongs to (first/most recent for backward compat).
    func fetchMySangha() async throws -> SanghaRow? {
        try await fetchMySanghas().first
    }

    /// Fetches all Sanghas the current user belongs to, ordered by joined_at desc (most recent first).
    func fetchMySanghas() async throws -> [SanghaRow] {
        guard let userId = currentUserId else { return [] }
        let members: [SanghaMemberRow] = try await client
            .from("sangha_members")
            .select()
            .eq("user_id", value: userId.uuidString.lowercased())
            .order("joined_at", ascending: false)
            .execute()
            .value
        var sanghas: [SanghaRow] = []
        for member in members {
            if let sangha = try await fetchSangha(id: member.sanghaId) {
                sanghas.append(sangha)
            }
        }
        return sanghas
    }

    /// Fetches member counts for the given sangha IDs.
    func fetchMemberCounts(for sanghaIds: [UUID]) async throws -> [UUID: Int] {
        guard !sanghaIds.isEmpty else { return [:] }
        let rows: [SanghaMemberRow] = try await client
            .from("sangha_members")
            .select()
            .in("sangha_id", values: sanghaIds.map { $0.uuidString.lowercased() })
            .execute()
            .value
        var counts: [UUID: Int] = [:]
        for id in sanghaIds {
            counts[id] = rows.filter { $0.sanghaId == id }.count
        }
        return counts
    }

    private func fetchSangha(id: UUID) async throws -> SanghaRow? {
        let rows: [SanghaRow] = try await client
            .from("sanghas")
            .select()
            .eq("id", value: id.uuidString.lowercased())
            .execute()
            .value
        return rows.first
    }

    /// Fetches all members of the given Sangha.
    func fetchMembers(sanghaId: UUID) async throws -> [SanghaMemberRow] {
        let rows: [SanghaMemberRow] = try await client
            .from("sangha_members")
            .select()
            .eq("sangha_id", value: sanghaId.uuidString.lowercased())
            .order("joined_at", ascending: true)
            .execute()
            .value
        return rows
    }

    /// Fetches all members of the current user's primary Sangha (first from fetchMySanghas).
    func fetchMembers() async throws -> [SanghaMemberRow] {
        guard let sangha = try await fetchMySangha() else { return [] }
        return try await fetchMembers(sanghaId: sangha.id)
    }

    /// Fetches the current user's membership in their sangha (if any).
    func fetchMyMembership() async throws -> SanghaMemberRow? {
        try await fetchMyMemberships().first
    }

    /// Fetches all memberships for the current user (one per group), ordered by joined_at desc.
    func fetchMyMemberships() async throws -> [SanghaMemberRow] {
        guard let userId = currentUserId else { return [] }
        return try await client
            .from("sangha_members")
            .select()
            .eq("user_id", value: userId.uuidString.lowercased())
            .order("joined_at", ascending: false)
            .execute()
            .value
    }

    /// Fetches all visible members from groups where the current user is visible.
    /// Excludes groups where the user has paused visibility; deduplicates by userId.
    func fetchAllVisibleMembersFromMyGroups() async throws -> [SanghaMemberRow] {
        let myMemberships = try await fetchMyMemberships()
        let visibleMemberships = myMemberships.filter { $0.isVisible }
        var seenUserIds: Set<UUID> = []
        var result: [SanghaMemberRow] = []
        for membership in visibleMemberships {
            let members = try await fetchMembers(sanghaId: membership.sanghaId)
            for member in members where member.isVisible {
                if !seenUserIds.contains(member.userId) {
                    seenUserIds.insert(member.userId)
                    result.append(member)
                }
            }
        }
        return result
    }

    /// Returns the first sangha from groups where the current user is visible, or nil.
    func fetchMyPrimarySanghaFromVisibleGroups() async throws -> SanghaRow? {
        let visibleMemberships = try await fetchMyMemberships().filter { $0.isVisible }
        guard let first = visibleMemberships.first else { return nil }
        return try await fetchSangha(id: first.sanghaId)
    }

    /// Sets visibility for the current user in their sangha.
    func setVisibility(visible: Bool) async throws {
        guard let userId = currentUserId else { throw SanghaError.notSignedIn }
        try await client
            .from("sangha_members")
            .update(["is_visible": visible])
            .eq("user_id", value: userId.uuidString.lowercased())
            .execute()
    }

    /// Leaves the given sangha (removes membership for that group only).
    func leaveSangha(sanghaId: UUID) async throws {
        guard let userId = currentUserId else { throw SanghaError.notSignedIn }
        try await client
            .from("sangha_members")
            .delete()
            .eq("user_id", value: userId.uuidString.lowercased())
            .eq("sangha_id", value: sanghaId.uuidString.lowercased())
            .execute()
    }

    // MARK: - Active Tracking State

    /// Fetches active tracking state for the given user IDs (Sangha members).
    func fetchActiveTrackingState(forUserIds userIds: [UUID]) async throws -> [ActiveTrackingStateRow] {
        guard !userIds.isEmpty else { return [] }
        let rows: [ActiveTrackingStateRow] = try await client
            .from("active_tracking_state")
            .select()
            .in("user_id", values: userIds.map { $0.uuidString.lowercased() })
            .execute()
            .value
        return rows
    }

    /// Sets or updates the current user's active tracking state.
    func setActiveTracking(activityTypeId: UUID, startedAt: Date = Date()) async throws {
        guard let userId = currentUserId else { return }
        let row = ActiveTrackingStateRow(
            userId: userId,
            activityTypeId: activityTypeId,
            startedAt: startedAt,
            updatedAt: Date()
        )
        try await client.from("active_tracking_state").upsert(row, onConflict: "user_id").execute()
    }

    /// Clears the current user's active tracking state.
    func clearActiveTracking() async throws {
        guard let userId = currentUserId else { return }
        try await client.from("active_tracking_state").delete().eq("user_id", value: userId.uuidString.lowercased()).execute()
    }

    // MARK: - Realtime

    /// Subscribes to active_tracking_state changes. Notifies via Notification.activeTrackingStateDidChange.
    func subscribeToActiveTrackingChanges() async {
        await unsubscribeFromActiveTrackingChanges()
        let channel = client.channel("active-tracking-state")
        _ = channel.onPostgresChange(
            AnyAction.self,
            schema: "public",
            table: "active_tracking_state",
            callback: { _ in
                Task { @MainActor in
                    NotificationCenter.default.post(name: .activeTrackingStateDidChange, object: nil)
                }
            }
        )
        activeTrackingChannel = channel
        do {
            try await channel.subscribeWithError()
        } catch {
            activeTrackingChannel = nil
        }
    }

    /// Unsubscribes from active_tracking_state changes.
    func unsubscribeFromActiveTrackingChanges() async {
        if let channel = activeTrackingChannel {
            await client.removeChannel(channel)
        }
        activeTrackingChannel = nil
    }

    // MARK: - Helpers

    private static func generateInviteCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }
}

// MARK: - DTOs

struct SanghaRow: Codable, Identifiable {
    let id: UUID
    let name: String
    let createdBy: UUID
    let createdAt: Date
    let inviteCode: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdBy = "created_by"
        case createdAt = "created_at"
        case inviteCode = "invite_code"
    }
}

struct SanghaMemberRow: Codable {
    let sanghaId: UUID
    let userId: UUID
    let joinedAt: Date
    let role: String
    var isVisible: Bool

    enum CodingKeys: String, CodingKey {
        case sanghaId = "sangha_id"
        case userId = "user_id"
        case joinedAt = "joined_at"
        case role
        case isVisible = "is_visible"
    }

    init(sanghaId: UUID, userId: UUID, joinedAt: Date, role: String, isVisible: Bool = true) {
        self.sanghaId = sanghaId
        self.userId = userId
        self.joinedAt = joinedAt
        self.role = role
        self.isVisible = isVisible
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sanghaId = try c.decode(UUID.self, forKey: .sanghaId)
        userId = try c.decode(UUID.self, forKey: .userId)
        joinedAt = try c.decode(Date.self, forKey: .joinedAt)
        role = try c.decode(String.self, forKey: .role)
        isVisible = try c.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
    }
}

struct ActiveTrackingStateRow: Codable {
    let userId: UUID
    let activityTypeId: UUID
    let startedAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case activityTypeId = "activity_type_id"
        case startedAt = "started_at"
        case updatedAt = "updated_at"
    }
}

enum SanghaError: LocalizedError {
    case notSignedIn
    case invalidInviteCode
    case sanghaNotFound
    case emptyGroupName

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "You must be signed in"
        case .invalidInviteCode: return "Invalid invite code"
        case .sanghaNotFound: return "Group not found"
        case .emptyGroupName: return "Group name cannot be empty"
        }
    }
}
