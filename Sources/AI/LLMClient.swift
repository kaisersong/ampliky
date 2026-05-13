import Foundation

// MARK: - LLM Providers

struct LLMProvider: Identifiable, Hashable {
    let id: String
    let label: String
    let baseUrl: String
    let defaultModel: String
    let availableModels: [String]
    let apiProtocol: LLMProtocol

    var idValue: String { id }

    static let all: [LLMProvider] = [
        LLMProvider(id: "openai", label: "OpenAI", baseUrl: "https://api.openai.com/v1",
                     defaultModel: "gpt-4o", availableModels: ["gpt-4o", "gpt-4.1", "o4-mini", "o3"],
                     apiProtocol: .openai),
        LLMProvider(id: "anthropic", label: "Anthropic", baseUrl: "https://api.anthropic.com",
                     defaultModel: "claude-sonnet-4-6", availableModels: ["claude-opus-4-6", "claude-sonnet-4-6", "claude-haiku-4-6"],
                     apiProtocol: .anthropic),
        LLMProvider(id: "kimi", label: "Kimi", baseUrl: "https://api.kimi.com/coding/v1",
                     defaultModel: "kimi-for-coding", availableModels: ["kimi-for-coding"],
                     apiProtocol: .openai),
        LLMProvider(id: "deepseek", label: "DeepSeek", baseUrl: "https://api.deepseek.com",
                     defaultModel: "deepseek-v4-pro", availableModels: ["deepseek-v4-pro", "deepseek-v4-flash"],
                     apiProtocol: .openai),
        LLMProvider(id: "glm", label: "智谱 GLM", baseUrl: "https://open.bigmodel.cn/api/paas/v4",
                     defaultModel: "glm-4.5", availableModels: ["glm-4.5"],
                     apiProtocol: .openai),
        LLMProvider(id: "minimax", label: "MiniMax", baseUrl: "https://api.minimax.chat/v1",
                     defaultModel: "MiniMax-Text-01", availableModels: ["MiniMax-Text-01"],
                     apiProtocol: .openai),
        LLMProvider(id: "gemini", label: "Gemini", baseUrl: "https://generativelanguage.googleapis.com/v1beta/openai",
                     defaultModel: "gemini-2.5-pro", availableModels: ["gemini-2.5-pro"],
                     apiProtocol: .openai),
    ]

    static func byId(_ id: String) -> LLMProvider {
        all.first { $0.id == id } ?? all[0]
    }
}

enum LLMProtocol: String {
    case openai    // POST /chat/completions
    case anthropic // POST /messages
}

// MARK: - LLM Config

struct LLMConfig: Codable {
    var provider: String = "anthropic"
    var model: String = "claude-sonnet-4-6"
    var apiKey: String = ""
    var baseUrl: String = ""
}

// MARK: - LLM Client

class LLMClient {
    private let config: LLMConfig

    init(config: LLMConfig) {
        self.config = config
    }

    /// Call the LLM with system + user message, return the assistant response
    func chat(system: String, user: String) async throws -> String {
        let provider = LLMProvider.byId(config.provider)
        let apiKey = config.apiKey
        let baseUrl = config.baseUrl.isEmpty ? provider.baseUrl : config.baseUrl
        let model = config.model.isEmpty ? provider.defaultModel : config.model

        switch provider.apiProtocol {
        case .openai:
            return try await callOpenAI(baseUrl: baseUrl, apiKey: apiKey, model: model, system: system, user: user)
        case .anthropic:
            return try await callAnthropic(baseUrl: baseUrl, apiKey: apiKey, model: model, system: system, user: user)
        }
    }

    private func callOpenAI(baseUrl: String, apiKey: String, model: String, system: String, user: String) async throws -> String {
        guard let url = URL(string: "\(baseUrl)/chat/completions") else {
            throw LLMError.invalidURL
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ],
            "temperature": 0.0
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "unknown error"
            throw LLMError.apiError(errorText)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let firstChoice = choices?.first
        let message = firstChoice?["message"] as? [String: Any]
        let content = message?["content"] as? String

        guard let content = content else {
            throw LLMError.emptyResponse
        }
        return content
    }

    private func callAnthropic(baseUrl: String, apiKey: String, model: String, system: String, user: String) async throws -> String {
        guard let url = URL(string: "\(baseUrl)/v1/messages") else {
            throw LLMError.invalidURL
        }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": system,
            "messages": [
                ["role": "user", "content": user]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "unknown error"
            throw LLMError.apiError(errorText)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let contentBlocks = json?["content"] as? [[String: Any]]
        let firstBlock = contentBlocks?.first
        let text = firstBlock?["text"] as? String

        guard let text = text else {
            throw LLMError.emptyResponse
        }
        return text
    }

    /// Test the connection without sending a real request
    func testConnection() async throws -> Bool {
        let provider = LLMProvider.byId(config.provider)
        let baseUrl = config.baseUrl.isEmpty ? provider.baseUrl : config.baseUrl

        // Just try to create a URL and check connectivity
        guard URL(string: baseUrl) != nil else { return false }

        // Send a minimal request to verify auth
        do {
            _ = try await chat(system: "test", user: "Say OK")
            return true
        } catch {
            return false
        }
    }
}

enum LLMError: Error, LocalizedError {
    case invalidURL
    case apiError(String)
    case emptyResponse
    case noApiKey

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的 Base URL"
        case .apiError(let msg): return "API 错误: \(msg)"
        case .emptyResponse: return "LLM 返回为空"
        case .noApiKey: return "请先配置 API Key"
        }
    }
}
