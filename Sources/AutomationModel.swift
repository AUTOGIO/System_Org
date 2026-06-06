import Foundation

// MARK: - AutomationModel

struct AutomationModel: Identifiable, Codable {
    var id: String
    var name: String
    var description: String
    var isEnabled: Bool
    var scriptPath: String
    var scriptContent: String = ""      // inline script body (optional, used by editor)
    var schedule: String
    var lastRun: Date?
    var category: AutomationCategory = .general
    var tags: [String] = []
    var notes: String = ""

    // ── Chains ──────────────────────────────────────────────────────
    /// IDs of automations that must succeed before this one runs
    var dependsOn: [String] = []
    /// IDs of automations to trigger after this one succeeds
    var triggersOnSuccess: [String] = []

    // ── File-watcher trigger ────────────────────────────────────────
    var watchPath: String? = nil        // if set, run when this path changes
}

// MARK: - RunRecord  (persisted history)

struct RunRecord: Identifiable, Codable {
    let id: UUID
    let automationId: String
    let startedAt: Date
    let finishedAt: Date
    let success: Bool
    let output: String

    init(automationId: String, startedAt: Date, finishedAt: Date, success: Bool, output: String) {
        self.id           = UUID()
        self.automationId = automationId
        self.startedAt    = startedAt
        self.finishedAt   = finishedAt
        self.success      = success
        self.output       = output
    }

    var duration: TimeInterval { finishedAt.timeIntervalSince(startedAt) }
}

// MARK: - AutomationCategory

enum AutomationCategory: String, Codable, CaseIterable {
    case general     = "General"
    case calendar    = "Calendar"
    case desktop     = "Desktop"
    case obsidian    = "Obsidian"
    case ssh         = "SSH/Remote"
    case development = "Development"
    case backup      = "Backup"
    case ai          = "AI"
}

// MARK: - ScheduleOption

struct ScheduleOption: Identifiable {
    let id: String
    let displayName: String

    static let options: [ScheduleOption] = [
        ScheduleOption(id: "manual",         displayName: "Manual"),
        ScheduleOption(id: "every_15_min",   displayName: "Every 15 Minutes"),
        ScheduleOption(id: "every_30_min",   displayName: "Every 30 Minutes"),
        ScheduleOption(id: "hourly",         displayName: "Hourly"),
        ScheduleOption(id: "daily_9am",      displayName: "Daily at 9 AM"),
        ScheduleOption(id: "daily_noon",     displayName: "Daily at Noon"),
        ScheduleOption(id: "daily_6pm",      displayName: "Daily at 6 PM"),
        ScheduleOption(id: "daily_midnight", displayName: "Daily at Midnight"),
        ScheduleOption(id: "weekdays_9am",   displayName: "Weekdays at 9 AM"),
        ScheduleOption(id: "weekly",         displayName: "Weekly"),
        ScheduleOption(id: "file_watch",     displayName: "File Watcher"),
    ]

    static func displayName(for id: String) -> String {
        options.first { $0.id == id }?.displayName ?? id
    }
}

// MARK: - RemoteMachine

struct RemoteMachine: Identifiable, Codable {
    var id: String
    var name: String
    var hostname: String
    var username: String
    var port: Int = 22
    var isConnected: Bool = false
    var lastConnectionCheck: Date?
}

// MARK: - ObsidianVault

struct ObsidianVault: Identifiable, Codable {
    var id: String
    var name: String
    var path: String
    var isDefault: Bool = false
}

// MARK: - CalendarEvent

struct CalendarEvent: Identifiable {
    var id: String
    var title: String
    var startDate: Date
    var endDate: Date
    var calendar: String
    var description: String?
}
