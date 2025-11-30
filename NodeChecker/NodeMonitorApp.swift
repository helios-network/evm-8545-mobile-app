// NodeMonitorApp.swift
import SwiftUI
import BackgroundTasks
import UserNotifications

let backgroundTaskIdentifier = "com.helios.NodeMonitor.nodeCheck"

@main
struct NodeMonitorApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        // Delegate pour afficher les notifs même en foreground 👇
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        NotificationManager.shared.requestAuthorization()

        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            guard let task = task as? BGProcessingTask else { return }
            self.handleNodeCheckTask(task: task)
        }
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        scheduleBackgroundNodeCheck()
    }

    private func handleNodeCheckTask(task: BGProcessingTask) {
        scheduleBackgroundNodeCheck()
        task.expirationHandler = { task.setTaskCompleted(success: false) }
        NodeManager.shared.checkNodesInBackground {
            task.setTaskCompleted(success: true)
        }
    }

    func scheduleBackgroundNodeCheck() {
        let request = BGProcessingTaskRequest(identifier: backgroundTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    // 🔥 Afficher la notif même si l’app est au premier plan
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
}
