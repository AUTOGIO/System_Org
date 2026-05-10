import Foundation

// MARK: - AutomationManager

class AutomationManager: NSObject, ObservableObject {
    @Published var automations: [AutomationModel] = []
    @Published var runningAutomations: Set<String> = []
    @Published var automationLogs: [String: [String]] = [:]
    @Published var runHistory: [RunRecord] = []

    private let processManager = ProcessManager()
    private var schedulers: [String: Timer] = [:]
    private var fileWatchers: [String: DispatchSourceFileSystemObject] = [:]

    // MARK: - Storage URLs

    private static func appSupportDir() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir  = base.appendingPathComponent("SystemOrganizer", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static var automationsURL: URL { appSupportDir().appendingPathComponent("automations.json") }
    private static var historyURL:     URL { appSupportDir().appendingPathComponent("run_history.json") }
    private static var machinesURL:    URL { appSupportDir().appendingPathComponent("remote_machines.json") }

    // MARK: - Init

    override init() {
        super.init()
        loadAutomations()
        loadHistory()
    }

    // MARK: - Load / Save automations

    func loadAutomations() {
        if let data    = try? Data(contentsOf: Self.automationsURL),
           let decoded = try? JSONDecoder().decode([AutomationModel].self, from: data) {
            automations = decoded
        } else {
            automations = defaultAutomations()
            saveAutomations()
        }
        setupAllSchedulers()
    }

    func saveAutomations() {
        if let data = try? JSONEncoder().encode(automations) {
            try? data.write(to: Self.automationsURL, options: .atomic)
        }
    }

    // MARK: - CRUD

    func addAutomation(_ automation: AutomationModel) {
        automations.append(automation)
        saveAutomations()
        if automation.isEnabled && automation.schedule != "manual" {
            setupScheduler(for: automation)
        }
        if automation.schedule == "file_watch", let path = automation.watchPath {
            setupFileWatcher(for: automation, path: path)
        }
    }

    func updateAutomation(_ automation: AutomationModel) {
        guard let idx = automations.firstIndex(where: { $0.id == automation.id }) else { return }
        automations[idx] = automation
        saveAutomations()
        // Re-schedule
        schedulers[automation.id]?.invalidate()
        schedulers.removeValue(forKey: automation.id)
        fileWatchers[automation.id]?.cancel()
        fileWatchers.removeValue(forKey: automation.id)
        if automation.isEnabled && automation.schedule != "manual" && automation.schedule != "file_watch" {
            setupScheduler(for: automation)
        }
        if automation.schedule == "file_watch", let path = automation.watchPath {
            setupFileWatcher(for: automation, path: path)
        }
    }

    func deleteAutomation(_ automation: AutomationModel) {
        schedulers[automation.id]?.invalidate()
        schedulers.removeValue(forKey: automation.id)
        fileWatchers[automation.id]?.cancel()
        fileWatchers.removeValue(forKey: automation.id)
        automations.removeAll { $0.id == automation.id }
        saveAutomations()
    }

    func toggleAutomation(_ automation: AutomationModel) {
        guard let idx = automations.firstIndex(where: { $0.id == automation.id }) else { return }
        automations[idx].isEnabled.toggle()
        saveAutomations()
        let updated = automations[idx]
        if updated.isEnabled && updated.schedule != "manual" {
            setupScheduler(for: updated)
        } else {
            schedulers[automation.id]?.invalidate()
            schedulers.removeValue(forKey: automation.id)
        }
    }

    // MARK: - Run

    func runAutomation(_ automation: AutomationModel) {
        guard !runningAutomations.contains(automation.id) else { return }

        // Check chain dependencies
        for depId in automation.dependsOn {
            if runningAutomations.contains(depId) {
                updateLog(automation.id, "⏳ Waiting for dependency '\(depId)' to finish")
                return
            }
        }

        runningAutomations.insert(automation.id)
        let startedAt = Date()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let output = self.processManager.executeScript(automation.scriptPath,
                                                           inlineContent: automation.scriptContent)
            let success  = !output.lowercased().hasPrefix("❌")
            let finished = Date()
            let record   = RunRecord(automationId: automation.id,
                                     startedAt: startedAt,
                                     finishedAt: finished,
                                     success: success,
                                     output: output)

            DispatchQueue.main.async {
                self.runningAutomations.remove(automation.id)
                self.updateLog(automation.id, output)
                self.appendHistory(record)

                if let idx = self.automations.firstIndex(where: { $0.id == automation.id }) {
                    self.automations[idx].lastRun = finished
                    self.saveAutomations()
                }

                // Notifications
                if success {
                    NotificationManager.shared.notifyAutomationSuccess(name: automation.name, output: output)
                } else {
                    NotificationManager.shared.notifyAutomationFailure(name: automation.name, error: output)
                }

                // Trigger chained automations on success
                if success {
                    for nextId in automation.triggersOnSuccess {
                        if let next = self.automations.first(where: { $0.id == nextId }) {
                            self.runAutomation(next)
                        }
                    }
                }
            }
        }
    }

