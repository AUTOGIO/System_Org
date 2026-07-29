import SwiftUI
import ServiceManagement
import AppKit

/// Retains the global NSEvent monitor (must not be discarded — Apple docs).
@MainActor
private final class GlobalHotkeyMonitor {
    static let shared = GlobalHotkeyMonitor()
    var monitor: Any?
}

@main
struct SystemOrganizerApp: App {
    @StateObject private var automationManager  = AutomationManager()
    @StateObject private var monitoringManager  = MonitoringManager()
    @StateObject private var ollamaManager      = OllamaManager()
    @StateObject private var gitStatusManager   = GitStatusManager()
    @StateObject private var notificationManager = NotificationManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(automationManager)
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
                .environmentObject(monitoringManager)
                .environmentObject(ollamaManager)
        }
    }

    // MARK: - Setup

    private func setupApp() {
        automationManager.loadAutomations()
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

    // MARK: - Global Hotkey  ⌘⌥Space → bring app forward

    private func registerGlobalHotkey() {
        // Requires Accessibility permission — request it gracefully
        let isTrusted = nonisolatedAccessibilityCheck()
        guard isTrusted else {
            print("Accessibility not granted — global hotkey disabled. Enable in System Settings → Privacy.")
            return
        }

        GlobalHotkeyMonitor.shared.monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            // ⌘⌥Space  (keyCode 49 = Space)
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == [.command, .option] && event.keyCode == 49 {
                Task { @MainActor in
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }

    nonisolated private func nonisolatedAccessibilityCheck() -> Bool {
        // kAXTrustedCheckOptionPrompt is a CFString constant — safe to access nonisolated
        let key = "AXTrustedCheckOptionPrompt"
        let options: [String: Any] = [key: false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
