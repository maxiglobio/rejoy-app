import SwiftUI
import AVFoundation
import Speech
import UserNotifications

struct SettingsPermissionsView: View {
    @Binding var micStatus: PermissionStatus
    @Binding var speechStatus: PermissionStatus
    @Binding var notificationStatus: PermissionStatus
    @AppStorage("appLanguage") private var appLanguageStorage = ""
    let onRefresh: () -> Void
    @State private var showNotificationDeniedAlert = false

    var body: some View {
        Form {
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
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle(L.string("permissions", language: appLanguageStorage))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            onRefresh()
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

    private func requestMicPermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { _ in
            DispatchQueue.main.async { onRefresh() }
        }
    }

    private func requestSpeechPermission() {
        SFSpeechRecognizer.requestAuthorization { _ in
            DispatchQueue.main.async { onRefresh() }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async {
                onRefresh()
                if !granted {
                    showNotificationDeniedAlert = true
                }
            }
        }
    }
}
