import Foundation

// MARK: - AutomationManager

@MainActor
class AutomationManager: NSObject, ObservableObject {
    @Published var automations: [AutomationModel] = []
    @Published var runningAutomations: Set<String> = []
    @Published var automationLogs: [String: [String]] = [:]
    @Published var runHistory: [RunRecord] = []
    /// When set, the UI shows a confirmation alert before running.
    @Published var pendingDestructiveRun: AutomationModel? = nil
    /// Last persistence failure message (nil when healthy).
    @Published var lastPersistenceError: String? = nil

    private nonisolated(unsafe) let processManager = ProcessManager()
    nonisolated(unsafe) var schedulers: [String: Timer] = [:]
    nonisolated(unsafe) var fileWatchers: [String: DispatchSourceFileSystemObject] = [:]

    /// Automations that mutate the desktop/downloads/session or guarded project data.
    static let destructiveAutomationIDs: Set<String> = [
        "organize_desktop",
        "organize_desktop_to_documents",
        "clean_downloads",
        "clean_downloads_older_than_5_days",
        "evening_shutdown",
        "evening_shutdown_routine",
        "fulofilo_run_daily_guarded",
    ]

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

    static var hasConfiguredRemoteMachines: Bool {
        FileManager.default.fileExists(atPath: machinesURL.path)
            && !loadMachines().isEmpty
    }

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
            automations = decoded.map { auto in
                var copy = auto
                copy.schedule = "manual"
                return copy
            }
            saveAutomations()
        } else {
            automations = defaultAutomations()
            saveAutomations()
        }
        setupAllSchedulers()
    }

    func saveAutomations() {
        do {
            let data = try JSONEncoder().encode(automations)
            try data.write(to: Self.automationsURL, options: .atomic)
            clearPersistenceError()
        } catch {
            reportPersistenceError("Could not save automations: \(error.localizedDescription)")
        }
    }

    func clearPersistenceError() {
        lastPersistenceError = nil
    }

    private func reportPersistenceError(_ message: String) {
        lastPersistenceError = message
        NotificationManager.shared.notifyPersistenceFailure(message)
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
        if updated.isEnabled && updated.schedule != "manual" && updated.schedule != "file_watch" {
            setupScheduler(for: updated)
        } else if updated.isEnabled && updated.schedule == "file_watch", let path = updated.watchPath {
            setupFileWatcher(for: updated, path: path)
        } else {
            schedulers[automation.id]?.invalidate()
            schedulers.removeValue(forKey: automation.id)
            fileWatchers[automation.id]?.cancel()
            fileWatchers.removeValue(forKey: automation.id)
        }
    }

    // MARK: - Run

    /// Entry point for UI/menu: confirms destructive automations first.
    func runAutomation(_ automation: AutomationModel) {
        if Self.destructiveAutomationIDs.contains(automation.id) {
            pendingDestructiveRun = automation
            return
        }
        executeAutomation(automation, environment: [:])
    }

    func confirmPendingDestructiveRun() {
        guard let automation = pendingDestructiveRun else { return }
        pendingDestructiveRun = nil
        var env: [String: String] = ["CONFIRM_EVENING_SHUTDOWN": "1"]
        if automation.id == "fulofilo_run_daily_guarded" {
            env["ALLOW_PROJECT_DATA_WRITES"] = "1"
        }
        executeAutomation(automation, environment: env)
    }

    func cancelPendingDestructiveRun() {
        pendingDestructiveRun = nil
    }

    private func executeAutomation(_ automation: AutomationModel, environment: [String: String]) {
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
        let scriptPath = automation.scriptPath
        let scriptContent = automation.scriptContent
        let automationCopy = automation
        let env = environment

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let result = self.processManager.executeScript(
                scriptPath,
                inlineContent: scriptContent,
                environment: env
            )
            let finished = Date()
            let record   = RunRecord(automationId: automationCopy.id,
                                     startedAt: startedAt,
                                     finishedAt: finished,
                                     success: result.success,
                                     output: result.output)

            DispatchQueue.main.async {
                self.runningAutomations.remove(automationCopy.id)
                self.updateLog(automationCopy.id, result.output)
                self.appendHistory(record)

                if let idx = self.automations.firstIndex(where: { $0.id == automationCopy.id }) {
                    self.automations[idx].lastRun = finished
                    self.saveAutomations()
                }

                // Notifications
                if result.success {
                    NotificationManager.shared.notifyAutomationSuccess(name: automationCopy.name, output: result.output)
                } else {
                    NotificationManager.shared.notifyAutomationFailure(name: automationCopy.name, error: result.output)
                }

                // Trigger chained automations on success
                if result.success {
                    for nextId in automationCopy.triggersOnSuccess {
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
        let limit = max(10, UserDefaults.standard.integer(forKey: "RunHistoryLimit"))
        let effectiveLimit = limit == 10 && UserDefaults.standard.object(forKey: "RunHistoryLimit") == nil ? 500 : limit
        if runHistory.count > effectiveLimit { runHistory = Array(runHistory.prefix(effectiveLimit)) }
        do {
            let data = try JSONEncoder().encode(runHistory)
            try data.write(to: Self.historyURL, options: .atomic)
            // Don't clear automation save errors from history success
        } catch {
            reportPersistenceError("Could not save run history: \(error.localizedDescription)")
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

    static func saveMachines(_ machines: [RemoteMachine]) throws {
        let data = try JSONEncoder().encode(machines)
        try data.write(to: machinesURL, options: .atomic)
    }

    /// Opens config for a user-provided machine (no localhost placeholder).
    static func saveMachinesReporting(_ machines: [RemoteMachine]) -> String? {
        do {
            try saveMachines(machines)
            return nil
        } catch {
            return "Could not save remote machines: \(error.localizedDescription)"
        }
    }

    static func clearRemoteMachines() {
        try? FileManager.default.removeItem(at: machinesURL)
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
        let automationId = automation.id
        let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard let current = self.automations.first(where: { $0.id == automationId }) else { return }
                self.runAutomation(current)
                if current.isEnabled && current.schedule != "manual" && current.schedule != "file_watch" {
                    self.setupScheduler(for: current)
                }
            }
        }
        schedulers[automation.id] = timer
    }

    func nextFireDate(for schedule: String) -> Date? {
        let cal = Calendar.current
        let now = Date()
        switch schedule {
        case "every_15_min":
            return nextMinuteInterval(minutes: 15, cal: cal, now: now)
        case "every_30_min":
            return nextMinuteInterval(minutes: 30, cal: cal, now: now)
        case "hourly":
            return cal.nextDate(after: now, matching: DateComponents(minute: 0), matchingPolicy: .nextTime)
        case "daily_9am":
            return nextDaily(hour: 9, cal: cal, now: now)
        case "daily_noon":
            return nextDaily(hour: 12, cal: cal, now: now)
        case "daily_6pm":
            return nextDaily(hour: 18, cal: cal, now: now)
        case "daily_midnight":
            return nextDaily(hour: 0, cal: cal, now: now, forceTomorrow: true)
        case "weekdays_9am":
            return nextWeekday(hour: 9, cal: cal, now: now)
        case "weekly":
            return cal.date(byAdding: .weekOfYear, value: 1, to: now)
        default:
            return nil
        }
    }

    private func nextMinuteInterval(minutes: Int, cal: Calendar, now: Date) -> Date? {
        guard minutes > 0 else { return nil }
        let minute = cal.component(.minute, from: now)
        let nextMinute = ((minute / minutes) + 1) * minutes
        var components = cal.dateComponents([.year, .month, .day, .hour], from: now)

        if nextMinute >= 60 {
            components.minute = 0
            guard let nextHour = cal.date(byAdding: .hour, value: 1, to: cal.date(from: components) ?? now) else {
                return nil
            }
            return nextHour
        }

        components.minute = nextMinute
        components.second = 0
        return cal.date(from: components)
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

    private func nextWeekday(hour: Int, cal: Calendar, now: Date) -> Date? {
        for offset in 0...7 {
            guard let day = cal.date(byAdding: .day, value: offset, to: now) else { continue }
            let weekday = cal.component(.weekday, from: day)
            guard (2...6).contains(weekday) else { continue }

            var components = cal.dateComponents([.year, .month, .day], from: day)
            components.hour = hour
            components.minute = 0
            components.second = 0

            if let candidate = cal.date(from: components), candidate > now {
                return candidate
            }
        }

        return nil
    }

    // MARK: - File Watcher

    private func setupFileWatcher(for automation: AutomationModel, path: String) {
        let expandedPath = Self.expandPath(path)
        let fd = open(expandedPath, O_EVTONLY)
        guard fd >= 0 else {
            updateLog(automation.id, "❌ Could not watch path: \(expandedPath)")
            return
        }

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
        let scriptsRoot = "$HOME/Documents/GitHub/System_Org 2/scripts/SystemOrganizer"
        return [
            AutomationModel(id: "organize_desktop",  name: "Organize Desktop",
                            description: "Archive Desktop files into Documents by type (requires confirm)",
                            isEnabled: false, scriptPath: "\(scriptsRoot)/organize_desktop_to_documents.sh",
                            schedule: "manual", category: .desktop),
            AutomationModel(id: "daily_report",      name: "Daily System Report",
                            description: "Create a daily local system report",
                            isEnabled: false, scriptPath: "\(scriptsRoot)/daily_system_report.sh",
                            schedule: "manual"),
            AutomationModel(id: "repo_refresh_inventory", name: "Repo Refresh Inventory",
                            description: "Refresh the full local Git repo inventory",
                            isEnabled: false, scriptPath: "\(scriptsRoot)/refresh_repo_inventory.sh",
                            schedule: "manual", category: .development, tags: ["repos", "inventory"]),
            AutomationModel(id: "repo_inventory_report", name: "Repo Inventory Report",
                            description: "Show discovered repos grouped by operational category",
                            isEnabled: false, scriptPath: "\(scriptsRoot)/repo_inventory_report.sh",
                            schedule: "manual", category: .development, tags: ["repos", "inventory", "report"]),
            AutomationModel(id: "repo_state_summary", name: "Repo State Summary",
                            description: "Show repo group, branch, dirty state, upstream, and validation readiness",
                            isEnabled: false, scriptPath: "\(scriptsRoot)/repo_state_summary.sh",
                            schedule: "manual", category: .development, tags: ["repos", "git", "summary"]),
            AutomationModel(id: "repo_health_check", name: "Repo Health Check",
                            description: "Check repo paths, Git state, upstream status, and active validation configuration",
                            isEnabled: false, scriptPath: "\(scriptsRoot)/repo_health_check.sh",
                            schedule: "manual", category: .development, tags: ["repos", "git", "health"]),
            AutomationModel(id: "project_portfolio_health", name: "Project Portfolio Health",
                            description: "Check Git, Python, Node, and Django status across key projects",
                            isEnabled: false, scriptPath: "\(scriptsRoot)/project_portfolio_health.sh",
                            schedule: "manual"),
            AutomationModel(id: "project_safe_validation", name: "Project Safe Validation",
                            description: "Run non-mutating validation/build checks across key projects",
                            isEnabled: false, scriptPath: "\(scriptsRoot)/project_safe_validation.sh",
                            schedule: "manual"),
            AutomationModel(id: "fulofilo_validate_data_integrity", name: "Fulofilo Data Integrity",
                            description: "Run fulofilo-analytics data integrity validation",
                            isEnabled: false, scriptPath: "\(scriptsRoot)/fulofilo_validate_data_integrity.sh",
                            schedule: "manual"),
            AutomationModel(id: "fulofilo_run_daily_guarded", name: "Fulofilo Daily Automation Guarded",
                            description: "Guarded fulofilo daily automation (requires confirm)",
                            isEnabled: false, scriptPath: "\(scriptsRoot)/fulofilo_run_daily_guarded.sh",
                            schedule: "manual"),
            AutomationModel(id: "gmc_build_frontend", name: "GMC Frontend Build",
                            description: "Build GMC React/Vite frontend",
                            isEnabled: false, scriptPath: "\(scriptsRoot)/gmc_build_frontend.sh",
                            schedule: "manual"),
            AutomationModel(id: "personallifeos_django_check", name: "PersonalLifeOS Django Check",
                            description: "Run Django system checks for PersonalLifeOS",
                            isEnabled: false, scriptPath: "\(scriptsRoot)/personallifeos_django_check.sh",
                            schedule: "manual"),
            AutomationModel(id: "clean_downloads",   name: "Clean Old Downloads",
                            description: "Trash Downloads older than five days (requires confirm)",
                            isEnabled: false, scriptPath: "\(scriptsRoot)/clean_downloads_older_than_5_days.sh",
                            schedule: "manual", category: .desktop),
            AutomationModel(id: "evening_shutdown",  name: "Evening Shutdown Routine",
                            description: "Save work, quit apps, stop project servers (requires confirm)",
                            isEnabled: false, scriptPath: "\(scriptsRoot)/evening_shutdown_routine.sh",
                            schedule: "manual"),
        ]
    }

    nonisolated static func expandPath(_ path: String) -> String {
        (path as NSString)
            .expandingTildeInPath
            .replacingOccurrences(of: "$HOME", with: NSHomeDirectory())
    }

    deinit {
        schedulers.values.forEach { $0.invalidate() }
        fileWatchers.values.forEach { $0.cancel() }
    }
}

// MARK: - ProcessManager

struct ScriptExecutionResult {
    let success: Bool
    let output: String
    let exitCode: Int32?
}

class ProcessManager {
    /// Wall-clock timeout for script execution (default 10 minutes).
    var timeoutSeconds: TimeInterval = 600

    /// Executes a script file, or inline content written to a temp file if scriptPath is empty.
    func executeScript(
        _ scriptPath: String,
        inlineContent: String = "",
        environment: [String: String] = [:]
    ) -> ScriptExecutionResult {
        let expandedPath = AutomationManager.expandPath(scriptPath)

        // If only inline content, write to a temp file
        let effectivePath: String
        let ext: String
        var temporaryScript: URL?
        if !scriptPath.isEmpty {
            effectivePath = expandedPath
            ext = (expandedPath as NSString).pathExtension.lowercased()
        } else if !inlineContent.isEmpty {
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent("sysorg_inline_\(UUID().uuidString).sh")
            do {
                try inlineContent.write(to: tmp, atomically: true, encoding: .utf8)
            } catch {
                return ScriptExecutionResult(success: false,
                                             output: "❌ Could not write inline script: \(error.localizedDescription)",
                                             exitCode: nil)
            }
            effectivePath = tmp.path
            ext = "sh"
            temporaryScript = tmp
        } else {
            return ScriptExecutionResult(success: false,
                                         output: "❌ No script path or content provided",
                                         exitCode: nil)
        }
        defer {
            if let temporaryScript {
                try? FileManager.default.removeItem(at: temporaryScript)
            }
        }

        if !scriptPath.isEmpty && !FileManager.default.fileExists(atPath: effectivePath) {
            return ScriptExecutionResult(success: false,
                                         output: "❌ Script file not found: \(effectivePath)",
                                         exitCode: nil)
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
        if !environment.isEmpty {
            var env = ProcessInfo.processInfo.environment
            for (key, value) in environment { env[key] = value }
            process.environment = env
        }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError  = pipe

        do {
            try process.run()
            let deadline = Date().addingTimeInterval(timeoutSeconds)
            while process.isRunning {
                if Date() >= deadline {
                    process.terminate()
                    // Give a brief grace period, then force-kill if needed
                    let killDeadline = Date().addingTimeInterval(2)
                    while process.isRunning && Date() < killDeadline {
                        Thread.sleep(forTimeInterval: 0.05)
                    }
                    if process.isRunning {
                        process.interrupt()
                    }
                    let partial = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    let message = "❌ Timed out after \(Int(timeoutSeconds))s"
                    let output = partial.isEmpty ? message : "\(partial)\n\(message)"
                    return ScriptExecutionResult(success: false, output: output, exitCode: process.terminationStatus)
                }
                Thread.sleep(forTimeInterval: 0.1)
            }
            let data   = pipe.fileHandleForReading.readDataToEndOfFile()
            let rawOutput = String(data: data, encoding: .utf8) ?? ""
            let success = process.terminationStatus == 0
            let output = rawOutput.isEmpty
                ? (success ? "✅ Completed successfully" : "❌ Failed with exit code \(process.terminationStatus)")
                : rawOutput
            return ScriptExecutionResult(success: success,
                                         output: output,
                                         exitCode: process.terminationStatus)
        } catch {
            return ScriptExecutionResult(success: false,
                                         output: "❌ \(error.localizedDescription)",
                                         exitCode: nil)
        }
    }
}
