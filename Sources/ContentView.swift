import SwiftUI

struct ContentView: View {
    @EnvironmentObject var automationManager:  AutomationManager
    @EnvironmentObject var ollamaManager:      OllamaManager
    @EnvironmentObject var gitStatusManager:   GitStatusManager

    @State private var selectedTab: TabSelection = .dashboard

    enum TabSelection: CaseIterable {
        case dashboard, automations, ai, remote, calendar, obsidian, settings

        var icon: String {
            switch self {
            case .dashboard:   return "chart.bar.fill"
            case .automations: return "gearshape.fill"
            case .ai:          return "brain.head.profile"
            case .remote:      return "network"
            case .calendar:    return "calendar"
            case .obsidian:    return "note.text"
            case .settings:    return "gear"
            }
        }

        var label: String {
            switch self {
            case .dashboard:   return "Dashboard"
            case .automations: return "Automations"
            case .ai:          return "AI"
            case .remote:      return "Remote"
            case .calendar:    return "Calendar"
            case .obsidian:    return "Obsidian"
            case .settings:    return "Settings"
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {

                // ── Header ────────────────────────────────────────────
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("System Organizer")
                            .font(.title2).fontWeight(.bold)
                        Text("Complete Automation Control")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(ollamaManager.isAvailable ? Color.purple : Color.gray)
                                .frame(width: 7, height: 7)
                            Text("AI")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .overlay(Rectangle().frame(height: 1).foregroundColor(Color(.separatorColor)), alignment: .bottom)

                // ── Content ───────────────────────────────────────────
                TabView(selection: $selectedTab) {
                    DashboardView()
                        .tag(TabSelection.dashboard)
                    AutomationsView()
                        .tag(TabSelection.automations)
                    AIView()
                        .tag(TabSelection.ai)
                    RemoteControlView()
                        .tag(TabSelection.remote)
                    CalendarView()
                        .tag(TabSelection.calendar)
                    ObsidianView()
                        .tag(TabSelection.obsidian)
                    SettingsView()
                        .tag(TabSelection.settings)
                }

                // ── Tab Bar ───────────────────────────────────────────
                HStack(spacing: 0) {
                    ForEach(TabSelection.allCases, id: \.self) { tab in
                        TabBarButton(
                            icon:       tab.icon,
                            label:      tab.label,
                            isSelected: selectedTab == tab,
                            badge:      badgeFor(tab)
                        ) { selectedTab = tab }
                    }
                }
                .background(Color(.controlBackgroundColor))
                .overlay(Rectangle().frame(height: 1).foregroundColor(Color(.separatorColor)), alignment: .top)
            }
            .frame(minWidth: 1100, minHeight: 720)
        }
    }

    private func badgeFor(_ tab: TabSelection) -> Int {
        switch tab {
        case .automations:
            return automationManager.runningAutomations.count
        case .ai:
            return ollamaManager.isAvailable ? 0 : -1   // -1 = warning dot
        default:
            return 0
        }
    }
}

// MARK: - TabBarButton

struct TabBarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    var badge: Int = 0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 3) {
                    Image(systemName: icon).font(.system(size: 15))
                    Text(label).font(.caption2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .foregroundColor(isSelected ? .blue : .secondary)
                .background(isSelected ? Color.blue.opacity(0.08) : Color.clear)

                // Badge / warning dot
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .background(Color.red)
                        .cornerRadius(6)
                        .offset(x: -6, y: 4)
                } else if badge == -1 {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 7, height: 7)
                        .offset(x: -6, y: 4)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

extension View {
    func borderTop() -> some View {
        overlay(Rectangle().frame(height: 1).foregroundColor(Color(.separatorColor)), alignment: .top)
    }
    func borderBottom() -> some View {
        overlay(Rectangle().frame(height: 1).foregroundColor(Color(.separatorColor)), alignment: .bottom)
    }
}

#Preview {
    ContentView()
        .environmentObject(AutomationManager())
        .environmentObject(MonitoringManager())
        .environmentObject(OllamaManager())
        .environmentObject(GitStatusManager())
}
