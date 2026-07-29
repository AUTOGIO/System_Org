import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var automationManager:   AutomationManager
    @EnvironmentObject var ollamaManager:       OllamaManager
    @EnvironmentObject var notificationManager: NotificationManager

    @AppStorage("LaunchAtLogin")         private var launchAtLogin       = false
    @AppStorage("NotificationsEnabled")  private var notificationsEnabled = true
    @AppStorage("gitScanPaths")          private var gitScanPaths         = GitStatusManager.defaultScanPathsRaw
    @AppStorage("RunHistoryLimit")       private var logRetention         = 500

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
                        Text("Obsidian and Remote tabs stay hidden until configured.")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        HStack {
                            Text(FeatureFlags.obsidianConfigured
                                  ? "Obsidian: configured"
                                  : "Obsidian: not configured")
                                .font(.caption)
                            Spacer()
                            Button(FeatureFlags.obsidianConfigured ? "Reset" : "Enable") {
                                if FeatureFlags.obsidianConfigured {
                                    ObsidianVaultStore.clearConfiguredVaults()
                                } else {
                                    ObsidianVaultStore.enableDefaultConfiguration()
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        HStack {
                            Text(FeatureFlags.remoteConfigured
                                  ? "Remote: configured"
                                  : "Remote: not configured")
                                .font(.caption)
                            Spacer()
                            Button(FeatureFlags.remoteConfigured ? "Reset" : "Enable") {
                                if FeatureFlags.remoteConfigured {
                                    AutomationManager.clearRemoteMachines()
                                } else {
                                    AutomationManager.enablePlaceholderRemoteMachine()
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        Text("After Enable, relaunch the app to show the new tab.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // ── About ─────────────────────────────────────────────
                SettingsSectionView(title: "About") {
                    VStack(alignment: .leading, spacing: 8) {
                        SettingsInfoRow(label: "App", value: "System Organizer 2.1.0")
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
        .environmentObject(AutomationManager())
        .environmentObject(OllamaManager())
        .environmentObject(NotificationManager.shared)
}
