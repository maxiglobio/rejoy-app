import SwiftUI
import SwiftData
import UserNotifications
import UIKit

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appLanguage) private var appLanguage
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Session.startDate, order: .reverse) private var allSessions: [Session]
    @Query(sort: \ActivityType.sortOrder) private var activityTypes: [ActivityType]

    @ObservedObject var seedsJarCoordinator: SeedsJarCoordinator
    var activeSession: ActiveTrackingSession? = nil
    var isTrackingCollapsed: Bool = false
    var onExpandTracking: (() -> Void)? = nil
    @Binding var pendingRejoyReminderDate: Date?
    @Binding var dateToOpenOnHome: Date?
    var selectedTab: Int = 0
    @State private var previousSeeds: Int = 0
    @State private var selectedDate: Date = Date()
    @State private var timeForRejoyCheck: Date = Date()
    @State private var showDayPicker = false
    @State private var showRejoyMeditationSetup = false
    @State private var isSanghaLoading = false
    @State private var lastSanghaLoadTime: Date?
    @State private var lastSanghaLoadDate: Date?
    @State private var mySangha: SanghaRow?
    @State private var sanghaMembers: [SanghaMemberRow] = []
    @State private var memberProfiles: [UUID: ProfileRow] = [:]
    @State private var activeTrackingUserIds: Set<UUID> = []
    @State private var todaySeedsByMemberId: [UUID: Int] = [:]
    @State private var selectedMemberForStory: UUID?
    @State private var viewedRefreshTrigger = UUID()
    @State private var showJoinSanghaFromHome = false
    @State private var pendingAchievement: Achievement?
    @State private var unreadNudges: [ActivityNudgeRow] = []
    @State private var nudgeSenderProfiles: [UUID: ProfileRow] = [:]
    @State private var showNudgePermissionPrompt = false
    @AppStorage("rejoyedSessionIds") private var rejoyedIdsRaw = ""
    @AppStorage("hasSeenNudgePermissionPrompt") private var hasSeenNudgePermissionPrompt = false
    @AppStorage("rejoyMeditationTime") private var rejoyMeditationTimeRaw = ""
    @AppStorage("hasSeenRejoyButtonHint") private var hasSeenRejoyButtonHint = false
    @AppStorage("viewedSanghaStories") private var viewedSanghaStoriesRaw = ""

    private var calendar: Calendar { Calendar.current }
    private var startOfSelectedDay: Date { calendar.startOfDay(for: selectedDate) }

    private struct AttributedSessionDayRow: Identifiable {
        let session: Session
        let attributedSeconds: Int
        let attributedSeeds: Int
        var id: UUID { session.id }
    }

    private var attributedSessionsForSelectedDay: [AttributedSessionDayRow] {
        allSessions.compactMap { session in
            let p = SessionDayAttribution.sessionPortion(session, on: startOfSelectedDay, calendar: calendar)
            guard p.seconds > 0 else { return nil }
            return AttributedSessionDayRow(session: session, attributedSeconds: p.seconds, attributedSeeds: p.seeds)
        }
        .sorted { $0.session.startDate > $1.session.startDate }
    }

    private var ongoingPortionForSelectedDay: (seconds: Int, seeds: Int) {
        guard let active = activeOngoingSession else { return (0, 0) }
        let now = Date()
        let secs = active.effectiveElapsedSeconds()
        let totalSeeds = SessionDayAttribution.seeds(forSeconds: secs)
        return SessionDayAttribution.portion(
            on: startOfSelectedDay,
            start: active.firstWallClockStart,
            end: now,
            durationSeconds: secs,
            totalSeeds: totalSeeds,
            calendar: calendar
        )
    }

    private var selectedDaySeeds: Int {
        let fromSessions = attributedSessionsForSelectedDay.reduce(0) { $0 + $1.attributedSeeds }
        return fromSessions + ongoingPortionForSelectedDay.seeds
    }

    private var selectedDayMinutes: Int {
        let fromSessions = attributedSessionsForSelectedDay.reduce(0) { $0 + $1.attributedSeconds } / 60
        return fromSessions + ongoingPortionForSelectedDay.seconds / 60
    }

    private var selectedDayLabel: String {
        if calendar.isDateInToday(selectedDate) { return L.string("today", language: appLanguage) }
        if calendar.isDateInYesterday(selectedDate) { return L.string("yesterday", language: appLanguage) }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = AppLanguage(rawValue: appLanguage)?.locale ?? Locale.current
        return formatter.string(from: selectedDate)
    }

    private var timelineTitle: String {
        if calendar.isDateInToday(selectedDate) { return L.string("today_timeline", language: appLanguage) }
        if calendar.isDateInYesterday(selectedDate) { return L.string("yesterday_timeline", language: appLanguage) }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        formatter.locale = AppLanguage(rawValue: appLanguage)?.locale ?? Locale.current
        return "\(formatter.string(from: selectedDate)) — \(L.string("timeline", language: appLanguage))"
    }

    private var visibleSanghaMembers: [SanghaMemberRow] {
        sanghaMembers.filter { $0.isVisible }
    }

    /// Active user IDs for display. Excludes current user when not tracking locally to avoid false live state from stale Supabase rows.
    private var effectiveActiveUserIds: Set<UUID> {
        guard let currentId = SupabaseService.shared.currentUserId else { return activeTrackingUserIds }
        if activeSession != nil {
            return activeTrackingUserIds.union([currentId])
        }
        return activeTrackingUserIds.subtracting([currentId])
    }

    private var rejoyedSessionIds: Set<UUID> {
        get {
            Set(rejoyedIdsRaw.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
        }
        set {
            rejoyedIdsRaw = newValue.map(\.uuidString).joined(separator: ",")
        }
    }

    /// Member IDs whose story we've viewed for the selected date. Format: "yyyy-MM-dd:uuid1,uuid2|yyyy-MM-dd:uuid3"
    private var viewedSanghaMemberIds: Set<UUID> {
        let key = dateString(for: selectedDate)
        let parts = viewedSanghaStoriesRaw.split(separator: "|")
        for part in parts {
            let pair = part.split(separator: ":", maxSplits: 1)
            guard pair.count == 2, String(pair[0]) == key else { continue }
            return Set(pair[1].split(separator: ",").compactMap { UUID(uuidString: String($0)) })
        }
        return []
    }

    private func dateString(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func markMemberViewed(_ memberId: UUID) {
        let key = dateString(for: selectedDate)
        var updated = viewedSanghaMemberIds
        updated.insert(memberId)
        let value = "\(key):\(updated.map(\.uuidString).joined(separator: ","))"
        var parts = viewedSanghaStoriesRaw.split(separator: "|").map(String.init).filter { !$0.isEmpty }
        parts.removeAll { $0.hasPrefix("\(key):") }
        parts.append(value)
        // Prune entries older than 7 days
        let cutoff = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let cutoffKey = dateString(for: cutoff)
        parts = parts.filter { part in
            guard let datePart = part.split(separator: ":").first else { return true }
            return String(datePart) >= cutoffKey
        }
        viewedSanghaStoriesRaw = parts.joined(separator: "|")
        viewedRefreshTrigger = UUID()
    }

    /// True when Rejoy is unlocked: no meditation time set, or not viewing today, or current time >= meditation time.
    private var canRejoyToday: Bool {
        guard let time = AppSettings.rejoyMeditationTime,
              let hour = time.hour, let minute = time.minute else { return true }
        guard calendar.isDateInToday(selectedDate) else { return true }
        let now = timeForRejoyCheck
        guard let meditationDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: calendar.startOfDay(for: now)) else { return true }
        return now >= meditationDate
    }

    private func updateWidgetData() {
        guard calendar.isDateInToday(selectedDate) else { return }
        WidgetSharedData.update(todaySeeds: selectedDaySeeds, todayMinutes: selectedDayMinutes)
    }

    private func resetSeedsAndRestoreRejoyed() {
        seedsJarCoordinator.resetSeeds(forTotalMinutes: selectedDayMinutes)
        let total = selectedDayMinutes
        guard total > 0 else { return }
        for row in attributedSessionsForSelectedDay where rejoyedSessionIds.contains(row.session.id) {
            let mins = row.attributedSeconds / 60
            seedsJarCoordinator.turnGreenProportional(sessionMinutes: mins, totalMinutes: total)
        }
    }

    private var allActivitiesRejoyed: Bool {
        !attributedSessionsForSelectedDay.isEmpty && attributedSessionsForSelectedDay.allSatisfy { rejoyedSessionIds.contains($0.session.id) }
    }

    private var heroCardAccentColor: Color {
        allActivitiesRejoyed ? Color.green : AppColors.rejoyOrange
    }

    private var meditationTimeFormatted: String? {
        guard let time = AppSettings.rejoyMeditationTime,
              let hour = time.hour, let minute = time.minute else { return nil }
        return String(format: "%d:%02d", hour, minute)
    }

    /// "Rejoy in 18h" or "Rejoy in 45m" when accumulating (before meditation time). Nil when not applicable.
    private var rejoyCountdownText: String? {
        guard let time = AppSettings.rejoyMeditationTime,
              let hour = time.hour, let minute = time.minute,
              calendar.isDateInToday(selectedDate),
              !canRejoyToday else { return nil }
        guard let meditationDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: calendar.startOfDay(for: timeForRejoyCheck)) else { return nil }
        let minutesRemaining = max(0, Int(meditationDate.timeIntervalSince(timeForRejoyCheck) / 60))
        if minutesRemaining >= 60 {
            let h = minutesRemaining / 60
            return String(format: L.string("rejoy_in_h", language: appLanguage), h)
        } else {
            return String(format: L.string("rejoy_in_m", language: appLanguage), minutesRemaining)
        }
    }

    /// "in 2h 30m" or "in 45m" for the accumulating sheet. Nil when not applicable.
    private var rejoyUnlockInText: String? {
        guard let time = AppSettings.rejoyMeditationTime,
              let hour = time.hour, let minute = time.minute,
              calendar.isDateInToday(selectedDate),
              !canRejoyToday else { return nil }
        guard let meditationDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: calendar.startOfDay(for: timeForRejoyCheck)) else { return nil }
        let minutesRemaining = max(0, Int(meditationDate.timeIntervalSince(timeForRejoyCheck) / 60))
        if minutesRemaining >= 60 {
            let h = minutesRemaining / 60
            let m = minutesRemaining % 60
            return m > 0
                ? String(format: L.string("unlock_in_h_m", language: appLanguage), h, m)
                : String(format: L.string("unlock_in_h", language: appLanguage), h)
        } else {
            return String(format: L.string("unlock_in_m", language: appLanguage), minutesRemaining)
        }
    }

    /// Uses @AppStorage so the view re-renders when the sheet saves; section disappears immediately.
    private var hasRejoyMeditationTimeSet: Bool {
        !rejoyMeditationTimeRaw.isEmpty
    }

    /// Active session when viewing today, for the timeline. Nil when collapsed (shown only near tab bar).
    private var activeOngoingSession: ActiveTrackingSession? {
        guard calendar.isDateInToday(selectedDate), !isTrackingCollapsed, let session = activeSession else { return nil }
        return session
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    if SupabaseService.shared.isSignedIn {
                        if isSanghaLoading && visibleSanghaMembers.isEmpty {
                            sanghaSkeletonView
                        } else if !visibleSanghaMembers.isEmpty {
                            SanghaAvatarStrip(
                                members: visibleSanghaMembers,
                                profilesByUserId: memberProfiles,
                                activeUserIds: effectiveActiveUserIds,
                                todaySeedsByUserId: todaySeedsByMemberId,
                                viewedMemberIds: viewedSanghaMemberIds,
                                currentUserId: SupabaseService.shared.currentUserId,
                                selectedMemberId: $selectedMemberForStory,
                                onMemberTapped: { markMemberViewed($0) }
                            )
                            .id(viewedRefreshTrigger)
                        } else {
                            sanghaEmptyStateCard
                        }
                    }
                    heroCard
                    if !hasRejoyMeditationTimeSet {
                        rejoyMeditationPromptSection
                    }
                    timelineSection
                }
                .padding()
                .padding(.bottom, 90)
            }
            .refreshable {
                await MainActor.run { isSanghaLoading = true }
                await MainActor.run {
                    timeForRejoyCheck = Date()
                    updateWidgetData()
                    resetSeedsAndRestoreRejoyed()
                }
                await loadSanghaData(forceRefresh: true)
            }
            .background(AppColors.background)
            .navigationTitle(L.string("seeds", language: appLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 4) {
                        Text(L.string("seeds_for", language: appLanguage))
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showDayPicker = true
                        } label: {
                            HStack(spacing: 4) {
                                Text(selectedDayLabel)
                                    .fontWeight(.medium)
                                Image(systemName: "chevron.down.circle.fill")
                                    .font(AppFont.subheadline)
                            }
                            .foregroundStyle(AppColors.dotsSecondaryText)
                        }
                    }
                }
            }
            .sheet(isPresented: $showDayPicker) {
                DayPickerSheet(selectedDate: $selectedDate, onDismiss: { showDayPicker = false })
            }
            .sheet(isPresented: $showRejoyMeditationSetup) {
                RejoyMeditationSetupSheet(onDismiss: { showRejoyMeditationSetup = false })
            }
            .sheet(item: $pendingAchievement) { achievement in
                AchievementPopupView(achievement: achievement) {
                    AchievementService.markAchievementShownToday()
                    Task {
                        await AchievementService.saveUnlock(achievementId: achievement.id)
                    }
                    pendingAchievement = nil
                }
            }
            .onAppear {
                timeForRejoyCheck = Date()
                previousSeeds = selectedDaySeeds
                resetSeedsAndRestoreRejoyed()
                updateWidgetData()
                if let date = pendingRejoyReminderDate {
                    selectedDate = date
                    pendingRejoyReminderDate = nil
                }
                if let date = dateToOpenOnHome {
                    selectedDate = date
                    dateToOpenOnHome = nil
                }
                Task { await loadSanghaData() }
            }
            .task(id: selectedDate) {
                await loadSanghaData()
            }
            .task(id: "\(visibleSanghaMembers.count)-\(hasSeenNudgePermissionPrompt)") {
                guard !visibleSanghaMembers.isEmpty,
                      SupabaseService.shared.isSignedIn,
                      !hasSeenNudgePermissionPrompt else { return }
                let settings = await withCheckedContinuation { (cont: CheckedContinuation<UNNotificationSettings, Never>) in
                    UNUserNotificationCenter.current().getNotificationSettings { cont.resume(returning: $0) }
                }
                if settings.authorizationStatus == .notDetermined {
                    await MainActor.run { showNudgePermissionPrompt = true }
                }
            }
            .sheet(isPresented: $showJoinSanghaFromHome) {
                ProfileVisibilityInviteSheet(onJoined: { _ in
                    Task { await loadSanghaData(forceRefresh: true) }
                })
            }
            .fullScreenCover(item: Binding(
                get: { selectedMemberForStory.map { MemberIdWrapper(id: $0) } },
                set: { selectedMemberForStory = $0?.id }
            )) { wrapper in
                StoryActivityViewer(
                    members: visibleSanghaMembers,
                    profilesByUserId: memberProfiles,
                    initialMemberId: wrapper.id,
                    date: selectedDate,
                    activityTypes: activityTypes,
                    onMemberViewed: { markMemberViewed($0) },
                    onDismiss: { selectedMemberForStory = nil }
                )
            }
            .alert(L.string("nudge_permission_prompt_title", language: appLanguage), isPresented: $showNudgePermissionPrompt) {
                Button(L.string("permissions_continue", language: appLanguage)) {
                    hasSeenNudgePermissionPrompt = true
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                        if granted {
                            PushRegistrationService.registerForRemoteNotifications()
                        }
                    }
                }
            } message: {
                Text(L.string("nudge_permission_prompt_message", language: appLanguage))
            }
            .onChange(of: pendingRejoyReminderDate) { _, newValue in
                if let date = newValue {
                    selectedDate = date
                    pendingRejoyReminderDate = nil
                }
            }
            .onChange(of: dateToOpenOnHome) { _, newValue in
                if let date = newValue {
                    selectedDate = date
                    dateToOpenOnHome = nil
                }
            }
            .onChange(of: selectedDate) { _, _ in
                resetSeedsAndRestoreRejoyed()
                previousSeeds = selectedDaySeeds
                updateWidgetData()
            }
            .onChange(of: selectedDayMinutes) { _, _ in
                guard calendar.isDateInToday(selectedDate) else { return }
                resetSeedsAndRestoreRejoyed()
            }
            .onChange(of: selectedDaySeeds) { _, newValue in
                guard calendar.isDateInToday(selectedDate) else { return }
                previousSeeds = newValue
                updateWidgetData()
            }
            .onReceive(NotificationCenter.default.publisher(for: .profileVisibilityDidChange)) { _ in
                Task { await loadSanghaData(forceRefresh: true) }
            }
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
                timeForRejoyCheck = Date()
            }
            .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
                Task { await pollActiveTracking() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .activeTrackingStateDidChange)) { _ in
                Task { await pollActiveTracking() }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await loadSanghaData() }
                    Task { await fetchUnreadNudges() }
                }
            }
            .task {
                await fetchUnreadNudges()
            }
            .overlay {
                if let nudge = unreadNudges.first {
                    nudgeBanner(nudge: nudge)
                }
            }
            .onChange(of: selectedTab) { _, newValue in
                if newValue == 0 {
                    Task { await loadSanghaData() }
                }
            }
        }
    }

    private func fetchUnreadNudges() async {
        guard SupabaseService.shared.isSignedIn else { return }
        do {
            let nudges = try await SupabaseService.shared.fetchUnreadNudges()
            guard !nudges.isEmpty else {
                await MainActor.run { unreadNudges = []; nudgeSenderProfiles = [:] }
                return
            }
            let senderIds = nudges.map(\.senderUserId)
            let profiles = try await SupabaseService.shared.fetchProfiles(userIds: senderIds)
            let profilesByUserId = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
            await MainActor.run {
                unreadNudges = nudges
                nudgeSenderProfiles = profilesByUserId
            }
        } catch {
            await MainActor.run { unreadNudges = []; nudgeSenderProfiles = [:] }
        }
    }

    @ViewBuilder
    private func nudgeBanner(nudge: ActivityNudgeRow) -> some View {
        let senderName = nudgeSenderProfiles[nudge.senderUserId]?.displayName ?? "Someone"
        let displayName = senderName.isEmpty ? "Someone" : senderName
        VStack {
            Button {
                Task {
                    try? await SupabaseService.shared.markNudgeSeen(nudgeId: nudge.id)
                    await MainActor.run {
                        unreadNudges.removeAll { $0.id == nudge.id }
                        if unreadNudges.isEmpty { nudgeSenderProfiles = [:] }
                    }
                }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: L.string("nudge_notification_title", language: appLanguage), displayName))
                        .font(AppFont.headline)
                        .foregroundStyle(.primary)
                    Text(L.string("nudge_notification_subtitle", language: appLanguage))
                        .font(AppFont.subheadline)
                        .foregroundStyle(AppColors.dotsSecondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(uiColor: .systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            Spacer()
        }
    }

    private func loadSanghaData(forceRefresh: Bool = false) async {
        let dateForLoad = selectedDate
        guard SupabaseService.shared.isSignedIn else {
            await MainActor.run {
                isSanghaLoading = false
                mySangha = nil
                sanghaMembers = []
                memberProfiles = [:]
                todaySeedsByMemberId = [:]
            }
            return
        }
        if !forceRefresh, let last = lastSanghaLoadTime, let lastDate = lastSanghaLoadDate,
           calendar.isDate(lastDate, inSameDayAs: dateForLoad),
           Date().timeIntervalSince(last) < 30,
           !sanghaMembers.isEmpty {
            return
        }
        let showSkeleton = sanghaMembers.isEmpty
        if showSkeleton {
            await MainActor.run { isSanghaLoading = true }
        }
        do {
            // Phase 1 (fast): members + profiles — update UI immediately
            let members = try await SanghaService.shared.fetchAllVisibleMembersFromMyGroups()
            let primarySangha = try await SanghaService.shared.fetchMyPrimarySanghaFromVisibleGroups()
            let profiles = try await SupabaseService.shared.fetchProfiles(userIds: members.map(\.userId))
            let profilesByUserId = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
            let avatarUrls = members.compactMap { profilesByUserId[$0.userId]?.avatarUrl }.compactMap { URL(string: $0) }
            AvatarImageCache.prefetch(urls: avatarUrls)

            await MainActor.run {
                guard calendar.isDate(dateForLoad, inSameDayAs: selectedDate) else { return }
                isSanghaLoading = false
                lastSanghaLoadTime = Date()
                lastSanghaLoadDate = dateForLoad
                mySangha = primarySangha
                sanghaMembers = members
                memberProfiles = profilesByUserId
                todaySeedsByMemberId = [:]
                activeTrackingUserIds = []
            }

            // Phase 2 (background): seeds + active tracking
            async let activeTask = SanghaService.shared.fetchActiveTrackingState(forUserIds: members.map(\.userId))
            let seedsByUser: [UUID: Int] = await withTaskGroup(of: (UUID, Int).self) { group in
                for member in members {
                    group.addTask {
                        let sessions = try? await SupabaseService.shared.fetchSessions(userId: member.userId, date: dateForLoad)
                        let cal = Calendar.current
                        let dayStart = cal.startOfDay(for: dateForLoad)
                        let seeds = sessions?.reduce(0) { partial, row in
                            partial + SessionDayAttribution.portion(
                                on: dayStart,
                                start: row.startDate,
                                end: row.endDate,
                                durationSeconds: row.durationSeconds,
                                totalSeeds: row.seeds,
                                calendar: cal
                            ).seeds
                        } ?? 0
                        return (member.userId, seeds)
                    }
                }
                var result: [UUID: Int] = [:]
                for await (userId, seeds) in group {
                    result[userId] = seeds
                }
                return result
            }
            let active = try await activeTask

            await MainActor.run {
                guard calendar.isDate(dateForLoad, inSameDayAs: selectedDate) else { return }
                todaySeedsByMemberId = seedsByUser
                activeTrackingUserIds = Set(active.map(\.userId))
            }
            if !members.isEmpty {
                await SanghaService.shared.subscribeToActiveTrackingChanges()
            }
        } catch {
            await MainActor.run {
                guard calendar.isDate(dateForLoad, inSameDayAs: selectedDate) else { return }
                isSanghaLoading = false
                if sanghaMembers.isEmpty {
                    mySangha = nil
                    sanghaMembers = []
                    memberProfiles = [:]
                    todaySeedsByMemberId = [:]
                    activeTrackingUserIds = []
                }
            }
            await SanghaService.shared.unsubscribeFromActiveTrackingChanges()
        }
    }

    private var sanghaSkeletonView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { _ in
                    ShimmerAvatarSkeleton(size: 74)
                }
            }
            .padding(.vertical, 8)
        }
        .scrollClipDisabled()
    }

    private var sanghaEmptyStateCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.3.fill")
                .font(AppFont.rounded(size: 24))
                .foregroundStyle(AppColors.rejoyOrange)
            VStack(alignment: .leading, spacing: 4) {
                Text(L.string("sangha_empty_state", language: appLanguage))
                    .font(AppFont.subheadline)
                    .foregroundStyle(.primary)
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showJoinSanghaFromHome = true
                } label: {
                    Text(L.string("join_sangha", language: appLanguage))
                        .font(AppFont.caption)
                        .foregroundStyle(AppColors.rejoyOrange)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(16)
        .background(AppColors.rejoyOrange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func pollActiveTracking() async {
        guard !visibleSanghaMembers.isEmpty else { return }
        do {
            let active = try await SanghaService.shared.fetchActiveTrackingState(forUserIds: visibleSanghaMembers.map(\.userId))
            await MainActor.run {
                activeTrackingUserIds = Set(active.map(\.userId))
            }
        } catch { }
    }

    private var heroCard: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(selectedDaySeeds)")
                        .font(AppFont.rounded(size: 48, weight: .bold))
                    HStack {
                        Text(L.string("seeds_planted", language: appLanguage))
                            .font(AppFont.title3)
                            .foregroundStyle(AppColors.dotsSecondaryText)
                        Spacer()
                        Text("\(L.string("total", language: appLanguage)) \(L.formattedDuration(minutes: selectedDayMinutes, language: appLanguage))")
                            .font(AppFont.title3)
                            .foregroundStyle(AppColors.dotsSecondaryText)
                    }
                    .frame(maxWidth: .infinity)
                }

                SeedsJarView(coordinator: seedsJarCoordinator, backgroundColor: AppColors.dotsGlassBg)
                    .id("seedsJar")
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if calendar.isDateInToday(selectedDate), let timeStr = meditationTimeFormatted {
                HStack(spacing: 3) {
                    Image(systemName: "figure.mind.and.body")
                        .font(AppFont.caption)
                        .foregroundStyle(AppColors.dotsSecondaryText)
                    Text(timeStr)
                        .font(AppFont.caption)
                        .foregroundStyle(AppColors.dotsStatsText)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(AppColors.dotsRejoyDisabledBg)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppColors.dotsBorder, lineWidth: 1))
                .padding(.top, 12)
                .padding(.trailing, 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .frame(minHeight: 220)
        .background(AppColors.dotsMainCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 40))
    }

    private var rejoyMeditationPromptSection: some View {
        Button {
            showRejoyMeditationSetup = true
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "figure.mind.and.body")
                    .font(AppFont.rounded(size: 32))
                    .foregroundStyle(AppColors.rejoyOrange)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.string("rejoy_meditation_prompt_title", language: appLanguage))
                        .font(AppFont.headline)
                        .foregroundStyle(.primary)
                    Text(L.string("rejoy_meditation_prompt_subtitle", language: appLanguage))
                        .font(AppFont.subheadline)
                        .foregroundStyle(AppColors.dotsSecondaryText)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(AppFont.rounded(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.trailing)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.dotsRejoyDisabledBg)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppColors.dotsBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
    }
}

