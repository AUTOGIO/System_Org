import SwiftUI
import Charts

struct MonitoringView: View {
    @EnvironmentObject var monitoringManager: MonitoringManager
    @State private var cpuHistory: [Double] = []
    @State private var memoryHistory: [Double] = []
    @State private var diskHistory: [Double] = []
    @State private var timestamps: [String] = []
    // Stored so it can be invalidated on disappear — fixes the memory leak
    @State private var historyTimer: Timer?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Real-time Stats
                HStack(spacing: 15) {
                    StatGauge(
                        title: "CPU",
                        value: monitoringManager.systemStats.cpuUsage,
                        color: .blue
                    )
                    StatGauge(
                        title: "Memory",
                        value: monitoringManager.systemStats.memoryUsage,
                        color: .orange
                    )
                    StatGauge(
                        title: "Disk",
                        value: monitoringManager.systemStats.diskUsage,
                        color: .green
                    )
                }
                .padding()

                // CPU Chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("CPU Usage Over Time")
                        .font(.headline)
                    Chart {
                        ForEach(Array(cpuHistory.enumerated()), id: \.offset) { index, value in
                            LineMark(
                                x: .value("Time", index),
                                y: .value("CPU %", value)
                            )
                            .foregroundStyle(.blue)
                        }
                    }
                    .frame(height: 200)
                    .chartYAxis { AxisMarks(position: .leading) }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
                .padding(.horizontal)

                // Memory Chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("Memory Usage Over Time")
                        .font(.headline)
                    Chart {
                        ForEach(Array(memoryHistory.enumerated()), id: \.offset) { index, value in
                            LineMark(
                                x: .value("Time", index),
                                y: .value("Memory %", value)
                            )
                            .foregroundStyle(.orange)
                        }
                    }
                    .frame(height: 200)
                    .chartYAxis { AxisMarks(position: .leading) }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
                .padding(.horizontal)

                // System Information
                VStack(alignment: .leading, spacing: 12) {
                    Text("System Information")
                        .font(.headline)
                        .padding(.horizontal)
                    VStack(spacing: 8) {
                        MonitoringInfoRow(label: "Processor Cores", value: "\(ProcessInfo.processInfo.activeProcessorCount)")
                        MonitoringInfoRow(label: "Total Memory", value: formatBytes(ProcessInfo.processInfo.physicalMemory))
                        MonitoringInfoRow(label: "OS Version", value: ProcessInfo.processInfo.operatingSystemVersionString)
                        MonitoringInfoRow(label: "Uptime", value: formatUptime(ProcessInfo.processInfo.systemUptime))
                    }
                    .padding()
                }
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.vertical)
        }
        .onAppear {
            startHistoryCollection()
        }
        .onDisappear {
            // Properly stop the timer when the view leaves the hierarchy
            historyTimer?.invalidate()
            historyTimer = nil
        }
    }

    private func startHistoryCollection() {
        guard historyTimer == nil else { return }   // prevent double-start
        historyTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            cpuHistory.append(monitoringManager.systemStats.cpuUsage)
            memoryHistory.append(monitoringManager.systemStats.memoryUsage)
            diskHistory.append(monitoringManager.systemStats.diskUsage)
            timestamps.append(Date().formatted(date: .omitted, time: .shortened))
            // Keep only last 30 data points
            if cpuHistory.count > 30 {
                cpuHistory.removeFirst()
                memoryHistory.removeFirst()
                diskHistory.removeFirst()
                timestamps.removeFirst()
            }
        }
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    private func formatUptime(_ seconds: TimeInterval) -> String {
        let days = Int(seconds) / 86400
        let hours = (Int(seconds) % 86400) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        return "\(days)d \(hours)h \(minutes)m"
    }
}

struct StatGauge: View {
    let title: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color(.controlBackgroundColor), lineWidth: 8)
                
                Circle()
                    .trim(from: 0, to: value / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 2) {
                    Text(String(format: "%.0f%%", value))
                        .font(.headline)
                    Text(title)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 100)
        }
    }
}

struct MonitoringInfoRow: View {
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
        .padding(.vertical, 4)
    }
}

#Preview {
    MonitoringView()
        .environmentObject(MonitoringManager())
}
