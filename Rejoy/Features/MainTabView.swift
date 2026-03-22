import SwiftUI
import SwiftData
import UIKit

struct PendingSession: Identifiable {
    let id = UUID()
    let activity: ActivityType
    var durationSeconds: Int
}

struct MainTabView: View {
    @Environment(\.appLanguage) private var appLanguage
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Session.startDate, order: .reverse) private var allSessions: [Session]
    @AppStorage("rejoyedSessionIds") private var rejoyedIdsRaw = ""
    @AppStorage("rejoyReminderLastShownDate") private var rejoyReminderLastShownDate = ""
    @StateObject private var seedsJarCoordinator = SeedsJarCoordinator(scene: SeedsJarScene(size: CGSize(width: 400, height: 160)))
    @State private var selectedTab = 0
    @State private var dateToOpenOnHome: Date?
    @State private var showUnfinishedRejoyReminder = false
    @State private var pendingRejoyReminderDate: Date? = nil
    @State private var showActivityPicker = false
    @State private var showTracking: ActivityType?
    @State private var activeSession: ActiveTrackingSession?
    @State private var restoredTrackingState: ActiveTrackingPersistence.PersistedSession?
    @State private var isTrackingCollapsed = false
    @State private var showAdjustAndDedication: PendingSession?
    @State private var showDedication: PendingSession?
    @State private var isKeyboardVisible = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(
                seedsJarCoordinator: seedsJarCoordinator,
                activeSession: activeSession,
                isTrackingCollapsed: isTrackingCollapsed,
                onExpandTracking: { isTrackingCollapsed = false },
                pendingRejoyReminderDate: $pendingRejoyReminderDate,
                dateToOpenOnHome: $dateToOpenOnHome,
                selectedTab: selectedTab
            )
            .tag(0)
            .tabItem {
                Label(L.string("seeds", language: appLanguage), systemImage: "leaf.fill")
            }

            Color.clear
                .tag(1)
                .tabItem {
                    Label {
                        Text("")
                            .frame(minWidth: 100)
                    } icon: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 32))
                            .symbolRenderingMode(.hierarchical)
                            .opacity(0)
                    }
                }

            SettingsView(selectedTab: selectedTab, onOpenDate: { date in
                dateToOpenOnHome = date
                selectedTab = 0
            })
            .tag(2)
            .tabItem {
                Label(L.string("profile", language: appLanguage), systemImage: "person.fill")
            }
        }
        .toolbarBackground(.visible, for: .tabBar)
        .overlay(alignment: .bottom) {
            if !isKeyboardVisible {
                StartActivityButtonOverlay(onTap: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        if activeSession != nil {
                            selectedTab = 0
                            isTrackingCollapsed = false
                        } else {
                            showActivityPicker = true
                        }
                    }
                )
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == 1 {
                showActivityPicker = true
                selectedTab = 0
            } else if newValue == 0 || newValue == 2 {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
        .sheet(isPresented: $showActivityPicker) {
            ActivityPickerView { activity in
                showActivityPicker = false
                restoredTrackingState = nil
                showTracking = activity
                activeSession = ActiveTrackingSession(activity: activity, startDate: Date())
                isTrackingCollapsed = false
                Task {
                    try? await SanghaService.shared.setActiveTracking(activityTypeId: activity.id, startedAt: Date())
                }
            }
        }
        .overlay {
            if let session = activeSession {
                ActiveTrackingView(session: session, isCollapsed: $isTrackingCollapsed, onStop: { duration in
                    let activity = session.activity
                    Task { @MainActor in
                        do {
                            try await SanghaService.shared.clearActiveTracking()
                        } catch {
                            #if DEBUG
                            print("[Rejoy] clearActiveTracking failed: \(error)")
                            #endif
                            try? await Task.sleep(for: .seconds(1))
                            try? await SanghaService.shared.clearActiveTracking()
                        }
                        activeSession = nil
                        showTracking = nil
                        restoredTrackingState = nil
                        showAdjustAndDedication = PendingSession(activity: activity, durationSeconds: duration)
                    }
                })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(isTrackingCollapsed ? Color.clear : AppColors.background)
            }
        }
        .task {
            await SupabaseService.shared.restoreFromSupabaseIfNeeded()
            await SupabaseService.shared.syncLocalSessionsToSupabase()
        }
        .onAppear {
            tryRestoreTrackingSession()
            PushRegistrationService.registerIfAuthorized()
            if shouldShowUnfinishedRejoyReminder {
                showUnfinishedRejoyReminder = true
            }
        }
        .overlay {
            if showUnfinishedRejoyReminder {
                UnfinishedRejoyReminderPopup(
                    onRejoyNow: {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"
                        rejoyReminderLastShownDate = formatter.string(from: Date())
                        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                        pendingRejoyReminderDate = yesterday
                        selectedTab = 0
                        showUnfinishedRejoyReminder = false
                    },
                    onLater: {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"
                        rejoyReminderLastShownDate = formatter.string(from: Date())
                        showUnfinishedRejoyReminder = false
                    }
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .fullScreenCover(item: $showAdjustAndDedication) { pending in
            AdjustDurationView(activity: pending.activity, durationSeconds: pending.durationSeconds) { adjustedDuration in
                showAdjustAndDedication = nil
                showDedication = PendingSession(activity: pending.activity, durationSeconds: adjustedDuration)
            }
        }
        .fullScreenCover(item: $showDedication) { pending in
            DedicationView(activity: pending.activity, durationSeconds: pending.durationSeconds, seedsJarCoordinator: seedsJarCoordinator, defaultDedicationText: L.string("dedication_default", language: appLanguage)) {
                showDedication = nil
            }
        }
    }

    private var shouldShowUnfinishedRejoyReminder: Bool {
        guard AppSettings.rejoyMeditationTime != nil else { return false }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        guard rejoyReminderLastShownDate != today else { return false }
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let yesterdaySessions = allSessions.filter { calendar.isDate($0.startDate, inSameDayAs: yesterday) }
        guard !yesterdaySessions.isEmpty else { return false }
        let rejoyedIds = Set(rejoyedIdsRaw.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
        let unrejoyed = yesterdaySessions.filter { !rejoyedIds.contains($0.id) }
        return !unrejoyed.isEmpty
    }

    private func tryRestoreTrackingSession() {
        guard let persisted = ActiveTrackingPersistence.load() else { return }
        let activityId = persisted.activityId
        var descriptor = FetchDescriptor<ActivityType>(predicate: #Predicate<ActivityType> { $0.id == activityId })
        descriptor.fetchLimit = 1
        guard let activities = try? modelContext.fetch(descriptor), let activity = activities.first else {
            ActiveTrackingPersistence.clear()
            return
        }
        restoredTrackingState = persisted
        showTracking = activity
        activeSession = ActiveTrackingSession(
            activity: activity,
            startDate: persisted.startDate,
            totalPausedSeconds: persisted.totalPausedSeconds,
            isPaused: persisted.isPaused
        )
        isTrackingCollapsed = false
        Task {
            try? await SanghaService.shared.setActiveTracking(activityTypeId: activity.id, startedAt: persisted.startDate)
        }
    }
}

private struct StartActivityButtonOverlay: View {
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(AppColors.rejoyOrange)
                    .frame(width: 74, height: 74)
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    }
                    .overlay {
                        Image(systemName: "record.circle")
                            .font(AppFont.rounded(size: 38))
                            .foregroundStyle(.white)
                    }
            }
        }
        .offset(y: 12)
    }
}
