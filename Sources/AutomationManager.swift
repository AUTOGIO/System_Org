import Foundation

// MARK: - AutomationManager

class AutomationManager: NSObject, ObservableObject {
    @Published var automations: [AutomationModel] = []
    @Published var runningAutomations: Set<String> = []
    @Published var automationLogs: [String: [String]] = [:]

    private let processManager = ProcessManager()
    private var schedulers: [String: Timer] = [:]

    /// Persisted JSON file in Application Support
    private static var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("SystemOrganizer", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("automations.json")
    }

    override init() {
        super.init()
        loadAutomations()
    }

    // MARK: Load / Save

    func loadAutomations() {
        if let data = try? Data(contentsOf: Self.storageURL),
           let decoded = try? JSONDecoder().decode([AutomationModel].self, from: data) {
            automations = decoded
        } else {
            // First-run defaults
            automations = defaultAutomations()
            saveAutomations()
        }
        setupSchedulers()
    }

    func saveAutomations() {
        if let data = try? JSONEncoder().encode(automations) {
            try? data.write(to: Self.storageURL, options: .atomic)
        }
    }

    private func defaultAutomations() -> [AutomationModel] {
        [
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
    }

    // MARK: Run

    func runAutomation(_ automation: AutomationModel) {
        guard !runningAutomations.contains(automation.id) else { return }
        runningAutomations.insert(automation.id)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = self?.processManager.executeScript(automation.scriptPath) ?? "Failed to execute"

            DispatchQueue.main.async {
                self?.runningAutomations.remove(automation.id)
                self?.updateAutomationLog(automation.id, with: result)
                if let index = self?.automations.firstIndex(where: { $0.id == automation.id }) {
                    self?.automations[index].lastRun = Date()
                    self?.saveAutomations()
                }
            }
        }
    }

    // MARK: Toggle

    func toggleAutomation(_ automation: AutomationModel) {
        guard let index = automations.firstIndex(where: { $0.id == automation.id }) else { return }
        automations[index].isEnabled.toggle()
        saveAutomations()

        if automations[index].isEnabled && automations[index].schedule != "manual" {
            setupScheduler(for: automations[index])
        } else {
            schedulers[automation.id]?.invalidate()
            schedulers.removeValue(forKey: automation.id)
        }
    }

    // MARK: Scheduling (fires at the correct wall-clock time, not just "24h from now")

    private func setupSchedulers() {
        schedulers.values.forEach { $0.invalidate() }
        schedulers.removeAll()
        for automation in automations where automation.isEnabled && automation.schedule != "manual" {
            setupScheduler(for: automation)
        }
    }

    private func setupScheduler(for automation: AutomationModel) {
        guard let fireDate = nextFireDate(for: automation.schedule) else { return }

        let delay = fireDate.timeIntervalSinceNow
        // One-shot timer that reschedules itself after firing
        let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.runAutomation(automation)
            // Reschedule for the next occurrence
            self?.setupScheduler(for: automation)
        }
        schedulers[automation.id] = timer
    }

    /// Returns the next future Date for a given schedule key.
    private func nextFireDate(for schedule: String) -> Date? {
        let cal = Calendar.current
        let now = Date()

        switch schedule {
        case "hourly":
            return cal.nextDate(after: now, matching: DateComponents(minute: 0), matchingPolicy: .nextTime)

        case "daily_9am":
            var components = cal.dateComponents([.year, .month, .day], from: now)
            components.hour = 9; components.minute = 0; components.second = 0
            let candidate = cal.date(from: components)!
            return candidate > now ? candidate : cal.date(byAdding: .day, value: 1, to: candidate)

        case "daily_6pm":
            var components = cal.dateComponents([.year, .month, .day], from: now)
            components.hour = 18; components.minute = 0; components.second = 0
            let candidate = cal.date(from: components)!
            return candidate > now ? candidate : cal.date(byAdding: .day, value: 1, to: candidate)

        case "daily_midnight":
            var components = cal.dateComponents([.year, .month, .day], from: now)
            components.hour = 0; components.minute = 0; components.second = 0
            let candidate = cal.date(byAdding: .day, value: 1, to: cal.date(from: components)!)!
            return candidate

        case "weekly":
            return cal.date(byAdding: .weekOfYear, value: 1, to: now)

        default:
            return nil
        }
    }

    // MARK: Logs

    private func updateAutomationLog(_ automationId: String, with message: String) {
        if automationLogs[automationId] == nil {
            automationLogs[automationId] = []
        }
        let timestamp = Date().formatted(date: .abbreviated, time: .standard)
        automationLogs[automationId]?.append("[\(timestamp)] \(message)")
        // Keep last 100 entries
        if (automationLogs[automationId]?.count ?? 0) > 100 {
            automationLogs[automationId]?.removeFirst()
        }
    }

    deinit {
        schedulers.values.forEach { $0.invalidate() }
    }
}

// MARK: - ProcessManager

class ProcessManager {

    /// Dispatches to the correct interpreter based on file extension.
    func executeScript(_ scriptPath: String) -> String {
        let expandedPath = (scriptPath as NSString)
            .expandingTildeInPath
            .replacingOccurrences(of: "$HOME", with: NSHomeDirectory())

        let ext = (expandedPath as NSString).pathExtension.lowercased()

        let (executable, arguments): (String, [String]) = {
            switch ext {
            case "applescript", "scpt":
                return ("/usr/bin/osascript", [expandedPath])
            case "py":
                return ("/usr/bin/env", ["python3", expandedPath])
            case "sh", "bash", "":
                return ("/bin/bash", [expandedPath])
            default:
                return ("/bin/bash", [expandedPath])
            }
        }()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return output.isEmpty ? "✅ Completed successfully" : output
        } catch {
            return "❌ Error: \(error.localizedDescription)"
        }
    }
}
