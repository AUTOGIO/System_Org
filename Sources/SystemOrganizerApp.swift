import SwiftUI
import CloudKit
import ServiceManagement

@main
struct SystemOrganizerApp: App {
    @StateObject private var automationManager  = AutomationManager()
    @StateObject private var cloudKitManager    = CloudKitManager()
    @StateObject private var monitoringManager  = MonitoringManager()
    @StateObject private var ollamaManager      = OllamaManager()
    @StateObject private var gitStatusManager   = GitStatusManager()
    @StateObject private var notificationManager = NotificationManager.shared

    /// Tracks whether the global-hotkey quick-launch panel is showing
    @State private var showQuickLaunch = false
    private var globalMonitor: Any?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(automationManager)
                .environmentObject(cloudKitManager)
                .environmentObject(monitoringManager)
                .environmentObject(ollamaManager)
                .environmentObject(gitStatusManager)
                .environmentObject(notificationManager)
                .onAppear { setupApp() }
        }
        .windowStyle(.hiddenTitleBar)

        MenuBarExtra("System Organizer", systemImage: "gearshape.fill") {
            MenuBarView()
                .environmentObject(automationManager)
                .environmentObject(cloudKitManager)
                .environmentObject(monitoringManager)
                .environmentObject(ollamaManager)
        }
    }

    // MARK: - Setup

    private func setupApp() {
        cloudKitManager.initializeCloudKit()
        automationManager.loadAutomations()
        monitoringManager.startMonitoring()
        gitStatusManager.refresh()
        notificationManager.requestAuthorization()
        syncLaunchAtLoginState()
        registerGlobalHotkey()
    }

    // MARK: - Launch at Login (SMAppService — macOS 13+)

    static func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("SMAppService error: \(error.localizedDescription)")
        }
    }

    static var isLaunchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    private func syncLaunchAtLoginState() {
        // Keep UserDefaults in sync with the actual system state
        let current = Self.isLaunchAtLoginEnabled
        if UserDefaults.standard.bool(forKey: "LaunchAtLogin") != current {
            UserDefaults.standard.set(current, forKey: "LaunchAtLogin")
        }
    }

    // MARK: - Global Hotkey  ⌘⌥Space → quick-launch panel

    private func registerGlobalHotkey() {
        // Requires Accessibility permission — request it gracefully
        let options: [String: Any] = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false]
        guard AXIsProcessTrustedWithOptions(options as CFDictionary) else {
            print("Accessibility not granted — global hotkey disabled. Enable in System Settings → Privacy.")
            return
        }

        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            // ⌘⌥Space  (keyCode 49 = Space)
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == [.command, .option] && event.keyCode == 49 {
                DispatchQueue.main.async {
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }
}
