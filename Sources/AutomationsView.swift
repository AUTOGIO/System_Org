import SwiftUI

struct AutomationsView: View {
    @EnvironmentObject var automationManager: AutomationManager
    @Binding var showNewSheet: Bool
    
    @State private var selectedCategory: AutomationCategory? = nil
    @State private var searchText = ""
    
    var filteredAutomations: [AutomationModel] {
        automationManager.automations.filter { automation in
            let matchesSearch = searchText.isEmpty || automation.name.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = selectedCategory == nil || automation.category == selectedCategory
            return matchesSearch && matchesCategory
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search and Filter
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search automations...", text: $searchText)
                        .textFieldStyle(.plain)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(6)
                
                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterButton(
                            title: "All",
                            isSelected: selectedCategory == nil
                        ) {
                            selectedCategory = nil
                        }
                        
                        ForEach([AutomationCategory.general, .calendar, .desktop, .obsidian, .ssh, .development, .backup], id: \.self) { category in
                            FilterButton(
                                title: category.rawValue,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            
            Divider()
            
            // Automations List
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(filteredAutomations) { automation in
                        AutomationDetailCard(automation: automation)
                    }
                    
                    if filteredAutomations.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("No automations found")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
                .padding()
            }
        }
    }
}

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.controlBackgroundColor))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

struct AutomationDetailCard: View {
    @EnvironmentObject var automationManager: AutomationManager
    let automation: AutomationModel
    
    @State private var showDetails = false
    @State private var showLogs = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Enable/Disable Toggle
                Toggle("", isOn: Binding(
                    get: { automation.isEnabled },
                    set: { _ in automationManager.toggleAutomation(automation) }
                ))
                .labelsHidden()
                
                // Automation Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(automation.name)
                            .font(.headline)
                        
                        if automationManager.runningAutomations.contains(automation.id) {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.8, anchor: .center)
                                Text("Running...")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    Text(automation.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        Label(automation.schedule, systemImage: "clock")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if let lastRun = automation.lastRun {
                            Label(
                                lastRun.formatted(date: .abbreviated, time: .shortened),
                                systemImage: "checkmark.circle"
                            )
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 8) {
                    Button(action: { automationManager.runAutomation(automation) }) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .disabled(!automation.isEnabled)
                    
                    Button(action: { showLogs.toggle() }) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: { showDetails.toggle() }) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            // Logs Section
            if showLogs {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Execution Logs")
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(automationManager.automationLogs[automation.id] ?? [], id: \.self) { log in
                                Text(log)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .frame(height: 100)
                    .padding(8)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(4)
                }
            }
            
            // Details Section
            if showDetails {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    DetailRow(label: "Script Path", value: automation.scriptPath)
                    DetailRow(label: "Category", value: automation.category.rawValue)
                    
                    if !automation.tags.isEmpty {
                        HStack {
                            Text("Tags")
                                .font(.caption)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                ForEach(automation.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(3)
                                }
                            }
                        }
                    }
                    
                    if !automation.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text(automation.notes)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

#Preview {
    AutomationsView(showNewSheet: .constant(false))
        .environmentObject(AutomationManager())
}
