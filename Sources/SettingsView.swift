import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @EnvironmentObject var automationManager: AutomationManager
    
    @State private var autoStartEnabled = true
    @State private var notificationsEnabled = true
    @State private var darkModeEnabled = false
    @State private var syncInterval = 300.0
    @State private var logRetention = 100
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // General Settings
                SettingsSectionView(title: "General") {
                    VStack(spacing: 12) {
                        SettingToggleRow(
                            label: "Launch at Login",
                            value: $autoStartEnabled,
                            icon: "arrow.up.right.circle"
                        )
                        
                        SettingToggleRow(
                            label: "Enable Notifications",
                            value: $notificationsEnabled,
                            icon: "bell.fill"
                        )
                        
                        SettingToggleRow(
                            label: "Dark Mode",
                            value: $darkModeEnabled,
                            icon: "moon.fill"
                        )
                    }
                }
                
                // CloudKit Settings
                SettingsSectionView(title: "CloudKit Sync") {
                    VStack(spacing: 12) {
                        SettingToggleRow(
                            label: "Enable CloudKit Sync",
                            value: Binding(
                                get: { UserDefaults.standard.bool(forKey: "EnableCloudKit") },
                                set: { 
                                    UserDefaults.standard.set($0, forKey: "EnableCloudKit")
                                    if $0 {
                                        cloudKitManager.initializeCloudKit()
                                    }
                                }
                            ),
                            icon: "icloud.fill"
                        )
                        
                        if !UserDefaults.standard.bool(forKey: "EnableCloudKit") {
                            Text("Note: Enabling CloudKit requires a correctly configured and signed environment. The app may crash if entitlements are missing.")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }

                        if UserDefaults.standard.bool(forKey: "EnableCloudKit") {
                            HStack {
                                Image(systemName: "icloud.fill")
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("CloudKit Status")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Text(cloudKitManager.syncStatus)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Circle()
                                    .fill(cloudKitManager.isCloudKitAvailable ? Color.green : Color.red)
                                    .frame(width: 8, height: 8)
                            }
                            
                            Divider()
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Sync Interval")
                                    .font(.caption)
                                Spacer()
                                Text("\(Int(syncInterval))s")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $syncInterval, in: 60...600, step: 60)
                        }
                        
                        Button(action: { cloudKitManager.syncData() }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Sync Now")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                // Automation Settings
                SettingsSectionView(title: "Automations") {
                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Log Retention")
                                    .font(.caption)
                                Spacer()
                                Text("\(logRetention) entries")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: Binding(
                                get: { Double(logRetention) },
                                set: { logRetention = Int($0) }
                            ), in: 10...500, step: 10)
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Active Automations")
                                .font(.caption)
                                .fontWeight(.semibold)
                            
                            HStack {
                                Text("\(automationManager.automations.filter { $0.isEnabled }.count) enabled")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("\(automationManager.automations.count) total")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // About
                SettingsSectionView(title: "About") {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsInfoRow(label: "App Name", value: "System Organizer")
                        SettingsInfoRow(label: "Version", value: "1.0.0")
                        SettingsInfoRow(label: "Build", value: "2025.02.26")
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("System Information")
                                .font(.caption)
                                .fontWeight(.semibold)
                            
                            SettingsInfoRow(
                                label: "macOS",
                                value: ProcessInfo.processInfo.operatingSystemVersionString
                            )
                            SettingsInfoRow(
                                label: "Processor Cores",
                                value: "\(ProcessInfo.processInfo.activeProcessorCount)"
                            )
                        }
                    }
                }
                
                // Danger Zone
                SettingsSectionView(title: "Danger Zone") {
                    VStack(spacing: 12) {
                        Button(role: .destructive, action: { clearLogs() }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Clear All Logs")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        Button(role: .destructive, action: { resetSettings() }) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset All Settings")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    private func clearLogs() {
        automationManager.automationLogs.removeAll()
    }
    
    private func resetSettings() {
        autoStartEnabled = true
        notificationsEnabled = true
        darkModeEnabled = false
        syncInterval = 300.0
        logRetention = 100
    }
}

struct SettingsSectionView<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            
            content
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
        }
    }
}

struct SettingToggleRow: View {
    let label: String
    @Binding var value: Bool
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(label)
                .font(.caption)
            
            Spacer()
            
            Toggle("", isOn: $value)
                .labelsHidden()
        }
    }
}

struct SettingsInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(CloudKitManager())
        .environmentObject(AutomationManager())
}
