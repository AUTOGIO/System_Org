import Foundation
import Darwin.Mach

@MainActor
class MonitoringManager: NSObject, ObservableObject {
    @Published var automationStatus: [String: AutomationStatus] = [:]
    @Published var metrics = SystemMetrics.empty

    private var sshConnections: [String: SSHConnection] = [:]
    nonisolated(unsafe) var metricsTimer: Timer?
    private var previousCPUTicks: CPUTicks?
    
    override init() {
        super.init()
        refreshMetrics()
        metricsTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshMetrics()
            }
        }
    }

    func refreshMetrics() {
        metrics = SystemMetrics(
            cpuUsage: currentCPUUsage(),
            memoryUsage: currentMemoryUsage(),
            diskUsage: currentDiskUsage(),
            updatedAt: Date()
        )
    }
    
    func checkSSHConnection(to host: String, username: String? = nil, port: Int = 22) {
        let target = username.map { "\($0)@\(host)" } ?? host
        let portStr = String(port)
        Task.detached(priority: .userInitiated) { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
            process.arguments = ["-o", "ConnectTimeout=5", "-o", "BatchMode=yes",
                                  "-p", portStr, target, "echo", "OK"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            let isConnected: Bool
            do {
                try process.run()
                process.waitUntilExit()
                isConnected = process.terminationStatus == 0
            } catch { isConnected = false }
            await MainActor.run { [weak self] in
                self?.sshConnections[target] = SSHConnection(host: target,
                                                              isConnected: isConnected,
                                                              lastCheck: Date())
            }
        }
    }
    
    func getSSHConnection(for host: String) -> SSHConnection? {
        return sshConnections[host]
    }

    func getSSHConnection(to host: String, username: String? = nil) -> SSHConnection? {
        let target = username.map { "\($0)@\(host)" } ?? host
        return sshConnections[target]
    }

    private func currentCPUUsage() -> Double {
        var cpuInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &cpuInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return metrics.cpuUsage }

        let ticks = CPUTicks(
            user: Double(cpuInfo.cpu_ticks.0),
            system: Double(cpuInfo.cpu_ticks.1),
            idle: Double(cpuInfo.cpu_ticks.2),
            nice: Double(cpuInfo.cpu_ticks.3)
        )
        defer { previousCPUTicks = ticks }

        guard let previousCPUTicks else { return metrics.cpuUsage }
        let user = ticks.user - previousCPUTicks.user
        let system = ticks.system - previousCPUTicks.system
        let idle = ticks.idle - previousCPUTicks.idle
        let nice = ticks.nice - previousCPUTicks.nice
        let total = user + system + idle + nice

        guard total > 0 else { return metrics.cpuUsage }
        return min(max((total - idle) / total, 0), 1)
    }

    private func currentMemoryUsage() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return metrics.memoryUsage }

        let active = Double(stats.active_count)
        let inactive = Double(stats.inactive_count)
        let wired = Double(stats.wire_count)
        let compressed = Double(stats.compressor_page_count)
        let free = Double(stats.free_count)
        let used = active + wired + compressed
        let total = used + inactive + free

        guard total > 0 else { return metrics.memoryUsage }
        return min(max(used / total, 0), 1)
    }

    private func currentDiskUsage() -> Double {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            guard let total = attrs[.systemSize] as? NSNumber,
                  let free = attrs[.systemFreeSize] as? NSNumber,
                  total.doubleValue > 0 else {
                return metrics.diskUsage
            }
            return min(max(1 - (free.doubleValue / total.doubleValue), 0), 1)
        } catch {
            return metrics.diskUsage
        }
    }

    deinit {
        metricsTimer?.invalidate()
    }
}

struct SystemMetrics {
    let cpuUsage: Double
    let memoryUsage: Double
    let diskUsage: Double
    let updatedAt: Date?

    static let empty = SystemMetrics(cpuUsage: 0, memoryUsage: 0, diskUsage: 0, updatedAt: nil)
}

private struct CPUTicks {
    let user: Double
    let system: Double
    let idle: Double
    let nice: Double
}

struct SSHConnection {
    let host: String
    let isConnected: Bool
    let lastCheck: Date
}

struct AutomationStatus {
    let id: String
    let isRunning: Bool
    let lastRun: Date?
    let nextRun: Date?
}