    // MARK: - History

    private func loadHistory() {
        if let data    = try? Data(contentsOf: Self.historyURL),
           let decoded = try? JSONDecoder().decode([RunRecord].self, from: data) {
            runHistory = decoded
        }
    }

    private func appendHistory(_ record: RunRecord) {
        runHistory.insert(record, at: 0)
        if runHistory.count > 500 { runHistory = Array(runHistory.prefix(500)) }
        if let data = try? JSONEncoder().encode(runHistory) {
            try? data.write(to: Self.historyURL, options: .atomic)
        }
    }

    func historyFor(_ automationId: String) -> [RunRecord] {
        runHistory.filter { $0.automationId == automationId }
    }

    func clearHistory() {
        runHistory.removeAll()
        try? FileManager.default.removeItem(at: Self.historyURL)
    }

    // MARK: - Remote Machines persistence

    static func loadMachines() -> [RemoteMachine] {
        guard let data    = try? Data(contentsOf: machinesURL),
              let decoded = try? JSONDecoder().decode([RemoteMachine].self, from: data) else {
            return []
        }
        return decoded
    }

    static func saveMachines(_ machines: [RemoteMachine]) {
        if let data = try? JSONEncoder().encode(machines) {
            try? data.write(to: machinesURL, options: .atomic)
        }
    }

    // MARK: - Scheduling

    private func setupAllSchedulers() {
        schedulers.values.forEach { $0.invalidate() }
        schedulers.removeAll()
        fileWatchers.values.forEach { $0.cancel() }
        fileWatchers.removeAll()

        for automation in automations where automation.isEnabled {
            if automation.schedule == "file_watch", let path = automation.watchPath {
                setupFileWatcher(for: automation, path: path)
            } else if automation.schedule != "manual" {
                setupScheduler(for: automation)
            }
        }
    }

