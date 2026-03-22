import SwiftUI
import SwiftData
import AVFoundation
import Speech
import UserNotifications
import UIKit

struct SettingsView: View {
    var selectedTab: Int = 0
    var onOpenDate: ((Date) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @AppStorage("appLanguage") private var appLanguageStorage = ""
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @AppStorage("hasCompletedStories") private var hasCompletedStories = false
    @AppStorage("hiddenActivityTypeIds") private var hiddenActivityTypeIdsRaw = ""
    @AppStorage("rejoyedSessionIds") private var rejoyedIdsRaw = ""
    @Query(sort: \ActivityType.sortOrder) private var activityTypes: [ActivityType]
    @Query(sort: \Session.startDate, order: .reverse) private var allSessions: [Session]

    @StateObject private var profileState = ProfileState.shared
    @ObservedObject private var supabaseService = SupabaseService.shared
    @State private var micStatus: PermissionStatus = .unknown
    @State private var showDeepUpgrade = false
    @State private var showAltar = false
    @State private var speechStatus: PermissionStatus = .unknown
    @State private var notificationStatus: PermissionStatus = .unknown
    @State private var showAddActivity = false
    @State private var recognitionLocale: String = AppSettings.recognitionLocaleIdentifier
    @State private var meditationEnabled: Bool = false
    @State private var showNotificationDeniedAlert = false
    @State private var showLogOutAlert = false
    @State private var showHowToUseRejoyCarousel = false
    @State private var showRejoyMeditationCarousel = false
    @State private var showSeedsInfoCarousel = false
    @State private var selectedAchievement: Achievement?
    @State private var selectedAchievementUnlockedAt: Date?
    @State private var showRewardsGallery = false
    @State private var activityToDelete: ActivityType? = nil
    @State private var activityToEdit: ActivityType? = nil
    @State private var profileVisibilityTrailingValue: String = ""
    @State private var profileVisibilityIsVisible: Bool? = nil
    @State private var showMeditationTimePicker = false
    @State private var showRejoyMeditationSheet = false
    @State private var displayNameText: String = ""
    @State private var achievementRefreshTrigger = UUID()
    @State private var meditationTime: Date = {
        let cal = Calendar.current
        var dc = DateComponents()
        dc.hour = 7
        dc.minute = 0
        return cal.date(from: dc) ?? Date()
    }()

    private func seedsForMonth(_ date: Date) -> Int {
        let cal = Calendar.current
        guard let start = cal.date(from: cal.dateComponents([.year, .month], from: date)),
              let end = cal.date(byAdding: .month, value: 1, to: start) else { return 0 }
        return allSessions
            .filter { $0.startDate >= start && $0.startDate < end }
            .reduce(0) { $0 + $1.seeds }
    }

    private var monthSeeds: Int {
        seedsForMonth(Date())
    }

    private var visibleMonthSeeds: Int {
        seedsForMonth(calendarVisibleMonth ?? Date())
    }

    private func formatSeeds(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSize = 3
        switch appLanguageStorage {
        case "ru":
            formatter.groupingSeparator = "."
            formatter.locale = Locale(identifier: "ru_RU")
        case "uk":
            formatter.groupingSeparator = "."
            formatter.locale = Locale(identifier: "uk_UA")
        default:
            formatter.groupingSeparator = ","
            formatter.locale = Locale(identifier: "en_US")
        }
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }

    private var visibleMonthSeedsFormatted: String {
        formatSeeds(visibleMonthSeeds)
    }

    private var unlockedAchievements: [Achievement] {
        let catalog = AchievementService.loadAchievements()
        return AchievementService.fetchUnlockedAchievements(achievements: catalog)
    }

    private var hasRewardsCatalog: Bool {
        !AchievementService.loadAchievements().isEmpty
    }

    private var currentMonthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        formatter.locale = AppLanguage(rawValue: appLanguageStorage)?.locale ?? Locale.current
        return formatter.string(from: Date())
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var meditationTimeFormatted: String {
        let cal = Calendar.current
        let h = cal.component(.hour, from: meditationTime)
        let m = cal.component(.minute, from: meditationTime)
        return String(format: "%d:%02d", h, m)
    }

    private var monthSeedsFormatted: String {
        formatSeeds(monthSeeds)
    }

    private var rejoyedSessionIds: Set<UUID> {
        Set(rejoyedIdsRaw.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    profileHeaderCard
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: ProfileHeaderMinYKey.self,
                                    value: geo.frame(in: .named("profileScroll")).minY
                                )
                            }
                        )
                    calendarSectionContent
                    achievementsSectionContent
                    settingsCardContent
                    howToUseRejoyCard
                    howToMeditateCard
                    whatIsSeedsCard
                    logoutCard
                    profileFooter
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 90)
            }
            .coordinateSpace(name: "profileScroll")
            .onPreferenceChange(ProfileHeaderMinYKey.self) { profileHeaderMinY = $0 }
            .refreshable {
                refreshPermissionStatus()
                await SupabaseService.shared.fetchProfile()
                await AchievementService.syncCountsFromSupabase()
                await loadProfileVisibilityState()
                await MainActor.run {
                    achievementRefreshTrigger = UUID()
                }
            }
            .background(AppColors.background)
            .navigationTitle(L.string("profile", language: appLanguageStorage))
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                GeometryReader { geo in
                    let safeTop = geo.safeAreaInsets.top
                    let centerX = geo.size.width / 2
                    let startY = safeTop + 59
                    let endX: CGFloat = 30
                    let endY = max(44, safeTop - 22)
                    let avatarSize: CGFloat = 110 * (1.0 - headerScrollProgress * 0.75)
                    let posX = (1.0 - headerScrollProgress) * centerX + headerScrollProgress * endX
                    let posY = (1.0 - headerScrollProgress) * startY + headerScrollProgress * endY

                    ProfileAvatarView(profileState: profileState, size: avatarSize)
                        .position(x: posX, y: posY)
                        .opacity(headerScrollProgress)
                        .allowsHitTesting(false)
                }
                .ignoresSafeArea(edges: .top)
            }
            .animation(.easeInOut(duration: 0.25), value: headerScrollProgress)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if supabaseService.isDeepFeatureAvailable {
                        if supabaseService.planType == .dip {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                showAltar = true
                            } label: {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(AppColors.rejoyOrange)
                            }
                        } else {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                showDeepUpgrade = true
                            } label: {
                                Text(L.string("upgrade_to_rejoy_deep", language: appLanguageStorage))
                                    .font(AppFont.footnote)
                                    .foregroundStyle(AppColors.rejoyOrange)
                            }
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(
                        item: "\(String(format: L.string("share_app_message_with_seeds", language: appLanguageStorage), monthSeedsFormatted))https://testflight.apple.com/join/Kfe4r5aN",
                        subject: Text(L.string("share_app", language: appLanguageStorage))
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.async { Slide2VideoPreloader.shared.preload() }
                refreshPermissionStatus()
                recognitionLocale = AppSettings.recognitionLocaleIdentifier
                displayNameText = ProfileState.displayName ?? ""
                Task {
                    await SupabaseService.shared.fetchProfile()
                    await MainActor.run { displayNameText = ProfileState.displayName ?? "" }
                    await AchievementService.syncCountsFromSupabase()
                    await loadProfileVisibilityState()
                    achievementRefreshTrigger = UUID()
                }
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
            .onReceive(NotificationCenter.default.publisher(for: .profileVisibilityDidChange)) { _ in
                Task { await loadProfileVisibilityState() }
            }
            .onChange(of: selectedTab) { _, newValue in
                if newValue == 2 { Task { await loadProfileVisibilityState() } }
            }
            .onChange(of: recognitionLocale) { _, newValue in
                AppSettings.recognitionLocaleIdentifier = newValue
            }
            .onChange(of: meditationEnabled) { _, enabled in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if enabled {
                    // Request permission immediately (must be in response to user action for prompt to show)
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                        DispatchQueue.main.async {
                            refreshPermissionStatus()
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
            .sheet(isPresented: $showAddActivity) {
                AddActivityView()
            }
            .sheet(isPresented: $showDeepUpgrade) {
                DeepUpgradeSheet()
            }
            .sheet(isPresented: $showAltar) {
                AltarSheet()
            }
            .sheet(isPresented: $showHowToUseRejoyCarousel) {
                HowToUseRejoyCarouselSheet()
            }
            .sheet(isPresented: $showRejoyMeditationCarousel) {
                RejoyMeditationCarouselSheet()
            }
            .sheet(isPresented: $showSeedsInfoCarousel) {
                SeedsInfoCarouselSheet()
            }
            .sheet(isPresented: $showRejoyMeditationSheet) {
                NavigationStack {
                    Form {
                        Section {
                            Toggle(L.string("rejoy_meditation_enable", language: appLanguageStorage), isOn: $meditationEnabled)
                                .tint(AppColors.rejoyOrange)
                            if meditationEnabled {
                                Button {
                                    showRejoyMeditationSheet = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        showMeditationTimePicker = true
                                    }
                                } label: {
                                    HStack {
                                        Text(L.string("time_for_meditation", language: appLanguageStorage))
                                        Spacer()
                                        Text(meditationTimeFormatted)
                                            .foregroundStyle(AppColors.trailing)
                                    }
                                }
                            }
                        }
                    }
                    .navigationTitle(L.string("rejoy_meditation_time", language: appLanguageStorage))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(L.string("done", language: appLanguageStorage)) {
                                showRejoyMeditationSheet = false
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showMeditationTimePicker) {
                NavigationStack {
                    Form {
                        DatePicker(L.string("time_for_meditation", language: appLanguageStorage), selection: $meditationTime, displayedComponents: .hourAndMinute)
                    }
                    .navigationTitle(L.string("time_for_meditation", language: appLanguageStorage))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(L.string("done", language: appLanguageStorage)) {
                                showMeditationTimePicker = false
                            }
                        }
                    }
                }
            }
            .alert(L.string("log_out_confirm", language: appLanguageStorage), isPresented: $showLogOutAlert) {
                Button(L.string("log_out", language: appLanguageStorage), role: .destructive) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    Task {
                        try? await SupabaseService.shared.signOut()
                        await MainActor.run {
                            hasSeenWelcome = false
                            hasCompletedStories = false
                        }
                    }
                }
                Button(L.string("cancel", language: appLanguageStorage), role: .cancel) { }
            } message: {
                Text(L.string("log_out_confirm_message", language: appLanguageStorage))
            }
            .alert(L.string("notifications_required", language: appLanguageStorage), isPresented: $showNotificationDeniedAlert) {
                Button(L.string("open_settings", language: appLanguageStorage)) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button(L.string("done", language: appLanguageStorage), role: .cancel) { }
            } message: {
                Text(L.string("notifications_required_message", language: appLanguageStorage))
            }
        }
    }


    private var profileHeaderCard: some View {
        VStack(spacing: 8) {
            ProfileAvatarView(profileState: profileState, size: 110)
                .opacity(1.0 - headerScrollProgress)
                .animation(.easeInOut(duration: 0.25), value: headerScrollProgress)
                .frame(maxWidth: .infinity)

            Text(visibleMonthSeedsFormatted)
                .font(AppFont.rounded(size: 32, weight: .semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(visibleMonthSeeds)))

            Text(L.string("monthly_seeds_planted", language: appLanguageStorage))
                .font(AppFont.rounded(size: 12, weight: .medium))
                .foregroundStyle(Color(red: 0.53, green: 0.53, blue: 0.54))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    @State private var calendarVisibleMonth: Date?
    @State private var calendarScrollToCurrent = false
    @State private var profileHeaderMinY: CGFloat = 0

    private let scrollTransitionRange: CGFloat = 90

    private var headerScrollProgress: CGFloat {
        min(1, max(0, -profileHeaderMinY / scrollTransitionRange))
    }

    private var calendarSectionContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                Text(monthName(for: calendarVisibleMonth ?? Date()))
                    .font(AppFont.rounded(size: 20, weight: .semibold))
                    .foregroundStyle(AppColors.sectionHeader)
                Spacer(minLength: 0)
                Button {
                    calendarScrollToCurrent = true
                } label: {
                    Text(L.string("today", language: appLanguageStorage))
                        .font(AppFont.rounded(size: 12, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppColors.cardBackground)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            ProfileCard {
                ProfileCalendarView(
                    allSessions: allSessions,
                    rejoyedSessionIds: rejoyedSessionIds,
                    visibleMonthStart: $calendarVisibleMonth,
                    scrollToCurrentTrigger: $calendarScrollToCurrent,
                    onDayTapped: onOpenDate,
                    calendar: Calendar.current
                )
            }
        }
    }

    private func monthName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = AppLanguage(rawValue: appLanguageStorage)?.locale ?? Locale.current
        return formatter.string(from: date)
    }

    private var achievementsSectionContent: some View {
        Group {
            if hasRewardsCatalog {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(L.string("achievement_section_title", language: appLanguageStorage))
                            .font(AppFont.rounded(size: 20, weight: .semibold))
                            .foregroundStyle(AppColors.sectionHeader)
                        Spacer(minLength: 8)
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showRewardsGallery = true
                        } label: {
                            Text(L.string("rewards_view_all", language: appLanguageStorage))
                                .font(AppFont.rounded(size: 16, weight: .semibold))
                                .foregroundStyle(AppColors.rejoyOrange)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    if !unlockedAchievements.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 22) {
                                ForEach(unlockedAchievements) { achievement in
                                    Button {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        selectedAchievement = achievement
                                        selectedAchievementUnlockedAt = AchievementService.unlockDate(for: achievement.id)
                                    } label: {
                                        AchievementBadgeView(achievement: achievement, count: max(1, AchievementService.unlockCount(for: achievement.id)))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.trailing, 20)
                        }
                        .padding(.horizontal, -20)
                    } else {
                        Text(L.string("achievement_empty_state", language: appLanguageStorage))
                            .font(AppFont.rounded(size: 14, weight: .regular))
                            .foregroundStyle(AppColors.sectionHeader)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                    }
                }
            }
        }
        .id(achievementRefreshTrigger)
        .sheet(item: $selectedAchievement) { achievement in
            AchievementPopupView(
                achievement: achievement,
                unlockedAt: selectedAchievementUnlockedAt
            ) {
                selectedAchievement = nil
                selectedAchievementUnlockedAt = nil
            }
        }
        .sheet(isPresented: $showRewardsGallery) {
            RewardsGalleryView()
        }
    }

    private var howToUseRejoyCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showHowToUseRejoyCarousel = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 17)
                        .fill(AppColors.cardBackground)
                        .frame(width: 82, height: 105)
                    Image("HowToUseRejoyCover")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 82, height: 105)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.string("how_to_use_rejoy", language: appLanguageStorage))
                        .font(AppFont.rounded(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(L.string("how_to_use_rejoy_explainer", language: appLanguageStorage))
                        .font(AppFont.rounded(size: 14, weight: .regular))
                        .foregroundStyle(AppColors.sectionHeader)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(AppFont.rounded(size: 16, weight: .medium))
                    .foregroundStyle(AppColors.trailing)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private var howToMeditateCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showRejoyMeditationCarousel = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 17)
                        .fill(AppColors.cardBackground)
                        .frame(width: 82, height: 105)
                    Image("HowToMeditate")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 82, height: 105)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.string("how_to_meditate", language: appLanguageStorage))
                        .font(AppFont.rounded(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(L.string("accumulating_sheet_explainer", language: appLanguageStorage))
                        .font(AppFont.rounded(size: 14, weight: .regular))
                        .foregroundStyle(AppColors.sectionHeader)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(AppFont.rounded(size: 16, weight: .medium))
                    .foregroundStyle(AppColors.trailing)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private var whatIsSeedsCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showSeedsInfoCarousel = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 17)
                        .fill(AppColors.cardBackground)
                        .frame(width: 82, height: 105)
                    Image("WhatAreSeeds")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 82, height: 105)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.string("what_is_seeds", language: appLanguageStorage))
                        .font(AppFont.rounded(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(L.string("what_is_seeds_explainer", language: appLanguageStorage))
                        .font(AppFont.rounded(size: 14, weight: .regular))
                        .foregroundStyle(AppColors.sectionHeader)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(AppFont.rounded(size: 16, weight: .medium))
                    .foregroundStyle(AppColors.trailing)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private var settingsCardContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            ProfileSectionHeader(title: L.string("settings", language: appLanguageStorage))
            ProfileCard {
                VStack(spacing: 14) {
                    if supabaseService.isSignedIn {
                        HStack(spacing: 16) {
                            Image(systemName: "person.fill")
                                .font(AppFont.rounded(size: 20, weight: .medium))
                                .foregroundStyle(Color(red: 1, green: 0.45, blue: 0.008))
                                .frame(width: 28)
                            Text(L.string("display_name", language: appLanguageStorage))
                                .font(AppFont.rounded(size: 18, weight: .regular))
                                .foregroundStyle(.primary)
                            Spacer(minLength: 0)
                            TextField(L.string("display_name_placeholder", language: appLanguageStorage), text: $displayNameText)
                                .font(AppFont.rounded(size: 16, weight: .medium))
                                .foregroundStyle(AppColors.trailing)
                                .multilineTextAlignment(.trailing)
                                .submitLabel(.done)
                                .onSubmit { saveDisplayName() }
                        }
                        ProfileRowDivider()
                        NavigationLink {
                            ProfileVisibilityView(initialIsVisible: profileVisibilityIsVisible)
                        } label: {
                            SettingsRow(
                                icon: "person.2.fill",
                                title: L.string("profile_visibility", language: appLanguageStorage),
                                trailingValue: profileVisibilityTrailingValue.isEmpty ? L.string("private", language: appLanguageStorage) : profileVisibilityTrailingValue
                            )
                        }
                        .buttonStyle(.plain)
                        ProfileRowDivider()
                    }
                    Button {
                        showRejoyMeditationSheet = true
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "figure.mind.and.body")
                                .font(AppFont.rounded(size: 20, weight: .medium))
                                .foregroundStyle(Color(red: 1, green: 0.45, blue: 0.008))
                                .frame(width: 28)
                            Text(L.string("rejoy_meditation_time", language: appLanguageStorage))
                                .font(AppFont.rounded(size: 18, weight: .regular))
                                .foregroundStyle(.primary)
                            Spacer(minLength: 0)
                            if meditationEnabled {
                                Text(meditationTimeFormatted)
                                    .font(AppFont.rounded(size: 16, weight: .medium))
                                    .foregroundStyle(AppColors.trailing)
                            } else {
                                Text(L.string("not_set", language: appLanguageStorage))
                                    .font(AppFont.rounded(size: 16, weight: .semibold))
                                    .foregroundStyle(AppColors.rejoyOrange)
                            }
                            Image(systemName: "chevron.right")
                                .font(AppFont.rounded(size: 16, weight: .medium))
                                .foregroundStyle(AppColors.trailing)
                        }
                    }
                    .buttonStyle(.plain)
                    ProfileRowDivider()
                    NavigationLink {
                        AppLanguageView()
                    } label: {
                        SettingsRow(
                            icon: "globe",
                            title: L.string("app_language", language: appLanguageStorage),
                            trailingValue: AppLanguage(rawValue: appLanguageStorage)?.displayName ?? "System"
                        )
                    }
                    .buttonStyle(.plain)
                    ProfileRowDivider()
                    NavigationLink {
                        SettingsPermissionsView(
                            micStatus: $micStatus,
                            speechStatus: $speechStatus,
                            notificationStatus: $notificationStatus,
                            onRefresh: refreshPermissionStatus
                        )
                    } label: {
                        SettingsRow(icon: "hand.raised.fill", title: L.string("permissions", language: appLanguageStorage))
                    }
                    .buttonStyle(.plain)
                    ProfileRowDivider()
                    NavigationLink {
                        SettingsVoiceView(recognitionLocale: $recognitionLocale)
                    } label: {
                        SettingsRow(icon: "waveform", title: L.string("voice", language: appLanguageStorage))
                    }
                    .buttonStyle(.plain)
                    ProfileRowDivider()
                    NavigationLink {
                        SettingsActivityTypesView(
                            activityToDelete: $activityToDelete,
                            activityToEdit: $activityToEdit,
                            showAddActivity: $showAddActivity
                        )
                    } label: {
                        SettingsRow(icon: "list.bullet", title: L.string("activity_types", language: appLanguageStorage))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var logoutCard: some View {
        Button {
            showLogOutAlert = true
        } label: {
            Text(L.string("log_out", language: appLanguageStorage))
                .font(AppFont.rounded(size: 18, weight: .regular))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30))
    }

    private var profileFooter: some View {
        VStack(spacing: 2) {
            Text(L.string("rej", language: appLanguageStorage))
                .font(AppFont.rounded(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.sectionHeader)
            Text("Version \(appVersion)")
                .font(AppFont.rounded(size: 14, weight: .medium))
                .foregroundStyle(AppColors.sectionHeader)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var appLanguageSection: some View {
        Section {
            Picker(L.string("language", language: appLanguageStorage), selection: $appLanguageStorage) {
                Text("System").tag("")
                Text("English").tag("en")
                Text("Русский").tag("ru")
                Text("Українська").tag("uk")
            }
            .listRowBackground(AppColors.listRowBackground)
        } header: {
            Text(L.string("app_language", language: appLanguageStorage))
        } footer: {
            Text(L.string("language_description", language: appLanguageStorage))
        }
    }

    private var rejoyMeditationSection: some View {
        Section {
            Toggle(L.string("rejoy_meditation_enable", language: appLanguageStorage), isOn: $meditationEnabled)
                .tint(AppColors.rejoyOrange)
                .listRowBackground(AppColors.listRowBackground)
            if meditationEnabled {
                DatePicker("", selection: $meditationTime, displayedComponents: .hourAndMinute)
                    .listRowBackground(AppColors.listRowBackground)
            }
            Button(L.string("learn_more_rejoy_meditation", language: appLanguageStorage)) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showRejoyMeditationCarousel = true
            }
            .listRowBackground(AppColors.listRowBackground)
        } header: {
            Text(L.string("rejoy_meditation_time", language: appLanguageStorage))
        } footer: {
            Text(L.string("rejoy_meditation_description", language: appLanguageStorage))
        }
    }

    private var permissionsSection: some View {
        Section(L.string("permissions", language: appLanguageStorage)) {
            PermissionStatusRow(
                title: L.string("microphone", language: appLanguageStorage),
                message: L.string("record_voice", language: appLanguageStorage),
                icon: "mic.fill",
                status: micStatus,
                language: appLanguageStorage
            ) {
                requestMicPermission()
            }
            .listRowBackground(AppColors.listRowBackground)
            PermissionStatusRow(
                title: L.string("speech_recognition", language: appLanguageStorage),
                message: L.string("transcribe_dedication", language: appLanguageStorage),
                icon: "waveform",
                status: speechStatus,
                language: appLanguageStorage
            ) {
                requestSpeechPermission()
            }
            .listRowBackground(AppColors.listRowBackground)
            PermissionStatusRow(
                title: L.string("notifications", language: appLanguageStorage),
                message: L.string("daily_reminder", language: appLanguageStorage),
                icon: "bell.fill",
                status: notificationStatus,
                language: appLanguageStorage
            ) {
                requestNotificationPermission()
            }
            .listRowBackground(AppColors.listRowBackground)
        }
    }

    private var recognitionLanguageSection: some View {
        Section {
            Picker(L.string("recognition_language", language: appLanguageStorage), selection: $recognitionLocale) {
                Text(L.string("automatic_russian", language: appLanguageStorage)).tag("")
                Text(L.string("russian", language: appLanguageStorage)).tag("ru-RU")
                Text(L.string("english", language: appLanguageStorage)).tag("en-US")
                Text(L.string("ukrainian", language: appLanguageStorage)).tag("uk-UA")
            }
            .listRowBackground(AppColors.listRowBackground)
        } header: {
            Text(L.string("voice", language: appLanguageStorage))
        } footer: {
            Text(L.string("voice_footer", language: appLanguageStorage))
        }
    }

    private var seedsSection: some View {
        Section {
            HStack {
                Text(L.string("seeds_per_second", language: appLanguageStorage))
                Spacer()
                Text("\(AppSettings.seedsPerSecond)")
                    .foregroundStyle(AppColors.dotsSecondaryText)
            }
            .listRowBackground(AppColors.listRowBackground)
        } header: {
            Text(L.string("seeds", language: appLanguageStorage))
        } footer: {
            Text(L.string("seeds_description", language: appLanguageStorage))
        }
    }

    private var hiddenActivityIds: Set<UUID> {
        Set(hiddenActivityTypeIdsRaw.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
    }

    private var visibleActivities: [ActivityType] {
        activityTypes.filter { !hiddenActivityIds.contains($0.id) }
    }

    private var hiddenActivities: [ActivityType] {
        activityTypes.filter { hiddenActivityIds.contains($0.id) }
    }

    private var activityTypesSection: some View {
        Section(L.string("activity_types", language: appLanguageStorage)) {
            ForEach(visibleActivities) { activity in
                HStack {
                    Image(systemName: activity.symbolName)
                        .foregroundStyle(AppColors.rejoyOrange)
                        .frame(width: 28)
                    Text(L.activityName(activity.name, language: appLanguageStorage))
                    if activity.isBuiltIn || Self.builtInNames.contains(activity.name) {
                        Text(L.string("default", language: appLanguageStorage))
                            .font(AppFont.caption2)
                            .foregroundStyle(AppColors.dotsSecondaryText)
                    }
                    Spacer()
                    if !activity.isBuiltIn && !Self.builtInNames.contains(activity.name) {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            activityToEdit = activity
                        } label: {
                            Image(systemName: "pencil")
                                .font(AppFont.body)
                                .foregroundStyle(AppColors.dotsSecondaryText)
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        activityToDelete = activity
                    } label: {
                        Image(systemName: "trash")
                            .font(AppFont.body)
                            .foregroundStyle(AppColors.dotsSecondaryText)
                    }
                    .buttonStyle(.plain)
                }
                .listRowBackground(AppColors.listRowBackground)
            }
            .onMove(perform: moveActivities)
            Button(L.string("add_activity", language: appLanguageStorage)) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showAddActivity = true
            }
            .listRowBackground(AppColors.listRowBackground)
        }
        .onAppear {
            ActivityType.seedDefaultActivitiesIfNeeded(modelContext: modelContext)
        }
    }

    private var restoreActivitiesSection: some View {
        Group {
            if !hiddenActivities.isEmpty {
                Section {
                    ForEach(hiddenActivities) { activity in
                        HStack {
                            Image(systemName: activity.symbolName)
                                .foregroundStyle(AppColors.dotsSecondaryText)
                                .frame(width: 28)
                            Text(L.activityName(activity.name, language: appLanguageStorage))
                            Spacer()
                            Button(L.string("restore_activity", language: appLanguageStorage)) {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                var ids = hiddenActivityIds
                                ids.remove(activity.id)
                                hiddenActivityTypeIdsRaw = ids.map(\.uuidString).joined(separator: ",")
                            }
                            .foregroundStyle(AppColors.rejoyOrange)
                        }
                        .listRowBackground(AppColors.listRowBackground)
                    }
                }
            }
        }
    }

    private var aboutSection: some View {
        Section(L.string("about", language: appLanguageStorage)) {
            HStack {
                Text(L.string("rej", language: appLanguageStorage))
                Spacer()
                Text(L.string("version", language: appLanguageStorage))
                    .foregroundStyle(AppColors.dotsSecondaryText)
            }
            .listRowBackground(AppColors.listRowBackground)
            Text(L.string("about_description", language: appLanguageStorage))
                .font(AppFont.caption)
                .foregroundStyle(AppColors.dotsSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            .listRowBackground(AppColors.listRowBackground)
        }
    }

    private func saveDisplayName() {
        let trimmed = displayNameText.trimmingCharacters(in: .whitespacesAndNewlines)
        ProfileState.displayName = trimmed.isEmpty ? nil : trimmed
        if supabaseService.isSignedIn {
            Task {
                try? await SupabaseService.shared.upsertProfileDisplayName(ProfileState.displayName)
            }
        }
    }

    private func refreshPermissionStatus() {
        micStatus = PermissionStatus.fromAVAudio(AVAudioSession.sharedInstance().recordPermission)
        speechStatus = PermissionStatus.fromSpeech(SFSpeechRecognizer.authorizationStatus())
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationStatus = PermissionStatus.fromNotification(settings.authorizationStatus)
            }
        }
    }

    private func loadProfileVisibilityState() async {
        guard supabaseService.isSignedIn else {
            await MainActor.run {
                profileVisibilityIsVisible = nil
                profileVisibilityTrailingValue = ""
            }
            return
        }
        do {
            let sangha = try await SanghaService.shared.fetchMySangha()
            let membership = try await SanghaService.shared.fetchMyMembership()
            await MainActor.run {
                if let sangha = sangha, let m = membership {
                    profileVisibilityIsVisible = m.isVisible
                    profileVisibilityTrailingValue = m.isVisible ? L.string("public", language: appLanguageStorage) : L.string("private", language: appLanguageStorage)
                } else {
                    profileVisibilityIsVisible = nil
                    profileVisibilityTrailingValue = L.string("private", language: appLanguageStorage)
                }
            }
        } catch {
            await MainActor.run {
                profileVisibilityIsVisible = nil
                profileVisibilityTrailingValue = L.string("private", language: appLanguageStorage)
            }
        }
    }

    private func requestMicPermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { _ in
            DispatchQueue.main.async {
                refreshPermissionStatus()
            }
        }
    }

    private func requestSpeechPermission() {
        SFSpeechRecognizer.requestAuthorization { _ in
            DispatchQueue.main.async {
                refreshPermissionStatus()
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
            DispatchQueue.main.async {
                refreshPermissionStatus()
            }
        }
    }

    private static let builtInNames = ["Meditation", "Yoga", "Walking", "Running", "Work", "Cooking", "Reading", "Family", "Study"]

    private func performDelete(_ activity: ActivityType) {
        let isBuiltIn = activity.isBuiltIn || Self.builtInNames.contains(activity.name)
        if isBuiltIn {
            var ids = hiddenActivityIds
            ids.insert(activity.id)
            hiddenActivityTypeIdsRaw = ids.map(\.uuidString).joined(separator: ",")
        } else {
            modelContext.delete(activity)
        }
        try? modelContext.save()
    }

    private func moveActivities(from source: IndexSet, to destination: Int) {
        var reordered = visibleActivities
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, activity) in reordered.enumerated() {
            activity.sortOrder = index
        }
        try? modelContext.save()
    }
}

enum PermissionStatus {
    case granted
    case denied
    case notDetermined
    case unknown

    func localizedLabel(language: String) -> String {
        switch self {
        case .granted: return L.string("enabled", language: language)
        case .denied: return L.string("denied", language: language)
        case .notDetermined: return L.string("not_set", language: language)
        case .unknown: return L.string("unknown", language: language)
        }
    }

    var color: Color {
        switch self {
        case .granted: return AppColors.rejoyOrange
        case .denied: return Color(white: 0.5)
        case .notDetermined, .unknown: return AppColors.rejoyOrange
        }
    }

    static func fromAVAudio(_ status: AVAudioSession.RecordPermission) -> PermissionStatus {
        switch status {
        case .granted: return .granted
        case .denied: return .denied
        case .undetermined: return .notDetermined
        @unknown default: return .unknown
        }
    }

    static func fromSpeech(_ status: SFSpeechRecognizerAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized: return .granted
        case .denied: return .denied
        case .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .unknown
        }
    }

    static func fromNotification(_ status: UNAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized, .provisional, .ephemeral: return .granted
        case .denied: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .unknown
        }
    }
}

