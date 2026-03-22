import Foundation
import UserNotifications

enum RejoyMeditationNotificationService {
    private static let identifier = "rejoyMeditation"

    static func scheduleNotification() {
        guard let time = AppSettings.rejoyMeditationTime,
              let hour = time.hour, let minute = time.minute else {
            cancelNotification()
            return
        }

        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized:
                addNotification(hour: hour, minute: minute)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    if granted {
                        addNotification(hour: hour, minute: minute)
                    }
                }
            case .denied, .provisional, .ephemeral:
                break
            @unknown default:
                break
            }
        }
    }

    private static func addNotification(hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Rejoy Meditation"
        content.body = "Time for your Rejoy meditation."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// Schedules a test notification in 5 seconds. Use to verify notifications work.
    static func scheduleTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Rejoy Meditation"
        content.body = "Time for your Rejoy meditation."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "rejoyMeditationTest", content: content, trigger: trigger)

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["rejoyMeditationTest"])
        UNUserNotificationCenter.current().add(request)
    }
}
