import Foundation

class AutomationManager: NSObject, ObservableObject {
    @Published var automations: [AutomationModel] = []
    @Published var runningAutomations: Set<String> = []
    @Published var automationLogs: [String: [String]] = [:]
    
    private var processManager = ProcessManager()
    private var schedulers: [String: Timer] = [:]
    
    override init() {
        super.init()
        loadAutomations()
    }
    
    func loadAutomations() {
        // Load from local storage and CloudKit
        automations = [
            AutomationModel(
                id: "calendar_summary",
                name: "Calendar Summary",
                description: "Collect today's events and email them",
                isEnabled: true,
                scriptPath: "$HOME/Documents/scripts/calendar_summary.applescript",
                schedule: "daily_9am",
                lastRun: nil
            ),
            AutomationModel(
                id: "organize_desktop",
                name: "Organize Desktop",
                description: "Sort files by kind (Documents, Images, Videos, Others)",
                isEnabled: true,
                scriptPath: "$HOME/Documents/scripts/organize_desktop.applescript",
                schedule: "daily_6pm",
                lastRun: nil
            ),
            AutomationModel(
                id: "save_to_obsidian",
                name: "Save to Obsidian",
                description: "Save chat messages to Obsidian vault",
                isEnabled: true,
                scriptPath: "$HOME/Documents/scripts/save_to_obsidian.py",
                schedule: "manual",
                lastRun: nil
            ),
            AutomationModel(
                id: "restore_spaces",
                name: "Restore Spaces",
                description: "Restore desktop workspace configuration",
                isEnabled: false,
                scriptPath: "$HOME/Documents/scripts/restore_spaces.sh",
                schedule: "manual",
                lastRun: nil
            ),
            AutomationModel(
                id: "terminal_tasks",
                name: "Terminal Tasks",
                description: "Execute scheduled terminal tasks",
                isEnabled: true,
                scriptPath: "$HOME/Documents/scripts/terminal_task_scheduler.sh",
                schedule: "daily_midnight",
                lastRun: nil
            ),
            AutomationModel(
                id: "sdk_agent",
                name: "SDK Agent Setup",
                description: "Setup and run Streamlit LLM agent",
                isEnabled: false,
                scriptPath: "$HOME/Documents/scripts/setup_all_sdk_agent.sh",
                schedule: "manual",
                lastRun: nil
            )
        ]
        
        setupSchedulers()
    }
    
    func runAutomation(_ automation: AutomationModel) {
        guard !runningAutomations.contains(automation.id) else { return }
        
        runningAutomations.insert(automation.id)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = self?.processManager.executeScript(automation.scriptPath) ?? "Failed to execute"
            
            DispatchQueue.main.async {
                self?.runningAutomations.remove(automation.id)
                self?.updateAutomationLog(automation.id, with: result)
                
                if var automation = self?.automations.first(where: { $0.id == automation.id }) {
                    automation.lastRun = Date()
                    if let index = self?.automations.firstIndex(where: { $0.id == automation.id }) {
                        self?.automations[index] = automation
                    }
                }
            }
        }
    }
    
    func toggleAutomation(_ automation: AutomationModel) {
        if let index = automations.firstIndex(where: { $0.id == automation.id }) {
            automations[index].isEnabled.toggle()
            
            if automations[index].isEnabled && automations[index].schedule != "manual" {
                setupScheduler(for: automations[index])
            } else {
                schedulers[automation.id]?.invalidate()
                schedulers.removeValue(forKey: automation.id)
            }
        }
    }
    
    private func setupSchedulers() {
        for automation in automations where automation.isEnabled && automation.schedule != "manual" {
            setupScheduler(for: automation)
        }
    }
    
    private func setupScheduler(for automation: AutomationModel) {
        let interval = parseScheduleInterval(automation.schedule)
        
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.runAutomation(automation)
        }
        
        schedulers[automation.id] = timer
    }
    
    private func parseScheduleInterval(_ schedule: String) -> TimeInterval {
        switch schedule {
        case "daily_9am":
            return 86400 // 24 hours
        case "daily_6pm":
            return 86400
        case "daily_midnight":
            return 86400
        case "hourly":
            return 3600
        default:
            return 3600
        }
    }
    
    private func updateAutomationLog(_ automationId: String, with message: String) {
        if automationLogs[automationId] == nil {
            automationLogs[automationId] = []
        }
        
        let timestamp = Date().formatted(date: .abbreviated, time: .standard)
        automationLogs[automationId]?.append("[\(timestamp)] \(message)")
        
        // Keep only last 100 logs
        if automationLogs[automationId]?.count ?? 0 > 100 {
            automationLogs[automationId]?.removeFirst()
        }
    }
    
    deinit {
        schedulers.values.forEach { $0.invalidate() }
    }
}

class ProcessManager {
    func executeScript(_ scriptPath: String) -> String {
        let expandedPath = NSString(string: scriptPath).expandingTildeInPath
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", expandedPath]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return output.isEmpty ? "✅ Completed successfully" : output
            }
        } catch {
            return "❌ Error: \(error.localizedDescription)"
        }
        
        return "❌ Failed to execute script"
    }
}
