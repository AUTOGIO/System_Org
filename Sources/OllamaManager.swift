import Foundation

// MARK: - Models

struct OllamaModel: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let size: Int64
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    var content: String
    let timestamp: Date = Date()
    var isStreaming: Bool = false

    enum Role { case user, assistant, system }
}

// MARK: - OllamaManager

class OllamaManager: NSObject, ObservableObject {
    @Published var isAvailable = false
    @Published var availableModels: [OllamaModel] = []
    @Published var selectedModel = "llama3.2"
    @Published var isGenerating = false
    @Published var statusMessage = "Checking Ollama…"

    static let baseURL = "http://localhost:11434"
    private var streamTask: Task<Void, Never>?

    override init() {
        super.init()
        checkAvailability()
    }

    // MARK: - Availability

    func checkAvailability() {
        guard let url = URL(string: "\(Self.baseURL)/api/tags") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, response, _ in
            DispatchQueue.main.async {
                guard
                    let http = response as? HTTPURLResponse, http.statusCode == 200,
                    let data = data,
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let rawModels = json["models"] as? [[String: Any]]
                else {
                    self?.isAvailable = false
                    self?.statusMessage = "Ollama offline — run: brew services start ollama"
                    return
                }
                let models = rawModels.compactMap { dict -> OllamaModel? in
                    guard let name = dict["name"] as? String else { return nil }
                    let size = dict["size"] as? Int64 ?? 0
                    return OllamaModel(name: name, size: size)
                }
                self?.availableModels = models
                self?.isAvailable = !models.isEmpty
                self?.statusMessage = models.isEmpty
                    ? "No models — run: ollama pull llama3.2"
                    : "\(models.count) model(s) ready"
                // Auto-select best default
                if let best = models.first(where: { $0.name.hasPrefix("llama3") })
                    ?? models.first {
                    self?.selectedModel = best.name
                }
            }
        }.resume()
    }

    // MARK: - Streaming Generate

    /// Streams tokens into `onToken`. Calls `onComplete` when done.
    func generate(
        prompt: String,
        systemPrompt: String = "You are a helpful macOS automation assistant.",
        onToken: @escaping (String) -> Void,
        onComplete: @escaping () -> Void
    ) {
        guard isAvailable else {
            onToken("❌ Ollama is not available. Start it with: brew services start ollama")
            onComplete()
            return
        }

        guard let url = URL(string: "\(Self.baseURL)/api/generate") else { return }

        let body: [String: Any] = [
            "model": selectedModel,
            "prompt": prompt,
            "system": systemPrompt,
            "stream": true
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 300

        isGenerating = true

        streamTask = Task {
            do {
                let (bytes, _) = try await URLSession.shared.bytes(for: request)
                for try await line in bytes.lines {
                    guard !line.isEmpty, !Task.isCancelled else { continue }
                    if let data = line.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let token = json["response"] as? String {
                        await MainActor.run { onToken(token) }
                    }
                }
            } catch {
                await MainActor.run { onToken("\n❌ \(error.localizedDescription)") }
            }
            await MainActor.run {
                self.isGenerating = false
                onComplete()
            }
        }
    }

    func cancelGeneration() {
        streamTask?.cancel()
        streamTask = nil
        isGenerating = false
    }

    // MARK: - Quick (non-streaming) call for automation summaries

    func quickGenerate(prompt: String) async -> String {
        guard isAvailable, let url = URL(string: "\(Self.baseURL)/api/generate") else {
            return "Ollama unavailable"
        }
        let body: [String: Any] = ["model": selectedModel, "prompt": prompt, "stream": false]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 120
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let response = json["response"] as? String {
                return response
            }
        } catch { }
        return "No response"
    }
}
