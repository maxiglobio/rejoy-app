import SwiftUI
import SwiftData
import UserNotifications
import UIKit

class RejoyAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        AvatarImageCache.configure()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Task { @MainActor in
            await SupabaseService.shared.savePushToken(token)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Expected on simulator; ignore
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
}

@main
struct RejoyApp: App {
    @UIApplicationDelegateAdaptor(RejoyAppDelegate.self) var appDelegate
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false

    init() {
        let style = UITraitCollection.current.userInterfaceStyle
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(
            style: style == .dark ? .systemChromeMaterialDark : .systemChromeMaterialLight
        )
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.secondaryLabel
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.secondaryLabel]
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.label
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.label]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().itemSpacing = 24
    }
    @AppStorage("hasSeenPermissions") private var hasSeenPermissions = false
    @AppStorage("hasCompletedStories") private var hasCompletedStories = false
    @AppStorage("appLanguage") private var appLanguage = ""

    var body: some Scene {
        WindowGroup {
            RootContentView(
                hasSeenWelcome: $hasSeenWelcome,
                hasSeenPermissions: $hasSeenPermissions,
                hasCompletedStories: $hasCompletedStories,
                appLanguage: appLanguage
            )
            .tint(.primary)
            .environment(\.appLanguage, appLanguage)
            .modelContainer(LocalStore.shared.modelContainer)
        }
    }
}

struct RootContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var authService = SupabaseService.shared
    @Binding var hasSeenWelcome: Bool
    @Binding var hasSeenPermissions: Bool
    @Binding var hasCompletedStories: Bool
    let appLanguage: String

    var body: some View {
        Group {
            if authService.isSignedIn {
                if !hasSeenPermissions {
                    PermissionsView {
                        hasSeenPermissions = true
                    }
                } else {
                    MainTabView()
                }
            } else {
                if !hasCompletedStories {
                    IntroCarouselView(onComplete: {
                        hasCompletedStories = true
                    })
                } else {
                    WelcomeView(
                        onContinue: {
                            hasSeenWelcome = true
                        },
                        onReplayStories: {
                            hasCompletedStories = false
                        }
                    )
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background, authService.isSignedIn {
                Task {
                    await SupabaseService.shared.syncUserSettingsToSupabase()
                }
            }
            if newPhase == .active, authService.isSignedIn {
                PushRegistrationService.registerIfAuthorized()
            }
        }
    }
}
