import Foundation

class MonitoringManager: NSObject, ObservableObject {
    @Published var systemStats = SystemStats()
    @Published var automationStatus: [String: AutomationStatus] = [:]
    @Published var isMonitoring = false
    
    private var monitoringTimer: Timer?
    private var sshConnections: [String: SSHConnection] = [:]
    
    override init() {
        super.init()
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        updateSystemStats()
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.updateSystemStats()
        }
    }
    
    func stopMonitoring() {
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    private func updateSystemStats() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            let stats = SystemStats(
                cpuUsage: self?.getCPUUsage() ?? 0,
                memoryUsage: self?.getMemoryUsage() ?? 0,
                diskUsage: self?.getDiskUsage() ?? 0,
                timestamp: Date()
            )
            
            DispatchQueue.main.async {
                self?.systemStats = stats
            }
        }
    }
    
    private func getCPUUsage() -> Double {
        var loadAverage: [Double] = [0, 0, 0]
        getloadavg(&loadAverage, 3)
        return min(loadAverage[0] * 100 / Double(ProcessInfo.processInfo.activeProcessorCount), 100)
    }
    
    private func getMemoryUsage() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size)/4
        
        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(TASK_VM_INFO),
                    $0,
                    &count
                )
            }
        }
        
        guard kerr == KERN_SUCCESS else { return 0 }
        
        let usedMemory = Double(info.phys_footprint)
        let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)
        
        return (usedMemory / totalMemory) * 100
    }
    
    private func getDiskUsage() -> Double {
        let fileManager = FileManager.default
        
        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())
            
            if let totalSize = attributes[.systemSize] as? NSNumber,
               let freeSize = attributes[.systemFreeSize] as? NSNumber {
                let usedSize = totalSize.int64Value - freeSize.int64Value
                return Double(usedSize) / Double(totalSize.int64Value) * 100
            }
        } catch {
            return 0
        }
        
        return 0
    }
    
    func checkSSHConnection(to host: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
            process.arguments = ["-o", "ConnectTimeout=5", host, "echo", "OK"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let isConnected = process.terminationStatus == 0
                
                DispatchQueue.main.async {
                    self?.sshConnections[host] = SSHConnection(
                        host: host,
                        isConnected: isConnected,
                        lastCheck: Date()
                    )
                }
            } catch {
                DispatchQueue.main.async {
                    self?.sshConnections[host] = SSHConnection(
                        host: host,
                        isConnected: false,
                        lastCheck: Date()
                    )
                }
            }
        }
    }
    
    func getSSHConnection(for host: String) -> SSHConnection? {
        return sshConnections[host]
    }
    
    deinit {
        stopMonitoring()
    }
}

struct SystemStats {
    var cpuUsage: Double = 0
    var memoryUsage: Double = 0
    var diskUsage: Double = 0
    var timestamp: Date = Date()
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

// Import required frameworks
import Darwin