private struct MemberIdWrapper: Identifiable {
    let id: UUID
}

// MARK: - Timeline Empty State
private struct TimelineEmptyStateView: View {
    let isToday: Bool
    let appLanguage: String
    @State private var arrowOffset: CGFloat = 0

    private let leafColor = Color(red: 161/255.0, green: 161/255.0, blue: 166/255.0)

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "leaf")
                .font(AppFont.rounded(size: 28, weight: .light))
                .foregroundStyle(leafColor)

            if !isToday {
                Text(L.string("no_sessions_day", language: appLanguage))
                    .font(AppFont.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }

            if isToday {
                Text(L.string("empty_state_subtitle", language: appLanguage))
                    .font(AppFont.subheadline)
                    .foregroundStyle(AppColors.dotsSecondaryText)
                    .multilineTextAlignment(.center)

                Image(systemName: "chevron.down")
                    .font(AppFont.rounded(size: 20, weight: .medium))
                    .foregroundStyle(leafColor)
                    .offset(y: arrowOffset)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 24)
        .onAppear {
            guard isToday else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                arrowOffset = 6
            }
        }
    }
}

extension HomeView {
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(timelineTitle)
                .font(AppFont.headline)
            if attributedSessionsForSelectedDay.isEmpty && activeOngoingSession == nil {
                TimelineEmptyStateView(
                    isToday: calendar.isDateInToday(selectedDate),
                    appLanguage: appLanguage
                )
            } else {
                if let session = activeOngoingSession {
                    OngoingSessionRowView(session: session, onTap: { onExpandTracking?() })
                }
                ForEach(attributedSessionsForSelectedDay) { row in
                    let session = row.session
                    let isFirstRejoyable = !hasSeenRejoyButtonHint
                        && canRejoyToday
                        && !rejoyedSessionIds.contains(session.id)
                        && attributedSessionsForSelectedDay.first(where: { canRejoyToday && !rejoyedSessionIds.contains($0.session.id) })?.session.id == session.id
                    SessionRowView(
                        session: session,
                        displayDurationSeconds: row.attributedSeconds,
                        displaySeeds: row.attributedSeeds,
                        activityTypes: activityTypes,
                        isRejoyed: rejoyedSessionIds.contains(session.id),
                        canRejoy: canRejoyToday,
                        rejoyCountdownText: rejoyCountdownText,
                        rejoyUnlockInText: rejoyUnlockInText,
                        showRejoyHint: isFirstRejoyable,
                        onRejoyHintDismiss: { hasSeenRejoyButtonHint = true },
                        onRejoy: {
                            var ids = Set(rejoyedIdsRaw.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
                            ids.insert(session.id)
                            rejoyedIdsRaw = ids.map(\.uuidString).joined(separator: ",")
                            seedsJarCoordinator.turnGreen(durationMinutes: max(1, (row.attributedSeconds + 59) / 60))
                            seedsJarCoordinator.triggerChaoticJump()
                            // Check if we should show achievement popup (all sessions rejoyed today, once per day)
                            let allRejoyed = !attributedSessionsForSelectedDay.isEmpty && attributedSessionsForSelectedDay.allSatisfy { ids.contains($0.session.id) }
                            if allRejoyed, calendar.isDateInToday(selectedDate), canRejoyToday, AchievementService.shouldShowAchievementToday() {
                                let catalog = AchievementService.loadAchievements()
                                if let achievement = AchievementService.randomAchievement(from: catalog) {
                                    pendingAchievement = achievement
                                }
                            }
                        }
                    )
                }
            }
        }
    }
}

