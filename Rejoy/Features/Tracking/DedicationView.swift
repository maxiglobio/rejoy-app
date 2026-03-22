import SwiftUI
import SwiftData
import AVFoundation
import Speech

struct DedicationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appLanguage) private var appLanguage
    let activity: ActivityType
    let durationSeconds: Int
    let seedsJarCoordinator: SeedsJarCoordinator
    let defaultDedicationText: String
    let onComplete: () -> Void

    @StateObject private var recorder = DedicationRecorder()
    @State private var dedicationText: String
    @State private var showConfetti = false

    init(activity: ActivityType, durationSeconds: Int, seedsJarCoordinator: SeedsJarCoordinator, defaultDedicationText: String, onComplete: @escaping () -> Void) {
        self.activity = activity
        self.durationSeconds = durationSeconds
        self.seedsJarCoordinator = seedsJarCoordinator
        self.defaultDedicationText = defaultDedicationText
        self.onComplete = onComplete
        _dedicationText = State(initialValue: defaultDedicationText)
    }
    @State private var hasRecorded = false
    @State private var isTranscribing = false
    @State private var hasSaved = false

    private var seeds: Int { durationSeconds * AppSettings.seedsPerSecond }
    private var canUseVoice: Bool { recorder.canRecord }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 28) {
                        activityHeader
                        seedsBadge

                        if canUseVoice {
                            recordSection
                        } else {
                            typedFallbackSection
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
            Image(systemName: activity.symbolName)
                .font(AppFont.rounded(size: 40))
                .foregroundStyle(AppColors.rejoyOrange)
        }
    }

    private var seedsBadge: some View {
        Text(String(format: L.string("seeds_count", language: appLanguage), seeds))
            .font(AppFont.title3)
            .foregroundStyle(AppColors.dotsSecondaryText)
    }

    private var recordSection: some View {
        VStack(spacing: 16) {
            if !hasRecorded {
                Text(L.string("record_dedication", language: appLanguage))
                    .font(AppFont.headline)
                    .foregroundStyle(AppColors.dotsSecondaryText)

                Button {
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
                            .fill(recorder.isRecording ? Color(red: 0.7, green: 0.35, blue: 0) : AppColors.rejoyOrange.opacity(0.9))
                            .frame(width: 120, height: 120)
                            .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)

                        if isTranscribing {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                                .scaleEffect(1.2)
                        } else {
                            Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                                .font(AppFont.rounded(size: 48))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isTranscribing)

                Text(recorder.isRecording ? L.string("tap_to_stop", language: appLanguage) : L.string("tap_to_record", language: appLanguage))
                    .font(AppFont.subheadline)
                    .foregroundStyle(AppColors.dotsSecondaryText)

                if let error = recorder.errorMessage {
                    Text(error)
                        .font(AppFont.caption)
                        .foregroundStyle(Color(white: 0.5))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var typedFallbackSection: some View {
        VStack(spacing: 8) {
            Text(L.string("microphone_unavailable", language: appLanguage))
                .font(AppFont.subheadline)
                .foregroundStyle(AppColors.dotsSecondaryText)
            Text(L.string("type_dedication", language: appLanguage))
                .font(AppFont.caption)
                .foregroundStyle(AppColors.dotsSecondaryText)
        }
    }

    private var dedicationTextField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.string("dedication", language: appLanguage))
                .font(AppFont.headline)
            TextEditor(text: $dedicationText)
                .frame(minHeight: 100, maxHeight: 200)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(AppColors.listRowBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var saveSection: some View {
        Button {
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
        .disabled(hasSaved)
    }

    private func saveSession() {
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-Double(durationSeconds))
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
