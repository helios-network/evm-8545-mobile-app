// NotificationManager.swift
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { allowed, error in
            print("Notif authorization: \(allowed), error: \(String(describing: error))")
        }
    }

    func notify(title: String, body: String) {
        DispatchQueue.main.async {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request) { err in
                if let err = err {
                    print("❌ Notification error: \(err)")
                } else {
                    print("📩 Notification scheduled.")
                }
            }
        }
    }
}