private struct DayPickerSheet: View {
    @Binding var selectedDate: Date
    let onDismiss: () -> Void
    @Environment(\.appLanguage) private var appLanguage

    private var calendar: Calendar { Calendar.current }

    private var quickDays: [(label: String, date: Date)] {
        let now = Date()
        var days: [(String, Date)] = []
        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            let label: String
            if calendar.isDateInToday(date) { label = L.string("today", language: appLanguage) }
            else if calendar.isDateInYesterday(date) { label = L.string("yesterday", language: appLanguage) }
            else {
                let f = DateFormatter()
                f.dateFormat = "EEEE, MMM d"
                f.locale = AppLanguage(rawValue: appLanguage)?.locale ?? Locale.current
                label = f.string(from: date)
            }
            days.append((label, date))
        }
        return days
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(quickDays, id: \.date) { item in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedDate = item.date
                        onDismiss()
                    } label: {
                        HStack {
                            Text(item.label)
                            Spacer()
                            if calendar.isDate(item.date, inSameDayAs: selectedDate) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppColors.rejoyOrange)
                            }
                        }
                    }
                }
            }
            .navigationTitle(L.string("choose_day", language: appLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.string("done", language: appLanguage)) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onDismiss()
                    }
                }
            }
        }
    }
}

/// Small tooltip callout near the Rejoy button — liquid glass style, no blur, button stays clickable.
private struct RejoyHintCallout: View {
    let onDismiss: () -> Void
    var tailDirection: Edge = .bottom
    @Environment(\.appLanguage) private var appLanguage
    @Environment(\.colorScheme) private var colorScheme
    @State private var appeared = false

