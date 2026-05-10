import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var cloudKitManager:     CloudKitManager
    @EnvironmentObject var automationManager:   AutomationManager
    @EnvironmentObject var ollamaManager:       OllamaManager
    @EnvironmentObject var notificationManager: NotificationManager

    @AppStorage("LaunchAtLogin")         private var launchAtLogin       = false
    @AppStorage("NotificationsEnabled")  private var notificationsEnabled = true
    @AppStorage("EnableCloudKit")        private var enableCloudKit       = false
    @AppStorage("gitScanPaths")          private var gitScanPaths         = "~/Documents,~/Developer,~/Projects"

    @State private var syncInterval = 300.0
    @State private var logRetention = 100
    @State private var showClearHistoryAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // ── General ─────────────────────────────────────────
                SettingsSectionView(title: "General") {
                    VStack(spacing: 12) {
                        // Launch at Login (wired to SMAppService)
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.up.right.circle").foregroundColor(.blue).frame(width: 20)
                            Text("Launch at Login").font(.caption)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { launchAtLogin },
                                set: { newValue in
                                    launchAtLogin = newValue
                                    SystemOrganizerApp.setLaunchAtLogin(newValue)
                                }
                            ))
                            .labelsHidden()
                        }

                        // Notifications (wired to NotificationManager)
                        HStack(spacing: 12) {
                            Image(systemName: "bell.fill").foregroundColor(.blue).frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Enable Notifications").font(.caption)
                                if !notificationManager.isAuthorized {
                                    Text("Not authorized — click to request")
                                        .font(.caption2).foregroundColor(.orange)
                                }
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { notificationsEnabled },
                                set: { newValue in
                                    notificationsEnabled = newValue
                                    if newValue && !notificationManager.isAuthorized {
                                        notificationManager.requestAuthorization()
                                    }
                                }
                            ))
                            .labelsHidden()
                        }
                    }
                }

                // ── AI / Ollama ──────────────────────────────────────
                SettingsSectionView(title: "AI (Ollama)") {
                    VStack(spacing: 12) {
                        HStack {
                            Circle()
                                .fill(ollamaManager.isAvailable ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Text(ollamaManager.statusMessage)
                                .font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Button("Refresh") { ollamaManager.checkAvailability() }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }

                        if !ollamaManager.availableModels.isEmpty {
                            HStack {
                                Text("Active Model").font(.caption)
                                Spacer()
                                Picker("", selection: $ollamaManager.selectedModel) {
                                    ForEach(ollamaManager.availableModels) { model in
                                        Text(model.name).tag(model.name)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 180)
                            }
                        }

                        Divider()
                        Text("Install / start: brew services start ollama\nPull a model:   ollama pull llama3.2")
                            .font(.caption2).foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }

                // ── Git Scanner ──────────────────────────────────────
                SettingsSectionView(title: "Git Scanner") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Scan paths (comma-separated)")
                            .font(.caption).fontWeight(.semibold)
                        TextField("~/Documents,~/Developer", text: $gitScanPaths)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                    }
                }

                // ── CloudKit ─────────────────────────────────────────
                SettingsSectionView(title: "CloudKit Sync") {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "icloud.fill").foregroundColor(.blue).frame(width: 20)
                            Text("Enable CloudKit Sync").font(.caption)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { enableCloudKit },
                                set: { newValue in
                                    enableCloudKit = newValue
                                    if newValue { cloudKitManager.initializeCloudKit() }
                                }
                            ))
                            .labelsHidden()
                        }
                        if !enableCloudKit {
                            Text("Requires a signed app with CloudKit entitlement.")
                                .font(.caption2).foregroundColor(.orange)
                        }
                        if enableCloudKit {
                            HStack {
                                Circle()
                                    .fill(cloudKitManager.isCloudKitAvailable ? Color.green : Color.red)
                                    .frame(width: 8, height: 8)
                                Text(cloudKitManager.syncStatus)
                                    .font(.caption2).foregroundColor(.secondary)
                                Spacer()
                                Button("Sync Now") { cloudKitManager.syncData() }
                                    .buttonStyle(.bordered).controlSize(.small)
                            }
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Sync Interval")
                                    .font(.caption)
                                Spacer()
                                Text("\(Int(syncInterval))s")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Slider(value: $syncInterval, in: 60...600, step: 60)
                        }
                    }
                }

                // ── Automations ──────────────────────────────────────
                SettingsSectionView(title: "Automations") {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Log Retention").font(.caption)
                            Spacer()
                            Text("\(logRetention) entries").font(.caption).foregroundColor(.secondary)
                        }
                        Slider(value: Binding(get: { Double(logRetention) }, set: { logRetention = Int($0) }),
                               in: 10...500, step: 10)
                        HStack {
                            Text("\(automationManager.automations.filter { $0.isEnabled }.count) enabled")
                                .font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Text("\(automationManager.automations.count) total")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                }

                // ── About ─────────────────────────────────────────────
                SettingsSectionView(title: "About") {
                    VStack(alignment: .leading, spacing: 8) {
                        SettingsInfoRow(label: "App", value: "System Organizer 2.0")
                        SettingsInfoRow(label: "macOS", value: ProcessInfo.processInfo.operatingSystemVersionString)
                        SettingsInfoRow(label: "Cores", value: "\(ProcessInfo.processInfo.activeProcessorCount)")
                    }
                }

                // ── Danger Zone ───────────────────────────────────────
                SettingsSectionView(title: "Danger Zone") {
                    VStack(spacing: 10) {
                        Button(role: .destructive) { showClearHistoryAlert = true } label: {
                            HStack { Image(systemName: "clock.arrow.circlepath"); Text("Clear Run History") }
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .alert("Clear all run history?", isPresented: $showClearHistoryAlert) {
                            Button("Clear", role: .destructive) { automationManager.clearHistory() }
                            Button("Cancel", role: .cancel) { }
                        }

                        Button(role: .destructive) { automationManager.automationLogs.removeAll() } label: {
                            HStack { Image(systemName: "trash.fill"); Text("Clear Logs") }
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
}

struct SettingsSectionView<Content: View>: View {
    let title: String
    let content: Content
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content.padding().background(Color(.controlBackgroundColor)).cornerRadius(8)
        }
    }
}

struct SettingToggleRow: View {
    let label: String
    @Binding var value: Bool
    let icon: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(.blue).frame(width: 20)
            Text(label).font(.caption)
            Spacer()
            Toggle("", isOn: $value).labelsHidden()
        }
    }
}

struct SettingsInfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).font(.caption).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.caption).fontWeight(.semibold)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(CloudKitManager())
        .environmentObject(AutomationManager())
        .environmentObject(OllamaManager())
        .environmentObject(NotificationManager.shared)
}