struct PermissionStatusRow: View {
    let title: String
    let message: String
    let icon: String
    let status: PermissionStatus
    let language: String
    let onEnable: () -> Void

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(AppColors.dotsSecondaryText)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.headline)
                Text(message)
                    .font(AppFont.caption)
                    .foregroundStyle(AppColors.dotsSecondaryText)
            }
            Spacer()
            if status == .granted {
                Text(status.localizedLabel(language: language))
                    .font(AppFont.caption)
                    .foregroundStyle(status.color)
            } else if status == .denied {
                Link(L.string("open_settings", language: language), destination: URL(string: UIApplication.openSettingsURLString)!)
                    .font(AppFont.caption)
            } else {
                Button(L.string("enable", language: language)) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onEnable()
                }
                .font(AppFont.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddActivityView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appLanguage) private var appLanguage
    @State private var name = ""
    @State private var symbolName = "star.fill"

    var body: some View {
        NavigationStack {
            Form {
                Section(L.string("activity", language: appLanguage)) {
                    TextField(L.string("name", language: appLanguage), text: $name)
                    Picker(L.string("icon", language: appLanguage), selection: $symbolName) {
                        ForEach(ActivitySymbolOptions.flatList, id: \.self) { symbol in
                            HStack {
                                Image(systemName: symbol)
                                Text(symbol)
                            }
                            .tag(symbol)
                        }
                    }
                }
            }
            .navigationTitle(L.string("add_activity", language: appLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.string("cancel", language: appLanguage)) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.string("save", language: appLanguage)) {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        let descriptor = FetchDescriptor<ActivityType>(sortBy: [SortDescriptor(\.sortOrder, order: .reverse)])
                        let existing = (try? modelContext.fetch(descriptor)) ?? []
                        let maxOrder = existing.first?.sortOrder ?? -1
                        let activity = ActivityType(name: name, symbolName: symbolName, sortOrder: maxOrder + 1, isBuiltIn: false)
                        modelContext.insert(activity)
                        try? modelContext.save()
                        if SupabaseService.shared.isSignedIn {
                            Task { try? await SupabaseService.shared.insertActivityType(activity) }
                        }
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

struct EditActivityView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appLanguage) private var appLanguage
    let activity: ActivityType
    @State private var name: String
    @State private var symbolName: String

    private var symbolOptions: [String] {
        ActivitySymbolOptions.allIncluding(activity.symbolName).flatMap { $0.symbols }
    }

    init(activity: ActivityType) {
        self.activity = activity
        _name = State(initialValue: activity.name)
        _symbolName = State(initialValue: activity.symbolName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L.string("activity", language: appLanguage)) {
                    TextField(L.string("name", language: appLanguage), text: $name)
                    Picker(L.string("icon", language: appLanguage), selection: $symbolName) {
                        ForEach(symbolOptions, id: \.self) { symbol in
                            HStack {
                                Image(systemName: symbol)
                                Text(symbol)
                            }
                            .tag(symbol)
                        }
                    }
                }
            }
            .navigationTitle(L.string("edit_activity", language: appLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.string("cancel", language: appLanguage)) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.string("save", language: appLanguage)) {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        activity.name = name
                        activity.symbolName = symbolName
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

private struct ProfileHeaderMinYKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
