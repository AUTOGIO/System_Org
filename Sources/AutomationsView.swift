import SwiftUI

struct AutomationsView: View {
    @EnvironmentObject var automationManager: AutomationManager

    @State private var selectedCategory: AutomationCategory? = nil
    @State private var searchText   = ""
    @State private var showAddSheet = false
    @State private var editingAutomation: AutomationModel? = nil

    var filtered: [AutomationModel] {
        automationManager.automations.filter { a in
            (searchText.isEmpty || a.name.localizedCaseInsensitiveContains(searchText))
            && (selectedCategory == nil || a.category == selectedCategory)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Toolbar ──────────────────────────────────────────────
            VStack(spacing: 10) {
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                        TextField("Search…", text: $searchText).textFieldStyle(.plain)
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(8).background(Color(.controlBackgroundColor)).cornerRadius(6)
                    Spacer()
                    Button { showAddSheet = true } label: {
                        Label("New", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        FilterChip(title: "All", isSelected: selectedCategory == nil) { selectedCategory = nil }
                        ForEach(AutomationCategory.allCases, id: \.self) { cat in
                            FilterChip(title: cat.rawValue, isSelected: selectedCategory == cat) {
                                selectedCategory = cat
                            }
                        }
                    }
                }
            }
            .padding().background(Color(.controlBackgroundColor))
            Divider()

            // ── List ─────────────────────────────────────────────────
            ScrollView {
                VStack(spacing: 10) {
                    if filtered.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "magnifyingglass").font(.system(size: 36)).foregroundColor(.secondary)
                            Text("No automations found").foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 40)
                    } else {
                        ForEach(filtered) { automation in
                            AutomationDetailCard(automation: automation) {
                                editingAutomation = automation
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AutomationEditorSheet(mode: .add) { automationManager.addAutomation($0) }
        }
        .sheet(item: $editingAutomation) { auto in
            AutomationEditorSheet(mode: .edit(auto)) { automationManager.updateAutomation($0) }
        }
    }
}

// MARK: - FilterChip

struct FilterChip: View {
    let title: String; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.caption)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(isSelected ? Color.blue : Color(.controlBackgroundColor))
                .foregroundColor(isSelected ? .white : .primary).cornerRadius(6)
        }.buttonStyle(.plain)
    }
}

// MARK: - AutomationDetailCard

struct AutomationDetailCard: View {
    @EnvironmentObject var automationManager: AutomationManager
    let automation: AutomationModel
    var onEdit: () -> Void = {}

    @State private var showLogs    = false
    @State private var showHistory = false
    @State private var showEditor  = false
    @State private var editedScript = ""

