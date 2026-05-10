import SwiftUI
import CloudKit

@main
struct SystemOrganizerApp: App {
    @StateObject private var automationManager = AutomationManager()
    @StateObject private var cloudKitManager = CloudKitManager()
    @StateObject private var monitoringManager = MonitoringManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(automationManager)
                .environmentObject(cloudKitManager)
                .environmentObject(monitoringManager)
                .onAppear {
                    setupApp()
                }
        }
        .windowStyle(.hiddenTitleBar)
        
        MenuBarExtra("System Organizer", systemImage: "gearshape.fill") {
            MenuBarView()
                .environmentObject(automationManager)
                .environmentObject(cloudKitManager)
                .environmentObject(monitoringManager)
        }
    }
    
    private func setupApp() {
        cloudKitManager.initializeCloudKit()
        automationManager.loadAutomations()
        monitoringManager.startMonitoring()
    }
}
