import SwiftUI
import SwiftData
import AVFoundation
import Speech

private enum DedicationChromeStyle {
    /// Brand orange aligned with recording gradient top (#FF7A00)
    static let accentOrange = Color(red: 1, green: 122 / 255, blue: 0)
    static let onGradientPrimary = Color.primary.opacity(0.88)
    static let onGradientSecondary = Color.primary.opacity(0.72)
    static let onGradientTertiary = Color.primary.opacity(0.62)
}

/// No scale/opacity feedback on press (avoids distracting motion on the glass mic control).
private struct RecordingControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(1)
            .scaleEffect(1)
    }
}

struct DedicationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appLanguage) private var appLanguage
    let activity: ActivityType
    let durationSeconds: Int
    let wallClockStart: Date
    let seedsJarCoordinator: SeedsJarCoordinator
    let defaultDedicationText: String
    let onComplete: () -> Void

    @StateObject private var recorder = DedicationRecorder()
    @State private var dedicationText: String
    @State private var showConfetti = false

    init(activity: ActivityType, durationSeconds: Int, wallClockStart: Date, seedsJarCoordinator: SeedsJarCoordinator, defaultDedicationText: String, onComplete: @escaping () -> Void) {
        self.activity = activity
        self.durationSeconds = durationSeconds
        self.wallClockStart = wallClockStart
        self.seedsJarCoordinator = seedsJarCoordinator
        self.defaultDedicationText = defaultDedicationText
        self.onComplete = onComplete
        _dedicationText = State(initialValue: defaultDedicationText)
    }
    @State private var hasRecorded = false
    @State private var isTranscribing = false
    @State private var hasSaved = false
    /// Bumps SwiftUI to re-read mic/speech authorization after system prompts.
    @State private var permissionEpoch = 0

    private var seeds: Int { durationSeconds * AppSettings.seedsPerSecond }

    private var micPermission: AVAudioSession.RecordPermission {
        _ = permissionEpoch
        return AVAudioSession.sharedInstance().recordPermission
    }

    private var speechAuthorization: SFSpeechRecognizerAuthorizationStatus {
        _ = permissionEpoch
        return SFSpeechRecognizer.authorizationStatus()
    }

    private enum VoicePermissionPhase {
        case ready
        case needsSystemPrompt
        case blocked
    }

    private var voicePermissionPhase: VoicePermissionPhase {
        let mic = micPermission
        let speech = speechAuthorization
        if mic == .denied || speech == .denied || speech == .restricted {
            return .blocked
        }
        if mic == .undetermined || speech == .notDetermined {
            return .needsSystemPrompt
        }
        if mic == .granted && speech == .authorized {
            return .ready
        }
        return .blocked
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if recorder.isRecording {
                    RecordingAmbienceBackground()
                }

                ScrollView {
                    VStack(spacing: 28) {
                        activityHeader
                        seedsBadge

                        switch voicePermissionPhase {
                        case .ready, .needsSystemPrompt:
                            voiceRecordSection
                        case .blocked:
                            voiceBlockedSection
                        }

                        dedicationTextField

                        Spacer(minLength: 24)

                        saveSection
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)

                if showConfetti {
                    ConfettiView()
                        .allowsHitTesting(false)
                }
            }
            .navigationTitle(L.string("dedication", language: appLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L.string("done", language: appLanguage)) {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
        }
    }

    private var activityHeader: some View {
        VStack(spacing: 8) {
            Text(L.activityName(activity.name, language: appLanguage))
                .font(AppFont.title2)
                .fontWeight(.semibold)
                .foregroundStyle(DedicationChromeStyle.onGradientPrimary)
            Image(systemName: activity.symbolName)
                .font(AppFont.rounded(size: 40))
                .foregroundStyle(recorder.isRecording ? Color.white : DedicationChromeStyle.accentOrange)
        }
    }

    private var seedsBadge: some View {
        Text(String(format: L.string("seeds_count", language: appLanguage), seeds))
            .font(AppFont.title3)
            .foregroundStyle(DedicationChromeStyle.onGradientSecondary)
    }

    private var voiceRecordSection: some View {
        VStack(spacing: 16) {
            if !hasRecorded {
                let needsSetup = voicePermissionPhase == .needsSystemPrompt
                Text(needsSetup ? L.string("voice_permissions_tap_mic_hint", language: appLanguage) : L.string("record_dedication", language: appLanguage))
                    .font(AppFont.headline)
                    .foregroundStyle(DedicationChromeStyle.onGradientSecondary)
                    .multilineTextAlignment(.center)

                Button {
                    if needsSetup && !recorder.isRecording {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        requestMicrophoneThenSpeechAuthorization()
                        return
                    }
                    if recorder.isRecording {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        isTranscribing = true
                        recorder.stopRecordingAndTranscribe { text in
                            isTranscribing = false
                            if let text = text, !text.isEmpty {
                                dedicationText = text
                            }
                            hasRecorded = true
                        }
                    } else {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        recorder.startRecording()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .blendMode(.plusLighter)

                        if isTranscribing {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                                .scaleEffect(1.2)
                        } else {
                            Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                                .font(AppFont.rounded(size: 48))
                                .foregroundStyle(recorder.isRecording ? Color.black : DedicationChromeStyle.accentOrange)
                        }
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.1), radius: 16, x: 0, y: 8)
                }
                .buttonStyle(RecordingControlButtonStyle())
                .disabled(isTranscribing)

                Group {
                    if recorder.isRecording {
                        Text(L.string("tap_to_stop", language: appLanguage))
                    } else if needsSetup {
                        Text(L.string("voice_permissions_allow_when_prompted", language: appLanguage))
                    } else {
                        Text(L.string("tap_to_record", language: appLanguage))
                    }
                }
                .font(AppFont.subheadline)
                .foregroundStyle(DedicationChromeStyle.onGradientTertiary)
                .multilineTextAlignment(.center)

                if let error = recorder.errorMessage {
                    Text(error)
                        .font(AppFont.caption)
                        .foregroundStyle(Color.primary.opacity(0.55))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var voiceBlockedSection: some View {
        VStack(spacing: 12) {
            Text(L.string("voice_permissions_denied_hint", language: appLanguage))
                .font(AppFont.subheadline)
                .foregroundStyle(DedicationChromeStyle.onGradientSecondary)
                .multilineTextAlignment(.center)
            Text(L.string("type_dedication", language: appLanguage))
                .font(AppFont.caption)
                .foregroundStyle(DedicationChromeStyle.onGradientTertiary)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text(L.string("open_settings", language: appLanguage))
                    .font(AppFont.headline)
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func requestMicrophoneThenSpeechAuthorization() {
        let audio = AVAudioSession.sharedInstance()
        if audio.recordPermission == .undetermined {
            audio.requestRecordPermission { _ in
                DispatchQueue.main.async {
                    permissionEpoch += 1
                    guard AVAudioSession.sharedInstance().recordPermission == .granted else { return }
                    requestSpeechAuthorizationIfNeeded()
                }
            }
        } else {
            requestSpeechAuthorizationIfNeeded()
        }
    }

    private func requestSpeechAuthorizationIfNeeded() {
        guard AVAudioSession.sharedInstance().recordPermission == .granted else {
            permissionEpoch += 1
            return
        }
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            SFSpeechRecognizer.requestAuthorization { _ in
                DispatchQueue.main.async {
                    permissionEpoch += 1
                }
            }
        } else {
            permissionEpoch += 1
        }
    }

    private var dedicationTextField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.string("dedication", language: appLanguage))
                .font(AppFont.headline)
                .foregroundStyle(DedicationChromeStyle.onGradientPrimary)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.72))
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.thinMaterial)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.gray.opacity(0.32), lineWidth: 1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 200)
                TextEditor(text: $dedicationText)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(Color.primary.opacity(0.88))
                    .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                    .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 200, alignment: .topLeading)
                    .disabled(recorder.isRecording)
            }
            .frame(maxWidth: .infinity)
            .opacity(recorder.isRecording ? 0.66 : 1)
        }
    }

    private var saveSection: some View {
        let voiceBusy = recorder.isRecording || isTranscribing
        let disabled = hasSaved || voiceBusy
        return Button {
            guard !hasSaved else { return }
            hasSaved = true
            let durationMinutes = durationSeconds / 60
            saveSession()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showConfetti = true
            seedsJarCoordinator.addSeeds(durationMinutes: durationMinutes)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                onComplete()
            }
        } label: {
            Text(L.string("save_seeds", language: appLanguage))
                .font(AppFont.headline)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .buttonStyle(.borderedProminent)
        .tint(AppColors.rejoyOrange)
        .disabled(disabled)
        .opacity(disabled && !hasSaved ? 0.45 : 1)
    }

    private func saveSession() {
        let endDate = Date()
        var startDate = wallClockStart
        if startDate >= endDate {
            startDate = endDate.addingTimeInterval(-Double(durationSeconds))
        } else {
            // Manual duration can exceed wall-clock tracking span; attribution uses min(duration, span).
            // Shift start back so the saved interval covers the full adjusted practice time.
            let spanSeconds = Int(endDate.timeIntervalSince(startDate))
            if durationSeconds > spanSeconds {
                startDate = endDate.addingTimeInterval(-Double(durationSeconds))
            }
        }
        let session = Session(
            activityTypeId: activity.id,
            startDate: startDate,
            endDate: endDate,
            durationSeconds: durationSeconds,
            seeds: seeds,
            dedicationText: dedicationText
        )
        modelContext.insert(session)
        try? modelContext.save()

        // Sync to Supabase when signed in
        if SupabaseService.shared.isSignedIn {
            Task {
                try? await SupabaseService.shared.insertSession(session)
            }
        }
    }
}
