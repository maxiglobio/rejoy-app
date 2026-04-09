import SwiftUI
import SwiftData
import AVFoundation
import Speech
import UIKit

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

/// Soft white ripples that expand from the mic/stop button and fade out one after another.
/// Uses **thick strokes** and **moderate** blur so rings stay visible on the orange gradient (thin stroke + heavy blur was effectively invisible).
/// Opacity uses sin(π·phase) so fade-in/out are smooth and phase wrap has **no** instant jump (unlike linear 1 − p).
/// Kept outside the `Button` label so nothing clips the halo.
private struct RecordingEnergyAura: View {
    private let rippleCount = 4
    private let cycle: TimeInterval = 3.4

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<rippleCount, id: \.self) { index in
                    let stagger = Double(index) / Double(rippleCount)
                    let phase = (t / cycle + stagger).truncatingRemainder(dividingBy: 1)
                    let p = CGFloat(phase)
                    // Smooth bell-shaped envelope: 0 at p=0 and p=1, peak mid-cycle — continuous at wrap.
                    let envelope = pow(sin(Double(p) * .pi), 0.82)
                    // Ease scale so expansion eases in/out (derivative ~0 at endpoints feels softer).
                    let pEase = CGFloat((1 - cos(Double(p) * .pi)) / 2)
                    // Extra falloff as the ring expands: outer / far radii lose opacity earlier (before max radius).
                    let outerFalloff = 1.0 - 0.52 * pow(Double(pEase), 1.38)
                    let fade = max(0, envelope * outerFalloff)
                    ZStack {
                        // Soft outer halo: radial fill that grows with the pulse (reads on orange).
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(0.2 * fade),
                                        Color.white.opacity(0.07 * fade),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 52,
                                    endRadius: 95 + pEase * 135
                                )
                            )
                            .frame(width: 120, height: 120)
                            .scaleEffect(1.0 + pEase * 1.95)
                            .blur(radius: 2 + CGFloat(fade) * 4)
                        // Ring edge: thick stroke + light blur so the band stays readable.
                        Circle()
                            .stroke(
                                Color.white.opacity(0.62 * fade),
                                lineWidth: 9 + pEase * 7
                            )
                            .frame(width: 118, height: 118)
                            .scaleEffect(1.0 + pEase * 2.0)
                            .blur(radius: 2 + CGFloat(fade) * 5)
                    }
                }
            }
            .frame(width: 440, height: 440)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct DedicationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appLanguage) private var appLanguage
    @Environment(\.colorScheme) private var colorScheme
    let activity: ActivityType
    let durationSeconds: Int
    let wallClockStart: Date
    let seedsJarCoordinator: SeedsJarCoordinator
    let defaultDedicationText: String
    let onComplete: (UUID) -> Void

    @StateObject private var recorder = DedicationRecorder()
    @State private var dedicationText: String
    @State private var showConfetti = false

    init(activity: ActivityType, durationSeconds: Int, wallClockStart: Date, seedsJarCoordinator: SeedsJarCoordinator, defaultDedicationText: String, onComplete: @escaping (UUID) -> Void) {
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
    @FocusState private var dedicationFieldFocused: Bool
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

                Group {
                    if recorder.isRecording {
                        dictationRecordingLayout
                    } else {
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

                                // Tap empty space below the field to dismiss keyboard (toolbar "Done" also dismisses).
                                if dedicationFieldFocused {
                                    Color.clear
                                        .frame(minHeight: 120)
                                        .frame(maxWidth: .infinity)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            dedicationFieldFocused = false
                                        }
                                        .accessibilityHidden(true)
                                }

                                saveSection
                            }
                            .padding()
                            .padding(.bottom, 8)
                        }
                        .scrollDismissesKeyboard(.interactively)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if showConfetti {
                    ConfettiView()
                        .allowsHitTesting(false)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L.string("done", language: appLanguage)) {
                        dedicationFieldFocused = false
                    }
                }
            }
        }
    }

    private var activityHeader: some View {
        VStack(spacing: 8) {
            Text(String(format: L.string("dedication_for_activity", language: appLanguage), L.activityName(activity.name, language: appLanguage)))
                .font(AppFont.title2)
                .fontWeight(.semibold)
                .foregroundStyle(recorder.isRecording ? Color.white : DedicationChromeStyle.onGradientPrimary)
                .shadow(color: recorder.isRecording ? Color.black.opacity(0.25) : .clear, radius: 2, x: 0, y: 1)
                .multilineTextAlignment(.center)
            Image(systemName: activity.symbolName)
                .font(AppFont.rounded(size: 40))
                .foregroundStyle(recorder.isRecording ? Color.white : DedicationChromeStyle.accentOrange)
        }
    }

    private var seedsBadge: some View {
        Text(String(format: L.string("seeds_count", language: appLanguage), seeds))
            .font(AppFont.title3)
            .foregroundStyle(recorder.isRecording ? Color.white.opacity(0.92) : DedicationChromeStyle.onGradientSecondary)
            .shadow(color: recorder.isRecording ? Color.black.opacity(0.2) : .clear, radius: 2, x: 0, y: 1)
    }

    /// While dictating: header + seeds at top, energy around the mic, stop control pinned toward the bottom (thumb zone). No live transcript on screen.
    private var dictationRecordingLayout: some View {
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                activityHeader
                seedsBadge
            }
            Spacer(minLength: 16)
            voiceRecordSection
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var voiceRecordSection: some View {
        VStack(spacing: 16) {
            if !hasRecorded {
                let needsSetup = voicePermissionPhase == .needsSystemPrompt
                if needsSetup {
                    Text(L.string("voice_permissions_tap_mic_hint", language: appLanguage))
                        .font(AppFont.headline)
                        .foregroundStyle(DedicationChromeStyle.onGradientSecondary)
                        .multilineTextAlignment(.center)
                }

                ZStack {
                    if recorder.isRecording && !isTranscribing {
                        RecordingEnergyAura()
                            .zIndex(0)
                            .layoutPriority(1)
                    }
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
                            if recorder.isRecording && !isTranscribing {
                                Circle()
                                    .fill(Color.white)
                            } else {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .blendMode(.plusLighter)
                            }

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
                    .zIndex(1)
                }

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
                .fontWeight(recorder.isRecording ? .semibold : .regular)
                .foregroundStyle(recorder.isRecording ? Color.white.opacity(0.95) : DedicationChromeStyle.onGradientTertiary)
                .shadow(color: recorder.isRecording ? Color.black.opacity(0.35) : .clear, radius: 3, x: 0, y: 1)
                .multilineTextAlignment(.center)

                if let error = recorder.errorMessage {
                    Text(error)
                        .font(AppFont.caption)
                        .foregroundStyle(Color.primary.opacity(0.55))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, recorder.isRecording ? 8 : 24)
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

    /// Text editor surface: dark mode uses a recessed charcoal fill; light mode uses a light card.
    private var dedicationFieldFill: Color {
        switch colorScheme {
        case .dark:
            return Color(white: 0.17)
        case .light:
            return Color.white.opacity(0.72)
        @unknown default:
            return Color.white.opacity(0.72)
        }
    }

    private var dedicationFieldStroke: Color {
        switch colorScheme {
        case .dark:
            return Color.white.opacity(0.14)
        case .light:
            return Color.gray.opacity(0.32)
        @unknown default:
            return Color.gray.opacity(0.32)
        }
    }

    private var dedicationFieldTextColor: Color {
        switch colorScheme {
        case .dark:
            return Color.white.opacity(0.94)
        case .light:
            return Color.primary.opacity(0.9)
        @unknown default:
            return Color.primary.opacity(0.9)
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
                    .fill(dedicationFieldFill)
                    .background {
                        if colorScheme == .light {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.thinMaterial)
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(dedicationFieldStroke, lineWidth: 1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 200)
                TextEditor(text: $dedicationText)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(dedicationFieldTextColor)
                    .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                    .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 200, alignment: .topLeading)
                    .focused($dedicationFieldFocused)
                // TextEditor often hit-tests only the glyphs; this fills the framed area so any tap focuses and shows the keyboard.
                if !dedicationFieldFocused {
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 200)
                        .onTapGesture {
                            dedicationFieldFocused = true
                        }
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var saveSection: some View {
        let voiceBusy = recorder.isRecording || isTranscribing
        let disabled = hasSaved || voiceBusy
        return Button {
            guard !hasSaved else { return }
            hasSaved = true
            let durationMinutes = durationSeconds / 60
            let savedSessionId = saveSession()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showConfetti = true
            seedsJarCoordinator.addSeeds(durationMinutes: durationMinutes)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                onComplete(savedSessionId)
            }
        } label: {
            Text(L.string("save_seeds", language: appLanguage))
                .font(AppFont.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .buttonStyle(.borderedProminent)
        .tint(AppColors.rejoyOrange)
        .disabled(disabled)
        .opacity(disabled && !hasSaved ? 0.45 : 1)
    }

    private func saveSession() -> UUID {
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
        let savedId = session.id
        modelContext.insert(session)
        try? modelContext.save()

        // Sync to Supabase when signed in
        if SupabaseService.shared.isSignedIn {
            Task {
                try? await SupabaseService.shared.insertSession(session)
            }
        }
        return savedId
    }

}
