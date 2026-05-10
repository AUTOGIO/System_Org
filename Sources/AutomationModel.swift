import Foundation

struct AutomationModel: Identifiable, Codable {
    var id: String
    var name: String
    var description: String
    var isEnabled: Bool
    var scriptPath: String
    var schedule: String
    var lastRun: Date?
    var category: AutomationCategory = .general
    var tags: [String] = []
    var notes: String = ""
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, isEnabled, scriptPath, schedule, lastRun, category, tags, notes
    }
}

enum AutomationCategory: String, Codable {
    case general = "General"
    case calendar = "Calendar"
    case desktop = "Desktop"
    case obsidian = "Obsidian"
    case ssh = "SSH/Remote"
    case development = "Development"
    case backup = "Backup"
}

struct ScheduleOption: Identifiable {
    let id: String
    let displayName: String
    let interval: TimeInterval
    
    static let options = [
        ScheduleOption(id: "manual", displayName: "Manual", interval: 0),
        ScheduleOption(id: "hourly", displayName: "Hourly", interval: 3600),
        ScheduleOption(id: "daily_9am", displayName: "Daily at 9 AM", interval: 86400),
        ScheduleOption(id: "daily_6pm", displayName: "Daily at 6 PM", interval: 86400),
        ScheduleOption(id: "daily_midnight", displayName: "Daily at Midnight", interval: 86400),
        ScheduleOption(id: "weekly", displayName: "Weekly", interval: 604800),
    ]
}

struct RemoteMachine: Identifiable, Codable {
    var id: String
    var name: String
    var hostname: String
    var username: String
    var port: Int = 22
    var isConnected: Bool = false
    var lastConnectionCheck: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, name, hostname, username, port, isConnected, lastConnectionCheck
    }
}

struct ObsidianVault: Identifiable, Codable {
    var id: String
    var name: String
    var path: String
    var isDefault: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id, name, path, isDefault
    }
}

struct CalendarEvent: Identifiable {
    var id: String
    var title: String
    var startDate: Date
    var endDate: Date
    var calendar: String
    var description: String?
}