    private var tooltipBaseGradient: [Color] {
        if colorScheme == .dark {
            return [
                Color(uiColor: .secondarySystemGroupedBackground),
                Color(uiColor: .tertiarySystemGroupedBackground)
            ]
        }
        return [
            Color(white: 0.99),
            Color(white: 0.96),
            Color(white: 0.92)
        ]
    }

    private var tooltipOverlayColors: [Color] {
        if colorScheme == .dark {
            return [Color.white.opacity(0.2), Color.white.opacity(0.06), Color.clear]
        }
        return [Color.white.opacity(0.5), Color.white.opacity(0.15), Color.clear]
    }

    private var tooltipStrokeColor: Color {
        colorScheme == .dark ? Color(.separator) : Color.white.opacity(0.35)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.string("rejoy_button_hint_body", language: appLanguage))
                .font(AppFont.rounded(size: 13, weight: .regular))
                .foregroundStyle(Color(.secondaryLabel))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onDismiss()
            } label: {
                Text(L.string("rejoy_button_hint_got_it", language: appLanguage))
                    .font(AppFont.rounded(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(AppColors.rejoyOrange))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: 160, alignment: .leading)
        .background(
            ZStack {
                LiquidGlassTooltipShape(tailDirection: tailDirection)
                    .fill(
                        LinearGradient(
                            colors: tooltipBaseGradient,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                LiquidGlassTooltipShape(tailDirection: tailDirection)
                    .fill(
                        RadialGradient(
                            colors: tooltipOverlayColors,
                            center: UnitPoint(x: 0.3, y: 0.25),
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .blendMode(.overlay)
                LiquidGlassTooltipShape(tailDirection: tailDirection)
                    .stroke(tooltipStrokeColor, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
        )
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.9)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }
}

/// Rounded pill shape with integrated tail for liquid glass tooltip. Tail points in the given direction.
private struct LiquidGlassTooltipShape: Shape {
    var tailDirection: Edge = .bottom

    func path(in rect: CGRect) -> Path {
        let cornerRadius: CGFloat = 36
        let tailWidth: CGFloat = 14
        let tailHeight: CGFloat = 8

        switch tailDirection {
        case .bottom:
            return pathTailBottom(in: rect, cornerRadius: cornerRadius, tailWidth: tailWidth, tailHeight: tailHeight)
        case .trailing:
            return pathTailTrailing(in: rect, cornerRadius: cornerRadius, tailWidth: tailWidth, tailHeight: tailHeight)
        default:
            return pathTailBottom(in: rect, cornerRadius: cornerRadius, tailWidth: tailWidth, tailHeight: tailHeight)
        }
    }

    private func pathTailBottom(in rect: CGRect, cornerRadius: CGFloat, tailWidth: CGFloat, tailHeight: CGFloat) -> Path {
        let bodyBottom = rect.height - tailHeight
        let midX = rect.midX
        let tailLeft = midX - tailWidth / 2
        let tailRight = midX + tailWidth / 2

        var path = Path()
        path.move(to: CGPoint(x: cornerRadius, y: 0))
        path.addLine(to: CGPoint(x: rect.width - cornerRadius, y: 0))
        path.addArc(center: CGPoint(x: rect.width - cornerRadius, y: cornerRadius), radius: cornerRadius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.width, y: bodyBottom - cornerRadius))
        path.addArc(center: CGPoint(x: rect.width - cornerRadius, y: bodyBottom - cornerRadius), radius: cornerRadius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: tailRight, y: bodyBottom))
        path.addLine(to: CGPoint(x: midX, y: rect.height))
        path.addLine(to: CGPoint(x: tailLeft, y: bodyBottom))
        path.addLine(to: CGPoint(x: cornerRadius, y: bodyBottom))
        path.addArc(center: CGPoint(x: cornerRadius, y: bodyBottom - cornerRadius), radius: cornerRadius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: 0, y: cornerRadius))
        path.addArc(center: CGPoint(x: cornerRadius, y: cornerRadius), radius: cornerRadius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }

    private func pathTailTrailing(in rect: CGRect, cornerRadius: CGFloat, tailWidth: CGFloat, tailHeight: CGFloat) -> Path {
        let bodyRight = rect.width - tailHeight
        let midY = rect.midY
        let tailTop = midY - tailWidth / 2
        let tailBottom = midY + tailWidth / 2

        var path = Path()
        path.move(to: CGPoint(x: cornerRadius, y: 0))
        path.addLine(to: CGPoint(x: bodyRight - cornerRadius, y: 0))
        path.addArc(center: CGPoint(x: bodyRight - cornerRadius, y: cornerRadius), radius: cornerRadius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: bodyRight, y: tailTop))
        path.addLine(to: CGPoint(x: rect.width, y: midY))
        path.addLine(to: CGPoint(x: bodyRight, y: tailBottom))
        path.addLine(to: CGPoint(x: bodyRight, y: rect.height - cornerRadius))
        path.addArc(center: CGPoint(x: bodyRight - cornerRadius, y: rect.height - cornerRadius), radius: cornerRadius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: cornerRadius, y: rect.height))
        path.addArc(center: CGPoint(x: cornerRadius, y: rect.height - cornerRadius), radius: cornerRadius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: 0, y: cornerRadius))
        path.addArc(center: CGPoint(x: cornerRadius, y: cornerRadius), radius: cornerRadius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}

private struct RejoyMeditationSetupSheet: View {
    @Environment(\.appLanguage) private var appLanguage
    let onDismiss: () -> Void

    @State private var meditationEnabled: Bool = false
    @State private var meditationTime: Date = {
        let cal = Calendar.current
        var dc = DateComponents()
        dc.hour = 7
        dc.minute = 0
        return cal.date(from: dc) ?? Date()
    }()
    @State private var showNotificationDeniedAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(L.string("rejoy_meditation_enable", language: appLanguage), isOn: $meditationEnabled)
                        .tint(AppColors.rejoyOrange)
                    if meditationEnabled {
                        DatePicker("", selection: $meditationTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text(L.string("rejoy_meditation_time", language: appLanguage))
                } footer: {
                    Text(L.string("rejoy_meditation_description", language: appLanguage))
                }
            }
            .navigationTitle(L.string("rejoy_meditation_time", language: appLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.string("done", language: appLanguage)) {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        onDismiss()
                    }
                }
            }
            .onAppear {
                if let time = AppSettings.rejoyMeditationTime, let h = time.hour, let m = time.minute {
                    meditationEnabled = true
                    var dc = DateComponents()
                    dc.hour = h
                    dc.minute = m
                    meditationTime = Calendar.current.date(from: dc) ?? meditationTime
                } else {
                    meditationEnabled = false
                }
            }
            .onChange(of: meditationEnabled) { _, enabled in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if enabled {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                        DispatchQueue.main.async {
                            if granted {
                                let cal = Calendar.current
                                let h = cal.component(.hour, from: meditationTime)
                                let m = cal.component(.minute, from: meditationTime)
                                var dc = DateComponents()
                                dc.hour = h
                                dc.minute = m
                                AppSettings.rejoyMeditationTime = dc
                                RejoyMeditationNotificationService.scheduleNotification()
                            } else {
                                meditationEnabled = false
                                showNotificationDeniedAlert = true
                            }
                        }
                    }
                } else {
                    AppSettings.rejoyMeditationTime = nil
                    RejoyMeditationNotificationService.cancelNotification()
                }
            }
            .onChange(of: meditationTime) { _, newTime in
                guard meditationEnabled else { return }
                let cal = Calendar.current
                var dc = DateComponents()
                dc.hour = cal.component(.hour, from: newTime)
                dc.minute = cal.component(.minute, from: newTime)
                AppSettings.rejoyMeditationTime = dc
                RejoyMeditationNotificationService.scheduleNotification()
            }
            .alert(L.string("notifications_required", language: appLanguage), isPresented: $showNotificationDeniedAlert) {
                Button(L.string("open_settings", language: appLanguage)) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button(L.string("done", language: appLanguage), role: .cancel) { }
            } message: {
                Text(L.string("notifications_required_message", language: appLanguage))
            }
        }
    }
}