    var history: [RunRecord] { automationManager.historyFor(automation.id) }
    var successRate: Double {
        guard !history.isEmpty else { return 0 }
        return Double(history.filter { $0.success }.count) / Double(history.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: 12) {
                Toggle("", isOn: Binding(
                    get: { automation.isEnabled },
                    set: { _ in automationManager.toggleAutomation(automation) }
                )).labelsHidden()

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(automation.name).font(.headline)
                        if automationManager.runningAutomations.contains(automation.id) {
                            Label("Running", systemImage: "arrow.triangle.2.circlepath")
                                .font(.caption2).foregroundColor(.blue)
                        }
                        if !history.isEmpty {
                            Text("\(Int(successRate * 100))%")
                                .font(.caption2).padding(.horizontal, 5).padding(.vertical, 2)
                                .background(successRate > 0.8 ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                                .foregroundColor(successRate > 0.8 ? .green : .orange).cornerRadius(4)
                        }
                    }
                    Text(automation.description).font(.caption).foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        Label(ScheduleOption.displayName(for: automation.schedule), systemImage: "clock")
                            .font(.caption2).foregroundColor(.secondary)
                        if let lastRun = automation.lastRun {
                            Label(lastRun.formatted(date: .abbreviated, time: .shortened),
                                  systemImage: "checkmark.circle")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                        Text(automation.category.rawValue)
                            .font(.caption2).padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1)).cornerRadius(4)
                    }
                }
                Spacer()

                HStack(spacing: 6) {
                    Button { automationManager.runAutomation(automation) } label: {
                        Image(systemName: "play.fill").font(.system(size: 11))
                    }.buttonStyle(.bordered).disabled(!automation.isEnabled)

                    Button { showEditor.toggle(); editedScript = automation.scriptContent } label: {
                        Image(systemName: "pencil").font(.system(size: 11))
                    }.buttonStyle(.bordered)

                    Button { showLogs.toggle() } label: {
                        Image(systemName: "list.bullet").font(.system(size: 11))
                    }.buttonStyle(.bordered)

                    Button { showHistory.toggle() } label: {
                        Image(systemName: "clock.arrow.circlepath").font(.system(size: 11))
                    }.buttonStyle(.bordered)

                    Button(action: onEdit) {
                        Image(systemName: "slider.horizontal.3").font(.system(size: 11))
                    }.buttonStyle(.bordered)

                    Button(role: .destructive) { automationManager.deleteAutomation(automation) } label: {
                        Image(systemName: "trash").font(.system(size: 11))
                    }.buttonStyle(.bordered)
                }
            }
            .padding()

            // Script Editor
            if showEditor {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Inline Script").font(.caption).fontWeight(.semibold)
                        Spacer()
                        Button("Save") {
                            var updated = automation
                            updated.scriptContent = editedScript
                            automationManager.updateAutomation(updated)
                            showEditor = false
                        }.buttonStyle(.borderedProminent).controlSize(.small)
                        Button("Cancel") { showEditor = false }.buttonStyle(.bordered).controlSize(.small)
                    }
                    TextEditor(text: $editedScript)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(height: 140)
                        .border(Color(.separatorColor), width: 1)
                }
                .padding()
            }

            // Logs
            if showLogs {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Execution Logs").font(.caption).fontWeight(.semibold)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(automationManager.automationLogs[automation.id] ?? [], id: \.self) {
                                Text($0).font(.caption2).foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(height: 90).padding(6).background(Color.black.opacity(0.05)).cornerRadius(4)
                }
                .padding()
            }

            // Run History
            if showHistory {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Run History (\(history.count))").font(.caption).fontWeight(.semibold)
                        Spacer()
                        if !history.isEmpty {
                            let avg = history.map(\.duration).reduce(0,+) / Double(history.count)
                            Text("Avg \(String(format: "%.1fs", avg))")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                    }
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(history.prefix(20)) { record in
                                HStack(spacing: 8) {
                                    Image(systemName: record.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(record.success ? .green : .red).font(.caption)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(record.startedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption2)
                                        Text(String(record.output.prefix(80))).font(.caption2).foregroundColor(.secondary).lineLimit(1)
                                    }
                                    Spacer()
                                    Text(String(format: "%.1fs", record.duration)).font(.caption2).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .frame(height: 120).padding(6).background(Color.black.opacity(0.05)).cornerRadius(4)
                }
                .padding()
            }
        }
        .background(Color(.controlBackgroundColor)).cornerRadius(8)
    }
}

// MARK: - AutomationEditorSheet

enum EditorMode { case add; case edit(AutomationModel) }

struct AutomationEditorSheet: View {
    let mode: EditorMode
    var onSave: (AutomationModel) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var automationManager: AutomationManager

    @State private var name: String
    @State private var description: String
    @State private var scriptPath: String
    @State private var scriptContent: String
    @State private var schedule: String
    @State private var category: AutomationCategory
    @State private var tags: String
    @State private var notes: String
    @State private var watchPath: String
    @State private var dependsOn: String
    @State private var triggersOnSuccess: String
    @State private var isEnabled: Bool

