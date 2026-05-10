import Foundation
import CloudKit

class CloudKitManager: NSObject, ObservableObject {
    @Published var isCloudKitAvailable = false
    @Published var syncStatus = "CloudKit Not Configured"
    @Published var lastSyncDate: Date?
    
    private var _container: CKContainer?
    private var container: CKContainer? {
        if _container == nil {
            // CKContainer.default() crashes with SIGABRT if entitlements are missing.
            // There is no easy way to catch this in pure Swift.
            // We'll use a safety check to avoid the crash in unconfigured environments.
            if !shouldAttemptCloudKitInitialization() {
                return nil
            }
            
            _container = CKContainer.default()
        }
        return _container
    }
    
    private var database: CKDatabase? {
        return container?.privateCloudDatabase
    }
    
    private var syncTimer: Timer?
    
    override init() {
        super.init()
    }
    
    private func shouldAttemptCloudKitInitialization() -> Bool {
        // Only attempt if not explicitly disabled and if we are in a signed environment
        // For development/local runs, we default to disabled to prevent crashes.
        if ProcessInfo.processInfo.environment["DISABLE_CLOUDKIT"] == "1" {
            return false
        }
        
        // If we've already tried and failed (or if we want to be conservative), 
        // we can check if we are running in a debugger or from terminal.
        // A simple way is to check for a specific flag or just default to false 
        // unless a "Enable CloudKit" setting is persisted.
        return UserDefaults.standard.bool(forKey: "EnableCloudKit")
    }
    
    func initializeCloudKit() {
        guard shouldAttemptCloudKitInitialization() else {
            self.syncStatus = "CloudKit integration disabled. Enable in Settings."
            return
        }
        
        guard let container = container else {
            self.syncStatus = "CloudKit Unavailable"
            return
        }
        
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    self?.isCloudKitAvailable = true
                    self?.syncStatus = "CloudKit Ready"
                    self?.setupAutoSync()
                case .noAccount:
                    self?.syncStatus = "No iCloud Account"
                case .restricted:
                    self?.syncStatus = "CloudKit Restricted"
                case .couldNotDetermine:
                    self?.syncStatus = "Could not determine CloudKit status"
                case .temporarilyUnavailable:
                    <#code#>
                @unknown default:
                    self?.syncStatus = "Unknown CloudKit status"
                }
            }
        }
    }
    
    private func setupAutoSync() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.syncData()
        }
    }
    
    func syncData() {
        guard isCloudKitAvailable, let database = database else { return }
        
        let query = CKQuery(recordType: "Automation", predicate: NSPredicate(value: true))
        
        database.perform(query, inZoneWith: nil) { [weak self] records, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.syncStatus = "Sync failed: \(error.localizedDescription)"
                } else {
                    self?.syncStatus = "Synced at \(Date().formatted())"
                    self?.lastSyncDate = Date()
                }
            }
        }
    }
    
    func saveAutomation(_ automation: AutomationModel) {
        guard isCloudKitAvailable, let database = database else { return }
        
        let record = CKRecord(recordType: "Automation")
        record["name"] = automation.name
        record["description"] = automation.description
        record["isEnabled"] = automation.isEnabled
        record["scriptPath"] = automation.scriptPath
        record["schedule"] = automation.schedule
        record["lastRun"] = automation.lastRun
        
        database.save(record) { [weak self] _, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.syncStatus = "Save failed: \(error.localizedDescription)"
                } else {
                    self?.syncStatus = "Automation saved to CloudKit"
                }
            }
        }
    }
    
    func fetchAutomations(completion: @escaping ([AutomationModel]) -> Void) {
        guard isCloudKitAvailable, let database = database else {
            completion([])
            return
        }
        
        let query = CKQuery(recordType: "Automation", predicate: NSPredicate(value: true))
        
        database.perform(query, inZoneWith: nil) { records, error in
            var automations: [AutomationModel] = []
            
            if let records = records {
                automations = records.compactMap { record in
                    AutomationModel(
                        id: record.recordID.recordName,
                        name: record["name"] as? String ?? "",
                        description: record["description"] as? String ?? "",
                        isEnabled: record["isEnabled"] as? Bool ?? false,
                        scriptPath: record["scriptPath"] as? String ?? "",
                        schedule: record["schedule"] as? String ?? "",
                        lastRun: record["lastRun"] as? Date
                    )
                }
            }
            
            DispatchQueue.main.async {
                completion(automations)
            }
        }
    }
    
    deinit {
        syncTimer?.invalidate()
    }
}
