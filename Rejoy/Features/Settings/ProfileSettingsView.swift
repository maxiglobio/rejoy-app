import SwiftUI
import SwiftData
import AVFoundation
import Speech
import UserNotifications
import UIKit

/// Settings hub (preferences + account) opened from the profile toolbar. Guide carousels live on the profile screen.
struct ProfileSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appLanguage") private var appLanguageStorage = ""
    @Query(sort: \ActivityType.sortOrder) private var activityTypes: [ActivityType]

    @ObservedObject private var supabaseService = SupabaseService.shared
    @State private var micStatus: PermissionStatus = .unknown
    @State private var speechStatus: PermissionStatus = .unknown
    @State private var notificationStatus: PermissionStatus = .unknown
    @State private var showAddActivity = false
    @State private var recognitionLocale: String = AppSettings.recognitionLocaleIdentifier
    @State private var meditationEnabled: Bool = false
    @State private var showNotificationDeniedAlert = false
    @State private var activityToDelete: ActivityType?
    @State private var activityToEdit: ActivityType?
    @State private var profileVisibilityTrailingValue: String = ""
    @State private var profileVisibilityIsVisible: Bool?
    @State private var showMeditationTimePicker = false
    @State private var showRejoyMeditationSheet = false
    @State private var displayNameText: String = ""
    @State private var meditationTime: Date = {
        let cal = Calendar.current
        var dc = DateComponents()
        dc.hour = 7
        dc.minute = 0
        return cal.date(from: dc) ?? Date()
    }()
    @State private var altarToggleUI = false
    @State private var showAltarActivateSheet = false
    @State private var showAltarDisableConfirm = false
    @State private var altarSettingsError = false

    private var meditationTimeFormatted: String {
        let cal = Calendar.current
        let h = cal.component(.hour, from: meditationTime)
        let m = cal.component(.minute, from: meditationTime)
        return String(format: "%d:%02d", h, m)
    }

    private var displayNameTrailingLabel: String {
        let t = displayNameText.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? L.string("not_set", language: appLanguageStorage) : t
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                settingsCardContent
                altarSettingsBlock
                accountCard
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 90)
        }
        .background(AppColors.background)
        .navigationTitle(L.string("settings", language: appLanguageStorage))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            refreshPermissionStatus()
            await SupabaseService.shared.fetchProfile()
            await MainActor.run {
                displayNameText = ProfileState.displayName ?? ""
                altarToggleUI = supabaseService.altarEnabled
            }
            await loadProfileVisibilityState()
        }
        .onAppear {
            refreshPermissionStatus()
            recognitionLocale = AppSettings.recognitionLocaleIdentifier
            displayNameText = ProfileState.displayName ?? ""
            altarToggleUI = supabaseService.altarEnabled
            Task {
                await SupabaseService.shared.fetchProfile()
                await MainActor.run {
                    displayNameText = ProfileState.displayName ?? ""
                    altarToggleUI = supabaseService.altarEnabled
                }
                await loadProfileVisibilityState()
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
        .onChange(of: recognitionLocale) { _, newValue in
            AppSettings.recognitionLocaleIdentifier = newValue
        }
        .onChange(of: meditationEnabled) { _, enabled in
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if enabled {
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
        .onChange(of: supabaseService.altarEnabled) { _, enabled in
            altarToggleUI = enabled
        }
        .onChange(of: altarToggleUI) { _, newValue in
            if newValue {
                if !supabaseService.altarEnabled {
                    showAltarActivateSheet = true
                    altarToggleUI = false
                }
            } else {
                if supabaseService.altarEnabled {
                    showAltarDisableConfirm = true
                    altarToggleUI = true
                }
            }
        }
        .sheet(isPresented: $showAltarActivateSheet) {
            AltarActivateConfirmationSheet(
                appLanguage: appLanguageStorage,
                onActivate: {
                    Task {
                        do {
                            try await supabaseService.setAltarEnabled(true)
                            await MainActor.run {
                                altarToggleUI = true
                                showAltarActivateSheet = false
                            }
                        } catch {
                            await MainActor.run {
                                altarSettingsError = true
                                showAltarActivateSheet = false
                            }
                        }
                    }
                },
                onCancel: {
                    showAltarActivateSheet = false
                }
            )
        }
        .alert(L.string("altar_disable_confirm_title", language: appLanguageStorage), isPresented: $showAltarDisableConfirm) {
            Button(L.string("cancel", language: appLanguageStorage), role: .cancel) {}
            Button(L.string("altar_turn_off", language: appLanguageStorage), role: .destructive) {
                Task {
                    do {
                        try await supabaseService.setAltarEnabled(false)
                        await MainActor.run { altarToggleUI = false }
                    } catch {
                        await MainActor.run { altarSettingsError = true }
                    }
                }
            }
        } message: {
            Text(L.string("altar_disable_confirm_message", language: appLanguageStorage))
        }
        .alert(L.string("altar_activate_error", language: appLanguageStorage), isPresented: $altarSettingsError) {
            Button(L.string("done", language: appLanguageStorage), role: .cancel) {}
        }
    }

    private var settingsCardContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            ProfileSectionHeader(title: L.string("settings", language: appLanguageStorage))
            ProfileCard {
                VStack(spacing: 14) {
                    if supabaseService.isSignedIn {
                        NavigationLink {
                            DisplayNameEditView(text: $displayNameText)
                        } label: {
                            SettingsRow(
                                icon: "person.fill",
                                title: L.string("display_name", language: appLanguageStorage),
                                trailingValue: displayNameTrailingLabel
                            )
                        }
                        .buttonStyle(.plain)
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
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

    private var altarSettingsBlock: some View {
        Group {
            if supabaseService.isSignedIn {
                VStack(alignment: .leading, spacing: 4) {
                    ProfileSectionHeader(title: L.string("altar_title", language: appLanguageStorage))
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(L.string("altar_title", language: appLanguageStorage))
                                    .font(AppFont.rounded(size: 18, weight: .regular))
                                    .foregroundStyle(.primary)
                                Text(L.string("altar_settings_description", language: appLanguageStorage))
                                    .font(AppFont.rounded(size: 13, weight: .regular))
                                    .foregroundStyle(AppColors.trailing)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 8)
                            Toggle("", isOn: $altarToggleUI)
                                .labelsHidden()
                                .tint(AppColors.rejoyOrange)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                }
            }
        }
    }

    private var accountCard: some View {
        NavigationLink {
            SettingsAccountView()
        } label: {
            HStack {
                Text(L.string("account", language: appLanguageStorage))
                    .font(AppFont.rounded(size: 18, weight: .regular))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(AppFont.rounded(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.trailing)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30))
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
                if sangha != nil, let m = membership {
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
}

// MARK: - Altar activation sheet (AltarForeground art)

struct AltarActivateConfirmationSheet: View {
    let appLanguage: String
    let onActivate: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Image("AltarForeground")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)

                    Text(L.string("altar_activate_sheet_title", language: appLanguage))
                        .font(AppFont.rounded(size: 22, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Text(L.string("altar_activate_sheet_body", language: appLanguage))
                        .font(AppFont.rounded(size: 16, weight: .regular))
                        .foregroundStyle(AppColors.trailing)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onActivate()
                    } label: {
                        Text(L.string("altar_activate_button", language: appLanguage))
                            .font(AppFont.rounded(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.rejoyOrange)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(AppColors.background)
            .navigationTitle(L.string("altar_title", language: appLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.string("cancel", language: appLanguage)) {
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Display name editor

struct DisplayNameEditView: View {
    @Binding var text: String
    @AppStorage("appLanguage") private var appLanguageStorage = ""
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var supabaseService = SupabaseService.shared

    var body: some View {
        Form {
            Section {
                TextField(L.string("display_name_placeholder", language: appLanguageStorage), text: $text)
                    .textInputAutocapitalization(.words)
                    .listRowBackground(AppColors.listRowBackground)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle(L.string("display_name", language: appLanguageStorage))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(L.string("done", language: appLanguageStorage)) {
                    save()
                    dismiss()
                }
            }
        }
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        text = trimmed
        ProfileState.displayName = trimmed.isEmpty ? nil : trimmed
        if supabaseService.isSignedIn {
            Task {
                try? await SupabaseService.shared.upsertProfileDisplayName(ProfileState.displayName)
            }
        }
    }
}