    init(mode: EditorMode, onSave: @escaping (AutomationModel) -> Void) {
        self.mode = mode; self.onSave = onSave
        if case .edit(let a) = mode {
            _name = State(initialValue: a.name); _description = State(initialValue: a.description)
            _scriptPath = State(initialValue: a.scriptPath); _schedule = State(initialValue: a.schedule)
            _scriptContent = State(initialValue: a.scriptContent)
            _category = State(initialValue: a.category)
            _tags = State(initialValue: a.tags.joined(separator: ", "))
            _notes = State(initialValue: a.notes); _watchPath = State(initialValue: a.watchPath ?? "")
            _dependsOn = State(initialValue: a.dependsOn.joined(separator: ", "))
            _triggersOnSuccess = State(initialValue: a.triggersOnSuccess.joined(separator: ", "))
            _isEnabled = State(initialValue: a.isEnabled)
        } else {
            _name = State(initialValue: ""); _description = State(initialValue: "")
            _scriptPath = State(initialValue: "")
            _scriptContent = State(initialValue: "")
            _schedule = State(initialValue: "manual"); _category = State(initialValue: .general)
            _tags = State(initialValue: ""); _notes = State(initialValue: "")
            _watchPath = State(initialValue: "")
            _dependsOn = State(initialValue: "")
            _triggersOnSuccess = State(initialValue: "")
            _isEnabled = State(initialValue: true)
        }
    }

    var isEditing: Bool { if case .edit = mode { return true }; return false }
    var hasRunnableScript: Bool {
        !scriptPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !scriptContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    var scriptPathWarning: String? {
        let trimmed = scriptPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let expanded = (trimmed as NSString)
            .expandingTildeInPath
            .replacingOccurrences(of: "$HOME", with: NSHomeDirectory())
        return FileManager.default.fileExists(atPath: expanded) ? nil : "Script file does not exist yet."
    }
    var availableAutomationIds: [String] {
        automationManager.automations
            .filter { automation in
                if case .edit(let current) = mode { return automation.id != current.id }
                return true
            }
            .map(\.id)
            .sorted()
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Basic Info") {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description)
                    Toggle("Enabled", isOn: $isEnabled)
                }
                Section("Script") {
                    TextField("Script Path", text: $scriptPath)
                    if let scriptPathWarning {
                        Label(scriptPathWarning, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    TextEditor(text: $scriptContent)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(height: 120)
                    Text("Use either a script path or an inline script body.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("Schedule", selection: $schedule) {
                        ForEach(ScheduleOption.options) { opt in
                            Text(opt.displayName).tag(opt.id)
                        }
                    }
                    if schedule == "file_watch" {
                        TextField("Watch Path (folder or file)", text: $watchPath)
                    }
                }
                Section("Automation Chain") {
                    TextField("Depends On IDs", text: $dependsOn)
                    TextField("Run After Success IDs", text: $triggersOnSuccess)
                    if !availableAutomationIds.isEmpty {
                        Text("Available IDs: \(availableAutomationIds.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                }
                Section("Organisation") {
                    Picker("Category", selection: $category) {
                        ForEach(AutomationCategory.allCases, id: \.self) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                    TextField("Tags (comma-separated)", text: $tags)
                }
                Section("Notes") {
                    TextEditor(text: $notes).frame(height: 80)
                }
            }
            .navigationTitle(isEditing ? "Edit Automation" : "New Automation")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var auto: AutomationModel
                        if case .edit(let a) = mode { auto = a }
                        else { auto = AutomationModel(id: UUID().uuidString, name: "", description: "",
                                                       isEnabled: true, scriptPath: "", schedule: "manual") }
                        auto.name = name; auto.description = description; auto.scriptPath = scriptPath
                        auto.schedule = schedule; auto.category = category; auto.isEnabled = isEnabled
                        auto.scriptContent = scriptContent
                        auto.tags = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                        auto.notes = notes; auto.watchPath = watchPath.isEmpty ? nil : watchPath
                        auto.dependsOn = parseAutomationIds(dependsOn)
                        auto.triggersOnSuccess = parseAutomationIds(triggersOnSuccess)
                        onSave(auto); dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !hasRunnableScript)
                }
            }
        }
        .frame(minWidth: 560, minHeight: 640)
    }

    private func parseAutomationIds(_ value: String) -> [String] {
        value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

struct DetailRow: View {
    let label: String; let value: String
    var body: some View {
        HStack {
            Text(label).font(.caption).fontWeight(.semibold)
            Spacer()
            Text(value).font(.caption).foregroundColor(.secondary).lineLimit(1)
        }
    }
}

#Preview {
    AutomationsView().environmentObject(AutomationManager())
}
