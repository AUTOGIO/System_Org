import SwiftUI

struct RemoteControlView: View {
    @EnvironmentObject var monitoringManager: MonitoringManager
    @State private var remoteMachines: [RemoteMachine] = [
        RemoteMachine(
            id: "macair",
            name: "MacBook Air",
            hostname: "192.168.1.154",
            username: "eduardogiovannini",
            port: 22
        ),
        RemoteMachine(
            id: "imac",
            name: "iMac",
            hostname: "192.168.1.100",
            username: "eduardogiovannini",
            port: 22
        )
    ]
    
    @State private var showAddMachine = false
    @State private var selectedMachine: RemoteMachine?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Remote Machines")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showAddMachine.toggle() }) {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            
            Divider()
            
            // Machines List
            ScrollView {
                VStack(spacing: 12) {
                    ForEach($remoteMachines) { $machine in
                        RemoteMachineCard(machine: $machine, monitoringManager: monitoringManager)
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showAddMachine) {
            AddRemoteMachineSheet(isPresented: $showAddMachine, machines: $remoteMachines)
        }
    }
}

struct RemoteMachineCard: View {
    @Binding var machine: RemoteMachine
    let monitoringManager: MonitoringManager
    
    @State private var showDetails = false
    @State private var showCommandInput = false
    @State private var commandText = ""
    @State private var commandOutput = ""
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Status Indicator
                Circle()
                    .fill(machine.isConnected ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)
                
                // Machine Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(machine.name)
                            .font(.headline)
                        
                        Text(machine.isConnected ? "Connected" : "Disconnected")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(machine.isConnected ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                            .foregroundColor(machine.isConnected ? .green : .gray)
                            .cornerRadius(4)
                    }
                    
                    Text("\(machine.username)@\(machine.hostname):\(machine.port)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let lastCheck = machine.lastConnectionCheck {
                        Text("Last checked: \(lastCheck.formatted(date: .omitted, time: .shortened))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 8) {
                    Button(action: { checkConnection() }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: { showCommandInput.toggle() }) {
                        Image(systemName: "terminal.fill")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: { showDetails.toggle() }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12))
                            .rotationEffect(.degrees(showDetails ? 180 : 0))
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            // Command Input
            if showCommandInput {
                Divider()
                
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "terminal")
                            .foregroundColor(.secondary)
                        
                        TextField("Enter command...", text: $commandText)
                            .textFieldStyle(.plain)
                        
                        Button(action: { executeCommand() }) {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(4)
                    
                    if !commandOutput.isEmpty {
                        ScrollView {
                            Text(commandOutput)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                        }
                        .frame(height: 100)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(4)
                    }
                }
            }
            
            // Details
            if showDetails {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    DetailRow(label: "Hostname", value: machine.hostname)
                    DetailRow(label: "Username", value: machine.username)
                    DetailRow(label: "Port", value: String(machine.port))
                    
                    HStack {
                        Text("Auto-connect")
                            .font(.caption)
                        Spacer()
                        Toggle("", isOn: $machine.isConnected)
                            .labelsHidden()
                    }
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func checkConnection() {
        monitoringManager.checkSSHConnection(to: machine.hostname)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if let connection = monitoringManager.getSSHConnection(for: machine.hostname) {
                machine.isConnected = connection.isConnected
                machine.lastConnectionCheck = connection.lastCheck
            }
        }
    }
    
    private func executeCommand() {
        let cmd = commandText
        guard !cmd.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        commandOutput = "Running…"

        // Moved off the main thread — process.waitUntilExit() blocks until completion
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
            process.arguments = [
                "-o", "ConnectTimeout=10",
                "-o", "BatchMode=yes",          // no interactive prompts
                "-p", String(machine.port),
                "\(machine.username)@\(machine.hostname)",
                cmd
            ]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError  = pipe

            do {
                try process.run()
                process.waitUntilExit()
                let data   = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? "(no output)"
                DispatchQueue.main.async { commandOutput = output.isEmpty ? "✅ Done" : output }
            } catch {
                DispatchQueue.main.async { commandOutput = "❌ \(error.localizedDescription)" }
            }
        }
    }
}

struct AddRemoteMachineSheet: View {
    @Binding var isPresented: Bool
    @Binding var machines: [RemoteMachine]
    
    @State private var name = ""
    @State private var hostname = ""
    @State private var username = ""
    @State private var port = "22"
    
    var body: some View {
        NavigationView {
            Form {
                Section("Machine Details") {
                    TextField("Machine Name", text: $name)
                    TextField("Hostname/IP", text: $hostname)
                    TextField("Username", text: $username)
                    TextField("Port", text: $port)
                }
            }
            .navigationTitle("Add Remote Machine")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let newMachine = RemoteMachine(
                            id: UUID().uuidString,
                            name: name,
                            hostname: hostname,
                            username: username,
                            port: Int(port) ?? 22
                        )
                        machines.append(newMachine)
                        isPresented = false
                    }
                    .disabled(name.isEmpty || hostname.isEmpty || username.isEmpty)
                }
            }
        }
    }
}

#Preview {
    RemoteControlView()
        .environmentObject(MonitoringManager())
}
