import SwiftUI
import SwiftData
import AVFoundation
import Speech
import UserNotifications
import UIKit

struct SettingsView: View {
    var selectedTab: Int = 0
    var onOpenDate: ((Date) -> Void)? = nil

    @AppStorage("appLanguage") private var appLanguageStorage = ""
    @AppStorage("rejoyedSessionIds") private var rejoyedIdsRaw = ""
    @Query(sort: \Session.startDate, order: .reverse) private var allSessions: [Session]
    @Query(sort: \ActivityType.sortOrder, order: .reverse) private var activityTypes: [ActivityType]

    @StateObject private var profileState = ProfileState.shared
    @ObservedObject private var supabaseService = SupabaseService.shared
    @ObservedObject private var altarFocus = AltarFocusController.shared

    private enum ProfileMainSegment: Int, CaseIterable {
        case profile = 0
        case altar = 1
    }

    @State private var profileMainSegment: ProfileMainSegment = .profile
    @State private var selectedAchievement: Achievement?
    @State private var selectedAchievementUnlockedAt: Date?
    @State private var showRewardsGallery = false
    @State private var achievementRefreshTrigger = UUID()
    @State private var showHowToUseRejoyCarousel = false
    @State private var showRejoyMeditationCarousel = false
    @State private var showSeedsInfoCarousel = false

    @Environment(\.openURL) private var openURL

    private enum SupportContact {
        static let emailURL = URL(string: "mailto:maxim@globio.io")!
        static let telegramURL = URL(string: "https://t.me/maximshishkinv")!
    }

