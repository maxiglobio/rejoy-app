import Foundation
import UserNotifications
import UIKit

/// Registers for remote push notifications when the user has granted permission.
/// Call when app becomes active or when MainTabView appears.
enum PushRegistrationService {
    /// Registers for remote notifications. Call only when permission is already granted.
    static func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    /// Registers for remote push if the user has already granted notification permission.
    static func registerIfAuthorized() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            registerForRemoteNotifications()
        }
    }
}
