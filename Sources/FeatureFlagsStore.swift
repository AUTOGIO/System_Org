import Foundation
import Combine

/// Observable feature gates so Obsidian/Remote tabs refresh without relaunch.
@MainActor
final class FeatureFlagsStore: ObservableObject {
    @Published private(set) var remoteConfigured = false
    @Published private(set) var obsidianConfigured = false

    init() {
        refresh()
    }

    func refresh() {
        remoteConfigured = Self.checkRemote()
        obsidianConfigured = Self.checkObsidian()
    }

    nonisolated static func checkRemote() -> Bool {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let url = base.appendingPathComponent("SystemOrganizer/remote_machines.json")
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let machines = try? JSONDecoder().decode([RemoteMachine].self, from: data) else {
            return false
        }
        return !machines.isEmpty
    }

    nonisolated static func checkObsidian() -> Bool {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let url = base.appendingPathComponent("SystemOrganizer/obsidian_vaults.json")
        return FileManager.default.fileExists(atPath: url.path)
    }
}
