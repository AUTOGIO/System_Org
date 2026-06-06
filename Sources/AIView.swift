import SwiftUI

struct AIView: View {
    @EnvironmentObject var ollamaManager: OllamaManager
    @EnvironmentObject var automationManager: AutomationManager

    @State private var inputText = ""
    @State private var messages: [ChatMessage] = []
    @State private var showModelPicker = false
    @State private var autoSaveToObsidian = false
    @State private var scrollProxy: ScrollViewProxy? = nil

    private let systemPrompt = """
    You are a macOS automation assistant integrated into System Organizer.
    You help the user write AppleScript, Shell, and Python scripts for macOS automation.
    When asked to write scripts, output clean, runnable code.
    Be concise and practical.
    """

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──────────────────────────────────────────────
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Assistant")
                        .font(.headline)
                    Text(ollamaManager.statusMessage)
                        .font(.caption2)
                        .foregroundColor(ollamaManager.isAvailable ? .green : .orange)
                }

                Spacer()

                // Model picker
                Menu {
                    ForEach(ollamaManager.availableModels) { model in
                        Button(action: { ollamaManager.selectedModel = model.name }) {
                            HStack {
                                Text(model.name)
                                if ollamaManager.selectedModel == model.name {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    Divider()
                    Button("Refresh models") { ollamaManager.checkAvailability() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                        Text(shortModelName(ollamaManager.selectedModel))
                            .font(.caption)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(6)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                // Save to Obsidian toggle
                Button(action: { autoSaveToObsidian.toggle() }) {
                    Image(systemName: autoSaveToObsidian ? "note.text.badge.plus" : "note.text")
                        .foregroundColor(autoSaveToObsidian ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .help("Auto-save conversation to Obsidian")

                // Clear
                Button(action: clearChat) {
                    Image(systemName: "trash")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(messages.isEmpty)
            }
            .padding()
            .background(Color(.controlBackgroundColor))

            Divider()

            // ── Messages ─────────────────────────────────────────────
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if messages.isEmpty {
                            AIWelcomeCard(onSuggestionTap: { inputText = $0 })
                                .padding(.top, 20)
                        }
                        ForEach(messages) { msg in
                            ChatBubble(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding()
                }
                .onAppear { scrollProxy = proxy }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider()

            // ── Input bar ────────────────────────────────────────────
            HStack(spacing: 10) {
                // Quick action buttons
                Menu {
                    Button("Summarize my automations") {
                        sendMessage("List my automations and suggest improvements: \(automationSummary())")
                    }
                    Button("Write a cleanup script") {
                        inputText = "Write a macOS shell script to organize my Downloads folder by file type."
                    }
                    Button("Write an AppleScript") {
                        inputText = "Write an AppleScript that "
                    }
                    Button("Explain a script") {
                        inputText = "Explain what this script does: "
                    }
                } label: {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.blue)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                TextField("Ask anything about macOS automation…", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .onSubmit { sendCurrentMessage() }

                if ollamaManager.isGenerating {
                    Button(action: { ollamaManager.cancelGeneration() }) {
                        Image(systemName: "stop.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: sendCurrentMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(inputText.isEmpty ? .secondary : .blue)
                    }
                    .buttonStyle(.plain)
                    .disabled(inputText.isEmpty || !ollamaManager.isAvailable)
                }
            }
            .padding(12)
            .background(Color(.controlBackgroundColor))
        }
        .onAppear { ollamaManager.checkAvailability() }
    }

    // MARK: - Actions

    private func sendCurrentMessage() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        sendMessage(inputText)
        inputText = ""
    }

    private func sendMessage(_ text: String) {
        let userMsg = ChatMessage(role: .user, content: text)
        messages.append(userMsg)

        let assistantMsg = ChatMessage(role: .assistant, content: "", isStreaming: true)
        messages.append(assistantMsg)
        let assistantId = assistantMsg.id

        ollamaManager.generate(
            prompt: text,
            systemPrompt: systemPrompt,
            onToken: { token in
                if let idx = messages.firstIndex(where: { $0.id == assistantId }) {
                    messages[idx].content += token
                }
            },
            onComplete: {
                if let idx = messages.firstIndex(where: { $0.id == assistantId }) {
                    messages[idx].isStreaming = false
                }
                if autoSaveToObsidian { saveToObsidian() }
            }
        )
    }

    private func clearChat() {
        ollamaManager.cancelGeneration()
        messages.removeAll()
    }

    private func automationSummary() -> String {
        automationManager.automations.map {
            "• \($0.name) (\($0.schedule)) — \($0.isEnabled ? "enabled" : "disabled")"
        }.joined(separator: "\n")
    }

    private func saveToObsidian() {
        let vault = AutomationManager.expandPath("$HOME/Documents/OBSIDIAN_VAULTS")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        let title = "AI Chat \(formatter.string(from: Date()))"
        let content = messages.map { m in
            "**\(m.role == .user ? "You" : "AI"):** \(m.content)"
        }.joined(separator: "\n\n")
        let path = (vault as NSString).appendingPathComponent("\(title).md")
        try? FileManager.default.createDirectory(atPath: vault, withIntermediateDirectories: true)
        try? content.write(toFile: path, atomically: true, encoding: .utf8)
    }

    private func shortModelName(_ name: String) -> String {
        name.components(separatedBy: ":").first ?? name
    }
}

// MARK: - ChatBubble

struct ChatBubble: View {
    let message: ChatMessage

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if !isUser {
                        Image(systemName: "brain.head.profile")
                            .font(.caption2)
                            .foregroundColor(.purple)
                    }
                    Text(isUser ? "You" : "AI")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if !isUser {
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if isUser {
                        Image(systemName: "person.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }

                ZStack(alignment: .bottomTrailing) {
                    Text(message.content.isEmpty && message.isStreaming ? "●" : message.content)
                        .font(.callout)
                        .textSelection(.enabled)
                        .padding(10)
                        .background(isUser ? Color.blue : Color(.controlBackgroundColor))
                        .foregroundColor(isUser ? .white : .primary)
                        .cornerRadius(10)

                    if message.isStreaming {
                        ProgressView()
                            .scaleEffect(0.5)
                            .padding(4)
                    }
                }
            }

            if !isUser { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Welcome Card

struct AIWelcomeCard: View {
    let onSuggestionTap: (String) -> Void

    private let suggestions = [
        ("Write an AppleScript", "Write an AppleScript that shows a notification on macOS"),
        ("Organize Downloads", "Write a shell script to organize my Downloads folder by file extension"),
        ("Explain cron syntax", "Explain macOS launchd plist scheduling vs cron jobs"),
        ("Python automation", "Write a Python script to rename all files in a folder with today's date prefix"),
    ]

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 40))
                .foregroundColor(.purple)
            Text("Local AI — powered by Ollama")
                .font(.headline)
            Text("Your data stays on-device. No internet required.")
                .font(.caption)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(suggestions, id: \.0) { title, prompt in
                    Button(action: { onSuggestionTap(prompt) }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title)
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text(prompt)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
    }
}

#Preview {
    AIView()
        .environmentObject(OllamaManager())
        .environmentObject(AutomationManager())
}
