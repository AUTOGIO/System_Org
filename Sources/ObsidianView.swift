import SwiftUI

struct ObsidianView: View {
    @State private var vaults: [ObsidianVault] = [
        ObsidianVault(
            id: "main",
            name: "Main Vault",
            path: "$HOME/Documents/OBSIDIAN_VAULTS",
            isDefault: true
        )
    ]
    
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
            AddVaultSheet(isPresented: $showAddVault, vaults: $vaults)
        }
        .sheet(isPresented: $showNewNote) {
            NewNoteSheet(
                isPresented: $showNewNote,
                vault: selectedVault,
                title: $newNoteTitle,
                content: $newNoteContent
            )
        }
        .onAppear {
            if let defaultVault = vaults.first(where: { $0.isDefault }) {
                selectedVault = defaultVault
                loadNotes(from: defaultVault)
            }
        }
    }
    
    private func loadNotes(from vault: ObsidianVault) {
        let expandedPath = NSString(string: vault.path).expandingTildeInPath
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: expandedPath)
            notes = contents.filter { $0.hasSuffix(".md") }
        } catch {
            notes = []
        }
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
                        saveNote()
                        isPresented = false
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func saveNote() {
        guard let vault = vault else { return }
        
        let expandedPath = NSString(string: vault.path).expandingTildeInPath
        let filePath = (expandedPath as NSString).appendingPathComponent("\(title).md")
        
        do {
            try FileManager.default.createDirectory(atPath: expandedPath, withIntermediateDirectories: true)
            try content.write(toFile: filePath, atomically: true, encoding: .utf8)
        } catch {
            print("Error saving note: \(error)")
        }
    }
}

#Preview {
    ObsidianView()
}
