import SwiftUI
import ServiceManagement
import AppKit

@main
struct SystemOrganizerApp: App {
    @StateObject private var automationManager  = AutomationManager()
    @StateObject private var monitoringManager  = MonitoringManager()
    @StateObject private var ollamaManager      = OllamaManager()
    @StateObject private var gitStatusManager   = GitStatusManager()
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var featureFlags       = FeatureFlagsStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(automationManager)
                .environmentObject(monitoringManager)
                .environmentObject(ollamaManager)
                .environmentObject(gitStatusManager)
                .environmentObject(notificationManager)
                .environmentObject(featureFlags)
                .onAppear { setupApp() }
                .alert(
                    "Run destructive automation?",
                    isPresented: Binding(
                        get: { automationManager.pendingDestructiveRun != nil },
                        set: { if !$0 { automationManager.cancelPendingDestructiveRun() } }
                    )
                ) {
                    Button("Cancel", role: .cancel) {
                        automationManager.cancelPendingDestructiveRun()
                    }
                    Button("Run", role: .destructive) {
                        automationManager.confirmPendingDestructiveRun()
                    }
                } message: {
                    if let pending = automationManager.pendingDestructiveRun {
                        Text("\(pending.name)\n\n\(pending.description)")
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)

        MenuBarExtra("System Organizer", systemImage: "gearshape.fill") {
            MenuBarView()
                .environmentObject(automationManager)
                .environmentObject(monitoringManager)
                .environmentObject(ollamaManager)
                .environmentObject(featureFlags)
                .alert(
                    "Run destructive automation?",
                    isPresented: Binding(
                        get: { automationManager.pendingDestructiveRun != nil },
                        set: { if !$0 { automationManager.cancelPendingDestructiveRun() } }
                    )
                ) {
                    Button("Cancel", role: .cancel) {
                        automationManager.cancelPendingDestructiveRun()
                    }
                    Button("Run", role: .destructive) {
                        automationManager.confirmPendingDestructiveRun()
                    }
                } message: {
                    if let pending = automationManager.pendingDestructiveRun {
                        Text("\(pending.name)\n\n\(pending.description)")
                    }
                }
        }
    }

    // MARK: - Setup

    private func setupApp() {
        automationManager.loadAutomations()
        gitStatusManager.refresh()
        notificationManager.requestAuthorization()
        syncLaunchAtLoginState()
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
        let current = Self.isLaunchAtLoginEnabled
        if UserDefaults.standard.bool(forKey: "LaunchAtLogin") != current {
            UserDefaults.standard.set(current, forKey: "LaunchAtLogin")
        }
    }
}
