import Foundation
import OllamaClient

// MARK: - ChatMessage (UI model — stays local to SystemOrganizer)

struct ChatMessage: Identifiable, @unchecked Sendable {
    let id = UUID()
    let role: Role
    var content: String
    let timestamp: Date = Date()
    var isStreaming: Bool = false

    enum Role { case user, assistant, system }
}

// MARK: - OllamaManager
//
// ViewModel wrapper around PersonalOSKit.OllamaClient.
// Owns all @Published state for SwiftUI binding.
// Network calls are fully async/await — no callback-based URLSession.

@MainActor
class OllamaManager: ObservableObject {
    @Published var isAvailable = false
    @Published var availableModels: [OllamaModel] = []
    @Published var selectedModel = "llama3.2"
    @Published var isGenerating = false
    @Published var statusMessage = "Checking Ollama…"

    private let client = OllamaClient()
    private var streamTask: Task<Void, Never>?

    init() {
        Task { await refresh() }
    }

    // MARK: - Availability

    func refresh() async {
        let models = await client.models()
        availableModels = models
        isAvailable = !models.isEmpty
        statusMessage = models.isEmpty
            ? "Ollama offline — run: brew services start ollama"
            : "\(models.count) model(s) ready"

        // Auto-select by preference order
        let preferenceOrder = ["qwen2.5", "gemma3", "deepseek-r1", "llama3", "codellama"]
        if let best = preferenceOrder
            .compactMap({ prefix in models.first(where: { $0.name.hasPrefix(prefix) }) })
            .first ?? models.first {
            selectedModel = best.name
        }
    }

    // Convenience alias kept for call-sites that used the old name
    func checkAvailability() {
        Task { await refresh() }
    }

    // MARK: - Streaming Generate

    /// Streams tokens into `onToken`. Calls `onComplete` when done.
    func generate(
        prompt: String,
        systemPrompt: String = "You are a helpful macOS automation assistant.",
        onToken: @escaping @MainActor (String) -> Void,
        onComplete: @escaping @MainActor () -> Void
    ) {
        guard isAvailable else {
            onToken("❌ Ollama is not available. Start it with: brew services start ollama")
            onComplete()
            return
        }

        isGenerating = true

        streamTask = Task {
            do {
                for try await token in client.generateStream(
                    model: selectedModel,
                    prompt: prompt,
                    system: systemPrompt
                ) {
                    guard !Task.isCancelled else { break }
                    onToken(token)
                }
            } catch {
                onToken("\n❌ \(error.localizedDescription)")
            }
            isGenerating = false
            onComplete()
        }
    }

    func cancelGeneration() {
        streamTask?.cancel()
        streamTask = nil
        isGenerating = false
    }

    // MARK: - Non-streaming (automation summaries)

    func quickGenerate(prompt: String) async -> String {
        guard isAvailable else { return "Ollama unavailable" }
        do {
            return try await client.generate(model: selectedModel, prompt: prompt)
        } catch {
            return "No response: \(error.localizedDescription)"
        }
    }
}
