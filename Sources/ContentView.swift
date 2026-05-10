import SwiftUI

struct ContentView: View {
    @EnvironmentObject var automationManager: AutomationManager
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @EnvironmentObject var monitoringManager: MonitoringManager
    
    @State private var selectedTab: TabSelection = .dashboard
    @State private var showNewAutomationSheet = false
    
    enum TabSelection {
        case dashboard
        case automations
        case monitoring
        case settings
        case remoteControl
        case calendar
        case obsidian
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("System Organizer")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Complete Automation Control")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(cloudKitManager.isCloudKitAvailable ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(cloudKitManager.syncStatus)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .borderBottom()
                
                // Main Content
                TabView(selection: $selectedTab) {
                    DashboardView()
                        .tag(TabSelection.dashboard)
                    
                    AutomationsView(showNewSheet: $showNewAutomationSheet)
                        .tag(TabSelection.automations)
                    
                    MonitoringView()
                        .tag(TabSelection.monitoring)
                    
                    RemoteControlView()
                        .tag(TabSelection.remoteControl)
                    
                    CalendarView()
                        .tag(TabSelection.calendar)
                    
                    ObsidianView()
                        .tag(TabSelection.obsidian)
                    
                    SettingsView()
                        .tag(TabSelection.settings)
                }

                
                // Tab Bar
                HStack(spacing: 0) {
                    TabBarButton(
                        icon: "chart.bar.fill",
                        label: "Dashboard",
                        isSelected: selectedTab == .dashboard
                    ) {
                        selectedTab = .dashboard
                    }
                    
                    TabBarButton(
                        icon: "gearshape.fill",
                        label: "Automations",
                        isSelected: selectedTab == .automations
                    ) {
                        selectedTab = .automations
                    }
                    
                    TabBarButton(
                        icon: "waveform.circle.fill",
                        label: "Monitor",
                        isSelected: selectedTab == .monitoring
                    ) {
                        selectedTab = .monitoring
                    }
                    
                    TabBarButton(
                        icon: "network",
                        label: "Remote",
                        isSelected: selectedTab == .remoteControl
                    ) {
                        selectedTab = .remoteControl
                    }
                    
                    TabBarButton(
                        icon: "calendar",
                        label: "Calendar",
                        isSelected: selectedTab == .calendar
                    ) {
                        selectedTab = .calendar
                    }
                    
                    TabBarButton(
                        icon: "note.text",
                        label: "Obsidian",
                        isSelected: selectedTab == .obsidian
                    ) {
                        selectedTab = .obsidian
                    }
                    
                    TabBarButton(
                        icon: "gear",
                        label: "Settings",
                        isSelected: selectedTab == .settings
                    ) {
                        selectedTab = .settings
                    }
                }
                .background(Color(.controlBackgroundColor))
                .borderTop()
            }
            .frame(minWidth: 1000, minHeight: 700)
        }
        .onAppear {
            monitoringManager.startMonitoring()
        }
    }
}

struct TabBarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(label)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundColor(isSelected ? .blue : .secondary)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

extension View {
    func borderTop() -> some View {
        self.border(Color(.separatorColor), width: 1)
    }
    
    func borderBottom() -> some View {
        self.border(Color(.separatorColor), width: 1)
    }
}

#Preview {
    ContentView()
        .environmentObject(AutomationManager())
        .environmentObject(CloudKitManager())
        .environmentObject(MonitoringManager())
}