private struct OngoingSessionRowView: View {
    @ObservedObject var session: ActiveTrackingSession
    let onTap: () -> Void
    @Environment(\.appLanguage) private var appLanguage

    private var todayPortion: (seconds: Int, seeds: Int) {
        let cal = Calendar.current
        let now = Date()
        let secs = session.effectiveElapsedSeconds()
        let totalSeeds = SessionDayAttribution.seeds(forSeconds: secs)
        return SessionDayAttribution.portion(
            on: cal.startOfDay(for: now),
            start: session.firstWallClockStart,
            end: now,
            durationSeconds: secs,
            totalSeeds: totalSeeds,
            calendar: cal
        )
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: session.activity.symbolName)
                    .font(AppFont.title2)
                    .foregroundStyle(AppColors.rejoyOrange)
                    .frame(width: 36, alignment: .center)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(L.activityName(session.activity.name, language: appLanguage))
                            .font(AppFont.headline)
                            .foregroundStyle(.primary)
                        Text(L.string("ongoing", language: appLanguage))
                            .font(AppFont.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(AppColors.rejoyOrange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.rejoyOrange.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    Text("\(session.formattedTime(todayPortion.seconds)) · \(String(format: L.string("seeds_count", language: appLanguage), todayPortion.seeds))")
                        .font(AppFont.subheadline)
                        .foregroundStyle(AppColors.dotsStatsText)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.circle.fill")
                    .font(AppFont.subheadline)
                    .foregroundStyle(AppColors.dotsStatsText)
            }
            .padding(16)
            .background(AppColors.dotsActiveRowBg)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppColors.dotsActiveRowBorder, lineWidth: 3))
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
    }
}