    private func setupScheduler(for automation: AutomationModel) {
        guard let fireDate = nextFireDate(for: automation.schedule) else { return }
        let delay = max(fireDate.timeIntervalSinceNow, 1)
        let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.runAutomation(automation)
            self?.setupScheduler(for: automation)  // reschedule for next occurrence
        }
        schedulers[automation.id] = timer
    }

    private func nextFireDate(for schedule: String) -> Date? {
        let cal = Calendar.current
        let now = Date()
        switch schedule {
        case "hourly":
            return cal.nextDate(after: now, matching: DateComponents(minute: 0), matchingPolicy: .nextTime)
        case "daily_9am":
            return nextDaily(hour: 9, cal: cal, now: now)
        case "daily_6pm":
            return nextDaily(hour: 18, cal: cal, now: now)
        case "daily_midnight":
            return nextDaily(hour: 0, cal: cal, now: now, forceTomorrow: true)
        case "weekly":
            return cal.date(byAdding: .weekOfYear, value: 1, to: now)
        default:
            return nil
        }
    }

    private func nextDaily(hour: Int, cal: Calendar, now: Date, forceTomorrow: Bool = false) -> Date? {
        var c = cal.dateComponents([.year, .month, .day], from: now)
        c.hour = hour; c.minute = 0; c.second = 0
        let candidate = cal.date(from: c)!
        if forceTomorrow || candidate <= now {
            return cal.date(byAdding: .day, value: 1, to: candidate)
        }
        return candidate
    }

    // MARK: - File Watcher

    private func setupFileWatcher(for automation: AutomationModel, path: String) {
        let expandedPath = (path as NSString).expandingTildeInPath
        let fd = open(expandedPath, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: DispatchQueue.global(qos: .utility)
        )
        source.setEventHandler { [weak self] in
            DispatchQueue.main.async { self?.runAutomation(automation) }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        fileWatchers[automation.id] = source
    }

    // MARK: - Logs (in-memory)

    private func updateLog(_ automationId: String, _ message: String) {
        if automationLogs[automationId] == nil { automationLogs[automationId] = [] }
        let ts = Date().formatted(date: .abbreviated, time: .standard)
        automationLogs[automationId]?.append("[\(ts)] \(message)")
        if (automationLogs[automationId]?.count ?? 0) > 100 { automationLogs[automationId]?.removeFirst() }
    }

    // MARK: - Defaults

    private func defaultAutomations() -> [AutomationModel] {
        [
            AutomationModel(id: "calendar_summary",  name: "Calendar Summary",
                            description: "Collect today's events and email them",
                            isEnabled: true, scriptPath: "$HOME/Documents/scripts/calendar_summary.applescript",
                            schedule: "daily_9am"),
            AutomationModel(id: "organize_desktop",  name: "Organize Desktop",
                            description: "Sort files by kind",
                            isEnabled: true, scriptPath: "$HOME/Documents/scripts/organize_desktop.applescript",
                            schedule: "daily_6pm"),
            AutomationModel(id: "save_to_obsidian",  name: "Save to Obsidian",
                            description: "Save chat messages to Obsidian vault",
                            isEnabled: true, scriptPath: "$HOME/Documents/scripts/save_to_obsidian.py",
                            schedule: "manual"),
            AutomationModel(id: "restore_spaces",    name: "Restore Spaces",
                            description: "Restore desktop workspace configuration",
                            isEnabled: false, scriptPath: "$HOME/Documents/scripts/restore_spaces.sh",
                            schedule: "manual"),
            AutomationModel(id: "terminal_tasks",    name: "Terminal Tasks",
                            description: "Execute scheduled terminal tasks",
                            isEnabled: true, scriptPath: "$HOME/Documents/scripts/terminal_task_scheduler.sh",
                            schedule: "daily_midnight"),
            AutomationModel(id: "sdk_agent",         name: "SDK Agent Setup",
                            description: "Setup and run Streamlit LLM agent",
                            isEnabled: false, scriptPath: "$HOME/Documents/scripts/setup_all_sdk_agent.sh",
                            schedule: "manual"),
        ]
    }

    deinit {
        schedulers.values.forEach { $0.invalidate() }
        fileWatchers.values.forEach { $0.cancel() }
    }
}

// MARK: - ProcessManager

class ProcessManager {
    /// Executes a script file, or inline content written to a temp file if scriptPath is empty.
    func executeScript(_ scriptPath: String, inlineContent: String = "") -> String {
        let expandedPath = (scriptPath as NSString)
            .expandingTildeInPath
            .replacingOccurrences(of: "$HOME", with: NSHomeDirectory())

        // If only inline content, write to a temp file
        let effectivePath: String
        let ext: String
        if !scriptPath.isEmpty {
            effectivePath = expandedPath
            ext = (expandedPath as NSString).pathExtension.lowercased()
        } else if !inlineContent.isEmpty {
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent("sysorg_inline_\(UUID().uuidString).sh")
            try? inlineContent.write(to: tmp, atomically: true, encoding: .utf8)
            effectivePath = tmp.path
            ext = "sh"
        } else {
            return "❌ No script path or content provided"
        }

        let (executable, arguments): (String, [String]) = {
            switch ext {
            case "applescript", "scpt": return ("/usr/bin/osascript", [effectivePath])
            case "py":                  return ("/usr/bin/env", ["python3", effectivePath])
            default:                    return ("/bin/bash", [effectivePath])
            }
        }()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments     = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError  = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data   = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return output.isEmpty ? "✅ Completed successfully" : output
        } catch {
            return "❌ \(error.localizedDescription)"
        }
    }
}