    private func seedsForMonth(_ date: Date) -> Int {
        let cal = Calendar.current
        guard let start = cal.date(from: cal.dateComponents([.year, .month], from: date)),
              let end = cal.date(byAdding: .month, value: 1, to: start) else { return 0 }
        return allSessions.reduce(0) { partial, session in
            partial + SessionDayAttribution.attributedSeeds(for: session, inMonthStartingAt: start, calendar: cal)
        }
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

    private var monthSeedsFormatted: String {
        formatSeeds(monthSeeds)
    }

    private var rejoyedSessionIds: Set<UUID> {
        Set(rejoyedIdsRaw.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
    }

    private var showProfileAltarTabs: Bool {
        supabaseService.isSignedIn && supabaseService.altarEnabled
    }

    private func syncAltarFocusState() {
        let focused = showProfileAltarTabs && profileMainSegment == .altar
        AltarFocusController.shared.setAltarFocused(focused)
    }

    var body: some View {
        NavigationStack {
            Group {
                if showProfileAltarTabs {
                    GeometryReader { geo in
                        let w = geo.size.width
                        let h = geo.size.height
                        HStack(spacing: 0) {
                            ScrollView(showsIndicators: false) {
                                profileScrollStack
                                    .frame(width: w)
                            }
                            .coordinateSpace(name: "profileScroll")
                            .frame(width: w, height: h)
                            AltarEditorContent()
                                .frame(width: w, height: h)
                        }
                        .offset(x: profileMainSegment == .profile ? 0 : -w)
                        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: profileMainSegment)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        profileScrollStack
                    }
                    .coordinateSpace(name: "profileScroll")
                }
            }
            .onPreferenceChange(ProfileHeaderMinYKey.self) { profileHeaderMinY = $0 }
            .refreshable {
                await SupabaseService.shared.fetchProfile()
                await AchievementService.syncCountsFromSupabase()
                await MainActor.run {
                    achievementRefreshTrigger = UUID()
                }
            }
            .background(AppColors.background)
            .navigationTitle(showProfileAltarTabs ? "" : L.string("profile", language: appLanguageStorage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(altarFocus.isAltarFocused ? .hidden : .visible, for: .tabBar)
            .toolbarBackground(altarFocus.isAltarFocused ? .hidden : .visible, for: .tabBar)
            .animation(.easeInOut(duration: 0.28), value: altarFocus.isAltarFocused)
            .overlay {
                if !showProfileAltarTabs || profileMainSegment == .profile {
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
            }
            .animation(.easeInOut(duration: 0.25), value: headerScrollProgress)
            .animation(.easeInOut(duration: 0.28), value: profileMainSegment)
            .toolbar {
                if profileMainSegment == .profile {
                    ToolbarItem(placement: .navigationBarLeading) {
                        ShareLink(
                            item: "\(String(format: L.string("share_app_message_with_seeds", language: appLanguageStorage), monthSeedsFormatted))\(LegalDocumentLinks.appStore.absoluteString)",
                            subject: Text(L.string("share_app", language: appLanguageStorage))
                        ) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
                if showProfileAltarTabs {
                    ToolbarItem(placement: .principal) {
                        Picker("", selection: $profileMainSegment) {
                            Text(L.string("profile", language: appLanguageStorage)).tag(ProfileMainSegment.profile)
                            Text(L.string("altar_title", language: appLanguageStorage)).tag(ProfileMainSegment.altar)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 280)
                    }
                }
                if profileMainSegment == .profile {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink {
                            ProfileSettingsView()
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .onChange(of: supabaseService.altarEnabled) { _, enabled in
                if !enabled { profileMainSegment = .profile }
                syncAltarFocusState()
            }
            .onChange(of: supabaseService.isSignedIn) { _, signedIn in
                if !signedIn { profileMainSegment = .profile }
                syncAltarFocusState()
            }
            .onChange(of: profileMainSegment) { _, _ in
                syncAltarFocusState()
            }
            .onDisappear {
                AltarFocusController.shared.setAltarFocused(false)
            }
            .onAppear {
                syncAltarFocusState()
                DispatchQueue.main.async { Slide2VideoPreloader.shared.preload() }
                Task {
                    await SupabaseService.shared.fetchProfile()
                    await AchievementService.syncCountsFromSupabase()
                    await MainActor.run {
                        achievementRefreshTrigger = UUID()
                    }
                }
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
        }
    }

    private var profileScrollStack: some View {
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
            activityBalanceSectionContent
            supportSectionContent
            profileFooter
                .padding(.top, -12)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 72)
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

    private var activityBalanceSectionContent: some View {
        ActivityBalanceSection(
            sessions: allSessions,
            activityTypes: activityTypes,
            appLanguage: appLanguageStorage
        )
    }

    private var supportSectionContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            ProfileSectionHeader(title: L.string("support_section", language: appLanguageStorage))
            supportGuideList
            supportContactBlock
        }
    }

    /// Thumbnail width + `HStack` spacing — divider starts where the title text begins (iOS grouped list style).
    private var supportGuideDividerLeadingInset: CGFloat { 82 + 12 }

    private var supportGuideList: some View {
        ProfileCard {
            VStack(spacing: 0) {
                supportGuideRow(
                    imageName: "HowToUseRejoyCover",
                    title: L.string("how_to_use_rejoy", language: appLanguageStorage),
                    subtitle: L.string("how_to_use_rejoy_explainer", language: appLanguageStorage)
                ) {
                    showHowToUseRejoyCarousel = true
                }
                supportGuideInsetDivider
                supportGuideRow(
                    imageName: "HowToMeditate",
                    title: L.string("how_to_meditate", language: appLanguageStorage),
                    subtitle: L.string("accumulating_sheet_explainer", language: appLanguageStorage)
                ) {
                    showRejoyMeditationCarousel = true
                }
                supportGuideInsetDivider
                supportGuideRow(
                    imageName: "WhatAreSeeds",
                    title: L.string("what_is_seeds", language: appLanguageStorage),
                    subtitle: L.string("what_is_seeds_explainer", language: appLanguageStorage)
                ) {
                    showSeedsInfoCarousel = true
                }
            }
        }
    }

    private var supportGuideInsetDivider: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: supportGuideDividerLeadingInset)
            Rectangle()
                .fill(AppColors.rowDivider)
                .frame(height: 1.0 / max(UIScreen.main.scale, 1))
        }
        .frame(maxWidth: .infinity)
    }

    private func supportGuideRow(imageName: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 17)
                        .fill(AppColors.cardBackground)
                        .frame(width: 82, height: 105)
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 82, height: 105)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppFont.rounded(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
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
            .contentShape(Rectangle())
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    private var supportContactBlock: some View {
        VStack(spacing: 16) {
            Text(L.string("support_contact_intro", language: appLanguageStorage))
                .font(AppFont.rounded(size: 14, weight: .regular))
                .foregroundStyle(AppColors.sectionHeader)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
            HStack(spacing: 12) {
                supportContactOutlineButton(
                    icon: "envelope.fill",
                    title: L.string("support_contact_email", language: appLanguageStorage)
                ) {
                    openURL(SupportContact.emailURL)
                }
                supportContactOutlineButton(
                    icon: "paperplane.fill",
                    title: L.string("support_contact_telegram", language: appLanguageStorage)
                ) {
                    openURL(SupportContact.telegramURL)
                }
            }
            .padding(.horizontal, 28)
        }
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private func supportContactOutlineButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(AppFont.rounded(size: 16, weight: .semibold))
                Text(title)
                    .font(AppFont.rounded(size: 15, weight: .semibold))
            }
            .foregroundStyle(AppColors.rejoyOrange)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppColors.rejoyOrange.opacity(0.45), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
        .padding(.top, 4)
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
    /// Invoked for microphone, speech, or notifications when status is not yet determined (shows system request).
    let onContinueToSystemRequest: () -> Void

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
                // Guideline 5.1.1(iv): use neutral labels (Continue / Next), not "Enable", before system permission sheets.
                Button(L.string("permissions_continue", language: language)) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onContinueToSystemRequest()
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
