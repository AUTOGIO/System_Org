import SwiftUI

struct ObsidianView: View {
    @State private var vaults: [ObsidianVault] = ObsidianVaultStore.loadVaults()
    
    @State private var selectedVault: ObsidianVault?
    @State private var notes: [String] = []
    @State private var showAddVault = false
    @State private var showNewNote = false
    @State private var newNoteTitle = ""
    @State private var newNoteContent = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Obsidian Integration")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showAddVault.toggle() }) {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            
            Divider()
            
            // Vaults and Notes
            HStack(spacing: 0) {
                // Vaults List
                VStack(spacing: 0) {
                    Text("Vaults")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.controlBackgroundColor))
                    
                    Divider()
                    
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(vaults) { vault in
                                VaultRowView(
                                    vault: vault,
                                    isSelected: selectedVault?.id == vault.id
                                ) {
                                    selectedVault = vault
                                    loadNotes(from: vault)
                                }
                            }
                        }
                        .padding()
                    }
                    .frame(width: 200)
                }
                .background(Color(.controlBackgroundColor))
                
                Divider()
                
                // Notes List
                VStack(spacing: 0) {
                    HStack {
                        Text("Notes")
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button(action: { showNewNote.toggle() }) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    
                    Divider()
                    
                    ScrollView {
                        VStack(spacing: 8) {
                            if notes.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "note.text")
                                        .font(.system(size: 30))
                                        .foregroundColor(.secondary)
                                    Text("No notes in this vault")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            } else {
                                ForEach(notes, id: \.self) { note in
                                    NoteRowView(note: note)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .sheet(isPresented: $showAddVault) {
            AddVaultSheet(isPresented: $showAddVault, vaults: $vaults) {
                ObsidianVaultStore.saveVaults(vaults)
                if selectedVault == nil, let defaultVault = vaults.first(where: { $0.isDefault }) {
                    selectedVault = defaultVault
                    loadNotes(from: defaultVault)
                }
            }
        }
        .sheet(isPresented: $showNewNote) {
            NewNoteSheet(
                isPresented: $showNewNote,
                vault: selectedVault,
                title: $newNoteTitle,
                content: $newNoteContent
            ) {
                if let selectedVault {
                    loadNotes(from: selectedVault)
                }
                newNoteTitle = ""
                newNoteContent = ""
            }
        }
        .onAppear {
            if let defaultVault = vaults.first(where: { $0.isDefault }) {
                selectedVault = defaultVault
                loadNotes(from: defaultVault)
            }
        }
    }
    
    private func loadNotes(from vault: ObsidianVault) {
        let expandedPath = AutomationManager.expandPath(vault.path)
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: expandedPath)
            notes = contents.filter { $0.hasSuffix(".md") }.sorted()
        } catch {
            notes = []
        }
    }
}

enum ObsidianVaultStore {
    static let defaultVaults = [
        ObsidianVault(
            id: "main",
            name: "Main Vault",
            path: "$HOME/Documents/OBSIDIAN_VAULTS",
            isDefault: true
        )
    ]

    private static var vaultsURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("SystemOrganizer", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("obsidian_vaults.json")
    }

    static func loadVaults() -> [ObsidianVault] {
        guard let data = try? Data(contentsOf: vaultsURL),
              let decoded = try? JSONDecoder().decode([ObsidianVault].self, from: data),
              !decoded.isEmpty else {
            return defaultVaults
        }
        return decoded
    }

    static func saveVaults(_ vaults: [ObsidianVault]) {
        guard let data = try? JSONEncoder().encode(vaults) else { return }
        try? data.write(to: vaultsURL, options: .atomic)
    }
}

struct VaultRowView: View {
    let vault: ObsidianVault
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(vault.name)
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    if vault.isDefault {
                        Text("Default")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(8)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}

struct NoteRowView: View {
    let note: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text.fill")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(note.replacingOccurrences(of: ".md", with: ""))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(8)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(4)
    }
}

struct AddVaultSheet: View {
    @Binding var isPresented: Bool
    @Binding var vaults: [ObsidianVault]
    var onSave: () -> Void = {}
    
    @State private var name = ""
    @State private var path = ""
    @State private var isDefault = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Vault Details") {
                    TextField("Vault Name", text: $name)
                    TextField("Vault Path", text: $path)
                    Toggle("Set as Default", isOn: $isDefault)
                }
            }
            .navigationTitle("Add Vault")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let newVault = ObsidianVault(
                            id: UUID().uuidString,
                            name: name,
                            path: path,
                            isDefault: isDefault
                        )
                        
                        if isDefault {
                            vaults = vaults.map { var v = $0; v.isDefault = false; return v }
                        }
                        
                        vaults.append(newVault)
                        onSave()
                        isPresented = false
                    }
                    .disabled(name.isEmpty || path.isEmpty)
                }
            }
        }
    }
}

struct NewNoteSheet: View {
    @Binding var isPresented: Bool
    let vault: ObsidianVault?
    @Binding var title: String
    @Binding var content: String
    var onSaved: () -> Void = {}
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                TextField("Note Title", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                
                TextEditor(text: $content)
                    .border(Color.gray, width: 1)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("New Note")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if saveNote() {
                            onSaved()
                            isPresented = false
                        }
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func saveNote() -> Bool {
        guard let vault = vault else { return false }
        
        let expandedPath = AutomationManager.expandPath(vault.path)
        let safeTitle = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
        let filePath = (expandedPath as NSString).appendingPathComponent("\(safeTitle).md")
        
        do {
            try FileManager.default.createDirectory(atPath: expandedPath, withIntermediateDirectories: true)
            try content.write(toFile: filePath, atomically: true, encoding: .utf8)
            return true
        } catch {
            print("Error saving note: \(error)")
            return false
        }
    }
}

#Preview {
    ObsidianView()
}
