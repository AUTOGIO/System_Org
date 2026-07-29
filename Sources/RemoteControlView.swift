import SwiftUI

struct RemoteControlView: View {
    @EnvironmentObject var monitoringManager: MonitoringManager
    @State private var machines: [RemoteMachine] = AutomationManager.loadMachines()
    @State private var showAddMachine = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Remote Machines").font(.headline)
                Spacer()
                Button { showAddMachine.toggle() } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            Divider()

            ScrollView {
                VStack(spacing: 12) {
                    ForEach($machines) { $machine in
                        RemoteMachineCard(machine: $machine, monitoringManager: monitoringManager) {
                            saveMachines()
                        }
                    }
                    .onDelete { offsets in
                        machines.remove(atOffsets: offsets)
                        saveMachines()
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showAddMachine) {
            AddRemoteMachineSheet(isPresented: $showAddMachine) { newMachine in
                machines.append(newMachine)
                saveMachines()
            }
        }
    }

    private func saveMachines() {
        AutomationManager.saveMachines(machines)
    }
}

// MARK: - RemoteMachineCard

struct RemoteMachineCard: View {
    @Binding var machine: RemoteMachine
    let monitoringManager: MonitoringManager
    var onChanged: () -> Void = {}

    @State private var showDetails      = false
    @State private var showCommandInput = false
    @State private var commandText      = ""
    @State private var commandOutput    = ""
    @State private var isRunningCmd     = false
    @State private var showCommandConfirm = false
    @State private var pendingCommand   = ""

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(machine.isConnected ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(machine.name).font(.headline)
                        Text(machine.isConnected ? "Connected" : "Disconnected")
                            .font(.caption)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background((machine.isConnected ? Color.green : Color.gray).opacity(0.2))
                            .foregroundColor(machine.isConnected ? .green : .gray)
                            .cornerRadius(4)
                    }
                    Text("\(machine.username)@\(machine.hostname):\(machine.port)")
                        .font(.caption).foregroundColor(.secondary)
                    if let lastCheck = machine.lastConnectionCheck {
                        Text("Checked: \(lastCheck.formatted(date: .omitted, time: .shortened))")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                }
                Spacer()

                HStack(spacing: 8) {
                    Button { checkConnection() } label: {
                        Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 12))
                    }.buttonStyle(.bordered)

                    Button { showCommandInput.toggle() } label: {
                        Image(systemName: "terminal.fill").font(.system(size: 12))
                    }.buttonStyle(.bordered)

                    Button { showDetails.toggle() } label: {
                        Image(systemName: "chevron.down").font(.system(size: 12))
                            .rotationEffect(.degrees(showDetails ? 180 : 0))
                    }.buttonStyle(.bordered)
                }
            }

            if showCommandInput {
                Divider()
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "terminal").foregroundColor(.secondary)
                        TextField("Enter command…", text: $commandText)
                            .textFieldStyle(.plain)
                            .onSubmit { executeCommand() }
                        if isRunningCmd {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Button { executeCommand() } label: {
                                Image(systemName: "arrow.right.circle.fill").foregroundColor(.blue)
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(8).background(Color(.controlBackgroundColor)).cornerRadius(4)

                    if !commandOutput.isEmpty {
                        ScrollView {
                            Text(commandOutput)
                                .font(.caption2).foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                        }
                        .frame(height: 100).background(Color(.controlBackgroundColor)).cornerRadius(4)
                    }
                }
            }

            if showDetails {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    DetailRow(label: "Hostname", value: machine.hostname)
                    DetailRow(label: "Username", value: machine.username)
                    DetailRow(label: "Port",     value: String(machine.port))
                }
            }
        }
        .padding().background(Color(.controlBackgroundColor)).cornerRadius(8)
        .alert("Run remote command?", isPresented: $showCommandConfirm) {
            Button("Cancel", role: .cancel) {
                pendingCommand = ""
            }
            Button("Run", role: .destructive) {
                runRemoteCommand(pendingCommand)
                pendingCommand = ""
            }
        } message: {
            Text("This will run over SSH on \(machine.username)@\(machine.hostname):\n\n\(pendingCommand)")
        }
    }

    private func checkConnection() {
        monitoringManager.checkSSHConnection(to: machine.hostname, username: machine.username, port: machine.port)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if let conn = monitoringManager.getSSHConnection(to: machine.hostname, username: machine.username) {
                machine.isConnected         = conn.isConnected
                machine.lastConnectionCheck = conn.lastCheck
                onChanged()
            }
        }
    }

    private func executeCommand() {
        let cmd = commandText.trimmingCharacters(in: .whitespaces)
        guard !cmd.isEmpty else { return }
        pendingCommand = cmd
        showCommandConfirm = true
    }

    private func runRemoteCommand(_ cmd: String) {
        commandOutput = "Running…"
        isRunningCmd  = true

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
            process.arguments = [
                "-o", "ConnectTimeout=10",
                "-o", "BatchMode=yes",
                "-p", String(machine.port),
                "\(machine.username)@\(machine.hostname)", cmd
            ]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError  = pipe
            do {
                try process.run()
                process.waitUntilExit()
                let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                DispatchQueue.main.async {
                    commandOutput = out.isEmpty ? "✅ Done" : out
                    isRunningCmd  = false
                }
            } catch {
                DispatchQueue.main.async {
                    commandOutput = "❌ \(error.localizedDescription)"
                    isRunningCmd  = false
                }
            }
        }
    }
}

// MARK: - AddRemoteMachineSheet

struct AddRemoteMachineSheet: View {
    @Binding var isPresented: Bool
    var onAdd: (RemoteMachine) -> Void

    @State private var name     = ""
    @State private var hostname = ""
    @State private var username = ""
    @State private var port     = "22"

    var body: some View {
        NavigationView {
            Form {
                Section("Machine Details") {
                    TextField("Name",        text: $name)
                    TextField("Hostname/IP", text: $hostname)
                    TextField("Username",    text: $username)
                    TextField("Port",        text: $port)
                }
            }
            .navigationTitle("Add Remote Machine")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(RemoteMachine(id: UUID().uuidString, name: name,
                                            hostname: hostname, username: username,
                                            port: Int(port) ?? 22))
                        isPresented = false
                    }
                    .disabled(name.isEmpty || hostname.isEmpty || username.isEmpty)
                }
            }
        }
    }
}

#Preview { RemoteControlView().environmentObject(MonitoringManager()) }