private struct RejoyAccumulatingExplanationSheet: View {
    let unlockInText: String?
    @Environment(\.appLanguage) private var appLanguage
    @Environment(\.dismiss) private var dismiss
    @State private var showRejoyMeditationCarousel = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Image(systemName: "figure.mind.and.body")
                        .font(AppFont.rounded(size: 72))
                        .foregroundStyle(AppColors.rejoyOrange)

                    Text(L.string("accumulating_sheet_title", language: appLanguage))
                        .font(AppFont.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)

                    if let text = unlockInText {
                        Text(text)
                            .font(AppFont.title3)
                            .fontWeight(.medium)
                            .foregroundStyle(AppColors.rejoyOrange)
                    }

                    Text(L.string("accumulating_sheet_explainer", language: appLanguage))
                        .font(AppFont.body)
                        .foregroundStyle(AppColors.dotsSecondaryText)
                        .multilineTextAlignment(.center)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showRejoyMeditationCarousel = true
                    } label: {
                        Text(L.string("learn_more_rejoy_meditation", language: appLanguage))
                            .font(AppFont.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(AppColors.rejoyOrange)
                    }
                    .padding(.top, 8)
                }
                .padding(24)
            }
            .navigationTitle(L.string("rejoy_button", language: appLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.string("understood", language: appLanguage)) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showRejoyMeditationCarousel) {
                RejoyMeditationCarouselSheet()
            }
        }
    }
}

