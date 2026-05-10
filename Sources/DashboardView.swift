import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var automationManager: AutomationManager
    @EnvironmentObject var monitoringManager: MonitoringManager
    @EnvironmentObject var cloudKitManager: CloudKitManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // System Stats Cards
                HStack(spacing: 15) {
                    StatCard(
                        title: "CPU Usage",
                        value: String(format: "%.1f%%", monitoringManager.systemStats.cpuUsage),
                        icon: "cpu",
                        color: .blue
                    )
                    
                    StatCard(
                        title: "Memory",
                        value: String(format: "%.1f%%", monitoringManager.systemStats.memoryUsage),
                        icon: "memorychip",
                        color: .orange
                    )
                    
                    StatCard(
                        title: "Disk",
                        value: String(format: "%.1f%%", monitoringManager.systemStats.diskUsage),
                        icon: "internaldrive",
                        color: .green
                    )
                }
                .padding()
                
                // Active Automations
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Active Automations")
                            .font(.headline)
                        Spacer()
                        Text("\(automationManager.automations.filter { $0.isEnabled }.count) enabled")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 8) {
                        ForEach(automationManager.automations.filter { $0.isEnabled }.prefix(5)) { automation in
                            AutomationRowCard(automation: automation)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Recent Activity
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Activity")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(automationManager.automations.filter { $0.lastRun != nil }.sorted { $0.lastRun ?? Date() > $1.lastRun ?? Date() }.prefix(5), id: \.id) { automation in
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(automation.name)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    if let lastRun = automation.lastRun {
                                        Text(lastRun.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(8)
                            .background(Color(.controlBackgroundColor))
                            .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // CloudKit Status
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "icloud.fill")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CloudKit Sync")
                                .font(.headline)
                            Text(cloudKitManager.syncStatus)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: { cloudKitManager.syncData() }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.vertical)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct AutomationRowCard: View {
    let automation: AutomationModel
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: automation.isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(automation.isEnabled ? .green : .gray)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(automation.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(automation.schedule)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let lastRun = automation.lastRun {
                Text(lastRun.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(6)
    }
}

#Preview {
    DashboardView()
        .environmentObject(AutomationManager())
        .environmentObject(MonitoringManager())
        .environmentObject(CloudKitManager())
}
