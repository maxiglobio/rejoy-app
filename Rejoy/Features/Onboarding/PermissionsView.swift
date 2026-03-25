import SwiftUI
import UserNotifications

struct PermissionsView: View {
    let onContinue: () -> Void
    @Environment(\.appLanguage) private var appLanguage

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(L.string("permissions_intro", language: appLanguage))
                        .font(AppFont.subheadline)
                        .foregroundStyle(AppColors.dotsSecondaryText)
                }

                Section(L.string("permissions", language: appLanguage)) {
                    PermissionRow(
                        title: L.string("notifications", language: appLanguage),
                        message: L.string("notifications_nudges_message", language: appLanguage),
                        icon: "bell.fill"
                    )
                }

                Section {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        requestNotificationPermissionThenContinue()
                    } label: {
                        Text(L.string("permissions_continue", language: appLanguage))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.rejoyOrange)
                }
            }
            .navigationTitle(L.string("permissions", language: appLanguage))
        }
    }

    private func requestNotificationPermissionThenContinue() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                PushRegistrationService.registerForRemoteNotifications()
            }
            DispatchQueue.main.async {
                onContinue()
            }
        }
    }
}

struct PermissionRow: View {
    let title: String
    let message: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(AppColors.dotsSecondaryText)
                .frame(width: 32, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.headline)
                Text(message)
                    .font(AppFont.caption)
                    .foregroundStyle(AppColors.dotsSecondaryText)
            }
        }
    }
}
