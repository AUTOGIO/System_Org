import Foundation
import SwiftUI

struct GitRepo: Identifiable {
    let id = UUID()
    let path: String
    var name: String { URL(fileURLWithPath: path).lastPathComponent }
    var branch: String = "unknown"
    var isDirty: Bool = false
    var uncommittedCount: Int = 0
    var lastCommitMessage: String = ""
    var lastCommitDate: String = ""
    var aheadCount: Int = 0    // commits ahead of remote
    var behindCount: Int = 0   // commits behind remote
}

@MainActor
class GitStatusManager: NSObject, ObservableObject {
    @Published var repos: [GitRepo] = []
    @Published var isRefreshing = false
    @Published var lastRefreshed: Date?

    static let defaultScanPathsRaw: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/Mobile Documents/com~apple~CloudDocs/Documents/GitHub"
    }()

    /// Directories to scan for git repos (add yours here or configure via Settings)
    @AppStorage("gitScanPaths") var scanPathsRaw: String = GitStatusManager.defaultScanPathsRaw

    var scanPaths: [String] {
        scanPathsRaw
            .split { character in
                character == "," || character == "\n" || character == ";"
            }
            .map { NSString(string: $0.trimmingCharacters(in: .whitespaces)).expandingTildeInPath }
            .filter { !$0.isEmpty }
    }

    func refresh() {
        isRefreshing = true
        let paths = scanPaths
        Task.detached(priority: .utility) { [weak self] in
            var found: [GitRepo] = []
            for base in paths {
                found += self?.discoverRepos(in: base) ?? []
            }
            found.sort { lhs, rhs in
                if lhs.isDirty != rhs.isDirty { return lhs.isDirty }
                return lhs.name < rhs.name
            }
            await MainActor.run { [weak self] in
                self?.repos = found
                self?.isRefreshing = false
                self?.lastRefreshed = Date()
            }
        }
    }

    // MARK: - Discovery

    nonisolated private func discoverRepos(in directory: String) -> [GitRepo] {
        guard FileManager.default.fileExists(atPath: directory) else { return [] }
        var results: [GitRepo] = []

        // Check if the directory itself is a repo
        if isGitRepo(directory) {
            results.append(buildRepo(at: directory))
            return results   // don't recurse inside a repo
        }

        // Check one level deep
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? []
        for item in contents {
            let full = (directory as NSString).appendingPathComponent(item)
            if isGitRepo(full) {
                results.append(buildRepo(at: full))
            }
        }
        return results
    }

    nonisolated private func isGitRepo(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: (path as NSString).appendingPathComponent(".git"))
    }

    // MARK: - Build repo info

    nonisolated private func buildRepo(at path: String) -> GitRepo {
        var repo = GitRepo(path: path)
        repo.branch        = git(["rev-parse", "--abbrev-ref", "HEAD"], at: path).trimmed
        repo.lastCommitMessage = git(["log", "-1", "--pretty=%s"], at: path).trimmed
        repo.lastCommitDate    = git(["log", "-1", "--pretty=%cr"], at: path).trimmed
        let statusOutput   = git(["status", "--porcelain"], at: path)
        let lines          = statusOutput.split(separator: "\n").filter { !$0.isEmpty }
        repo.uncommittedCount = lines.count
        repo.isDirty       = !lines.isEmpty

        // ahead/behind (ignore error if no upstream)
        let ab = git(["rev-list", "--left-right", "--count", "HEAD...@{upstream}"], at: path).trimmed
        let parts = ab.split(separator: "\t")
        if parts.count == 2 {
            repo.aheadCount  = Int(parts[0]) ?? 0
            repo.behindCount = Int(parts[1]) ?? 0
        }
        return repo
    }

    @discardableResult
    nonisolated private func git(_ args: [String], at path: String) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: path)
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError  = Pipe()   // suppress errors
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
