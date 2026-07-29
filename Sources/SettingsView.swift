import SwiftUI
import ServiceManagement
import AppKit

struct SettingsView: View {
    @EnvironmentObject var automationManager:   AutomationManager
    @EnvironmentObject var ollamaManager:       OllamaManager
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var featureFlags:        FeatureFlagsStore

    @AppStorage("LaunchAtLogin")         private var launchAtLogin       = false
    @AppStorage("NotificationsEnabled")  private var notificationsEnabled = true
    @AppStorage("gitScanPaths")          private var gitScanPaths         = GitStatusManager.defaultScanPathsRaw
    @AppStorage("RunHistoryLimit")       private var logRetention         = 500

    @State private var showClearHistoryAlert = false
    @State private var showAddRemoteSheet = false
    @State private var integrationMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // ── General ─────────────────────────────────────────
                SettingsSectionView(title: "General") {
                    VStack(spacing: 12) {
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
                        Text("Scan paths")
                            .font(.caption).fontWeight(.semibold)
                        TextEditor(text: $gitScanPaths)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(minHeight: 160)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(.separatorColor), lineWidth: 1)
                            )
                        Text("Use one path per line. Commas and semicolons also work.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
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

                // ── Integrations (tabs unlock when configured) ───────
                SettingsSectionView(title: "Integrations") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Obsidian and Remote tabs appear immediately after you configure them.")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        HStack {
                            Text(featureFlags.obsidianConfigured
                                  ? "Obsidian: configured"
                                  : "Obsidian: not configured")
                                .font(.caption)
                            Spacer()
                            if featureFlags.obsidianConfigured {
                                Button("Reset") {
                                    ObsidianVaultStore.clearConfiguredVaults()
                                    featureFlags.refresh()
                                    integrationMessage = "Obsidian tab hidden."
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            } else {
                                Button("Choose Vault…") {
                                    pickObsidianVault()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                        }

                        HStack {
                            Text(featureFlags.remoteConfigured
                                  ? "Remote: configured"
                                  : "Remote: not configured")
                                .font(.caption)
                            Spacer()
                            if featureFlags.remoteConfigured {
                                Button("Reset") {
                                    AutomationManager.clearRemoteMachines()
                                    featureFlags.refresh()
                                    integrationMessage = "Remote tab hidden."
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            } else {
                                Button("Add Machine…") {
                                    showAddRemoteSheet = true
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                        }

                        if let integrationMessage {
                            Text(integrationMessage)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // ── About ─────────────────────────────────────────────
                SettingsSectionView(title: "About") {
                    VStack(alignment: .leading, spacing: 8) {
                        SettingsInfoRow(label: "App", value: "System Organizer 2.1.0")
                        SettingsInfoRow(label: "macOS", value: ProcessInfo.processInfo.operatingSystemVersionString)
                        SettingsInfoRow(label: "Cores", value: "\(ProcessInfo.processInfo.activeProcessorCount)")
                        SettingsInfoRow(label: "Build tip", value: "swift test --scratch-path /tmp/SystemOrganizer-spm-build")
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
                            HStack { Image(systemName: "trash"); Text("Clear Automation Logs") }
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: $showAddRemoteSheet) {
            AddRemoteMachineSheet(isPresented: $showAddRemoteSheet) { machine in
                if let error = AutomationManager.saveMachinesReporting([machine]) {
                    automationManager.lastPersistenceError = error
                    notificationManager.notifyPersistenceFailure(error)
                } else {
                    featureFlags.refresh()
                    integrationMessage = "Remote tab enabled."
                }
            }
        }
    }

    private func pickObsidianVault() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose your Obsidian vault folder"
        panel.prompt = "Use Vault"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let name = url.lastPathComponent
        if let error = ObsidianVaultStore.enableWithVault(at: url.path, name: name) {
            automationManager.lastPersistenceError = error
            notificationManager.notifyPersistenceFailure(error)
            return
        }
        featureFlags.refresh()
        integrationMessage = "Obsidian tab enabled."
    }
}

// MARK: - Helpers

struct SettingsSectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
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
            Text(value).font(.caption).textSelection(.enabled)
        }
    }
}
