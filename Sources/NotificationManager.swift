import Foundation
import UserNotifications

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published var isAuthorized = false

    static let shared = NotificationManager()

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        checkAuthorization()
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            DispatchQueue.main.async { self?.isAuthorized = granted }
        }
    }

    private func checkAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - Send notifications

    func notifyAutomationSuccess(name: String, output: String) {
        guard UserDefaults.standard.bool(forKey: "NotificationsEnabled") else { return }
        send(
            title: "✅ \(name) completed",
            body: output.isEmpty ? "Finished successfully." : String(output.prefix(120)),
            identifier: "automation-success-\(name)"
        )
    }

    func notifyAutomationFailure(name: String, error: String) {
        guard UserDefaults.standard.bool(forKey: "NotificationsEnabled") else { return }
        send(
            title: "❌ \(name) failed",
            body: String(error.prefix(120)),
            identifier: "automation-failure-\(name)"
        )
    }

    func notifyOllamaOffline() {
        send(
            title: "⚠️ Ollama Offline",
            body: "Run `brew services start ollama` to restore the AI assistant.",
            identifier: "ollama-offline"
        )
    }

    // MARK: - Private

    private func send(title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "\(identifier)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil   // deliver immediately
        )
        UNUserNotificationCenter.current().add(request)
    }

    // Bring app to foreground when notification tapped
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 didReceive response: UNNotificationResponse,
                                 withCompletionHandler completionHandler: @escaping () -> Void) {
        NSApp.activate(ignoringOtherApps: true)
        completionHandler()
    }

    // Show banner even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification,
                                 withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
