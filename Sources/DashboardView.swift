import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var automationManager: AutomationManager
    @EnvironmentObject var monitoringManager: MonitoringManager
    @EnvironmentObject var ollamaManager:     OllamaManager
    @EnvironmentObject var gitStatusManager:  GitStatusManager

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // ── App Status ───────────────────────────────────────
                HStack(spacing: 14) {
                    StatCard(title: "Automations",
                             value: "\(automationManager.automations.filter { $0.isEnabled }.count) Enabled",
                             icon: "gearshape.2",
                             color: .blue)
                    StatCard(title: "Running",
                             value: "\(automationManager.runningAutomations.count)",
                             icon: "play.circle",
                             color: .green)
                    StatCard(title: "AI",
                             value: ollamaManager.isAvailable ? "Online" : "Offline",
                             icon: "brain.head.profile",
                             color: ollamaManager.isAvailable ? .purple : .gray)
                }
                .padding(.horizontal)

                HStack(spacing: 14) {
                    StatCard(title: "CPU",
                             value: formatPercent(monitoringManager.metrics.cpuUsage),
                             icon: "cpu",
                             color: .orange)
                    StatCard(title: "Memory",
                             value: formatPercent(monitoringManager.metrics.memoryUsage),
                             icon: "memorychip",
                             color: .purple)
                    StatCard(title: "Disk",
                             value: formatPercent(monitoringManager.metrics.diskUsage),
                             icon: "internaldrive",
                             color: .teal)
                }
                .padding(.horizontal)

                // ── Active Automations ────────────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Active Automations", systemImage: "gearshape.2")
                            .font(.headline)
                        Spacer()
                        Text("\(automationManager.automations.filter { $0.isEnabled }.count) enabled")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    VStack(spacing: 6) {
                        ForEach(automationManager.automations.filter { $0.isEnabled }.prefix(5)) { automation in
                            AutomationRowCard(automation: automation)
                        }
                    }
                    .padding(.horizontal)
                }

                // ── Recent Run History ────────────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    Label("Recent Activity", systemImage: "clock.arrow.circlepath")
                        .font(.headline)
                        .padding(.horizontal)

                    VStack(spacing: 6) {
                        ForEach(automationManager.runHistory.prefix(5)) { record in
                            let auto = automationManager.automations.first { $0.id == record.automationId }
                            HStack(spacing: 10) {
                                Image(systemName: record.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(record.success ? .green : .red)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(auto?.name ?? record.automationId)
                                        .font(.caption).fontWeight(.semibold)
                                    Text(record.startedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2).foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(String(format: "%.1fs", record.duration))
                                    .font(.caption2).foregroundColor(.secondary)
                            }
                            .padding(8).background(Color(.controlBackgroundColor)).cornerRadius(6)
                        }
                    }
                    .padding(.horizontal)
                }

                // ── Git Status Widget ─────────────────────────────────
                GitStatusWidget()

                Spacer()
            }
            .padding(.vertical)
        }
    }

    private func formatPercent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}

// MARK: - GitStatusWidget

struct GitStatusWidget: View {
    @EnvironmentObject var gitStatusManager: GitStatusManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Git Repos", systemImage: "arrow.triangle.branch")
                    .font(.headline)
                Spacer()
                if gitStatusManager.isRefreshing {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Button { gitStatusManager.refresh() } label: {
                        Image(systemName: "arrow.clockwise").font(.system(size: 12))
                    }.buttonStyle(.bordered)
                }
                if let last = gitStatusManager.lastRefreshed {
                    Text(last.formatted(date: .omitted, time: .shortened))
                        .font(.caption2).foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)

            if gitStatusManager.repos.isEmpty && !gitStatusManager.isRefreshing {
                Text("No git repos found in scan paths. Configure paths in Settings → Git Scanner.")
                    .font(.caption).foregroundColor(.secondary)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 6) {
                    ForEach(gitStatusManager.repos.prefix(8)) { repo in
                        GitRepoRow(repo: repo)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct GitRepoRow: View {
    let repo: GitRepo

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(repo.isDirty ? Color.orange : Color.green)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(repo.name).font(.caption).fontWeight(.semibold)
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.branch").font(.caption2).foregroundColor(.secondary)
                    Text(repo.branch).font(.caption2).foregroundColor(.secondary)
                    if repo.isDirty {
                        Text("\(repo.uncommittedCount) uncommitted")
                            .font(.caption2).foregroundColor(.orange)
                    }
                    if repo.aheadCount > 0 {
                        Text("↑\(repo.aheadCount)").font(.caption2).foregroundColor(.blue)
                    }
                    if repo.behindCount > 0 {
                        Text("↓\(repo.behindCount)").font(.caption2).foregroundColor(.red)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(repo.lastCommitDate).font(.caption2).foregroundColor(.secondary)
                Text(repo.lastCommitMessage).font(.caption2).foregroundColor(.secondary).lineLimit(1)
            }
            .frame(maxWidth: 180)
        }
        .padding(8)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(6)
    }
}

// MARK: - StatCard

struct StatCard: View {
    let title: String; let value: String; let icon: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.system(size: 18)).foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundColor(.secondary)
                Text(value).font(.title3).fontWeight(.bold)
            }
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.controlBackgroundColor)).cornerRadius(8)
    }
}

struct AutomationRowCard: View {
    @EnvironmentObject var automationManager: AutomationManager
    let automation: AutomationModel
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: automationManager.runningAutomations.contains(automation.id)
                  ? "arrow.triangle.2.circlepath" : "checkmark.circle.fill")
                .foregroundColor(automationManager.runningAutomations.contains(automation.id) ? .blue : .green)
            VStack(alignment: .leading, spacing: 2) {
                Text(automation.name).font(.caption).fontWeight(.semibold)
                Text(ScheduleOption.displayName(for: automation.schedule))
                    .font(.caption2).foregroundColor(.secondary)
            }
            Spacer()
            if let lastRun = automation.lastRun {
                Text(lastRun.formatted(date: .omitted, time: .shortened))
                    .font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(8).background(Color(.controlBackgroundColor)).cornerRadius(6)
    }
}

#Preview {
    DashboardView()
        .environmentObject(AutomationManager())
        .environmentObject(MonitoringManager())
        .environmentObject(OllamaManager())
        .environmentObject(GitStatusManager())
}