struct SessionRowView: View {
    let session: Session
    /// When set, timeline shows this day’s attributed slice (multi-day sessions).
    var displayDurationSeconds: Int? = nil
    var displaySeeds: Int? = nil
    let activityTypes: [ActivityType]
    let isRejoyed: Bool
    let canRejoy: Bool
    let rejoyCountdownText: String?
    let rejoyUnlockInText: String?
    var showRejoyHint: Bool = false
    var onRejoyHintDismiss: (() -> Void)? = nil
    let onRejoy: () -> Void
    @Environment(\.appLanguage) private var appLanguage
    @State private var showAccumulatingExplanation = false

    private var activity: ActivityType? {
        activityTypes.first { $0.id == session.activityTypeId }
    }

    private var durationForDisplay: Int { displayDurationSeconds ?? session.durationSeconds }
    private var seedsForDisplay: Int { displaySeeds ?? session.seeds }

    private var isAccumulating: Bool {
        !canRejoy && !isRejoyed
    }

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink {
                SessionDetailView(session: session)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: activity?.symbolName ?? "circle")
                        .font(AppFont.title2)
                        .foregroundStyle(isRejoyed ? Color(.secondaryLabel) : AppColors.rejoyOrange)
                        .frame(width: 36, alignment: .center)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(activity.map { L.activityName($0.name, language: appLanguage) } ?? L.string("activity", language: appLanguage))
                            .font(AppFont.headline)
                            .foregroundStyle(.primary)
                        Text("\(L.formattedTimelineMinutes(durationForDisplay, language: appLanguage)) · \(String(format: L.string("seeds_count", language: appLanguage), seedsForDisplay))")
                            .font(AppFont.subheadline)
                            .foregroundStyle(AppColors.dotsStatsText)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .trailing, spacing: 2) {
                if showRejoyHint {
                    RejoyHintCallout(onDismiss: { onRejoyHintDismiss?() }, tailDirection: .bottom)
                }
                rejoyButton
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppColors.dotsBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var rejoyButtonLabel: String {
        if isRejoyed { return L.string("rejoyed", language: appLanguage) }
        if isAccumulating { return rejoyCountdownText ?? L.string("accumulating_potential", language: appLanguage) }
        return L.string("rejoy", language: appLanguage)
    }

    private var rejoyButtonIcon: String? {
        if isRejoyed { return "checkmark" }
        if isAccumulating { return nil }
        return "face.smiling"
    }

    private var rejoyButtonFgColor: Color {
        if isRejoyed { return Color(.secondaryLabel) }
        if isAccumulating { return AppColors.dotsRejoyDisabledText }
        return Color.white
    }

    private var rejoyButtonBgColor: Color {
        if isRejoyed { return Color(.systemGray4) }
        if isAccumulating { return AppColors.dotsRejoyDisabledBg }
        return AppColors.rejoyOrange
    }

    private var rejoyButton: some View {
        Button {
            if isRejoyed { return }
            if isAccumulating {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showAccumulatingExplanation = true
            } else if canRejoy {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onRejoy()
            }
        } label: {
            HStack(spacing: 4) {
                Text(rejoyButtonLabel)
                    .font(AppFont.subheadline)
                    .fontWeight(.medium)
                if let icon = rejoyButtonIcon {
                    Image(systemName: icon)
                        .font(AppFont.subheadline)
                }
            }
            .foregroundStyle(rejoyButtonFgColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(rejoyButtonBgColor)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isRejoyed)
        .sheet(isPresented: $showAccumulatingExplanation) {
            RejoyAccumulatingExplanationSheet(unlockInText: rejoyUnlockInText)
        }
    }
}
