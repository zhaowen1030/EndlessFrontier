import Foundation

struct LLMResponse {
    let text: String
    let stopReason: String?
    let model: String
}

enum LLMError: LocalizedError {
    case notConfigured(String)
    case invalidConfiguration(String)
    case http(Int, String?)
    case emptyResponse
    case truncated
    case refused(String?)
    case malformed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured(let detail):
            return detail
        case .invalidConfiguration(let detail):
            return detail
        case .http(let status, let message):
            switch status {
            case 401:
                return "API 密钥无效或已过期。请在设置中检查密钥。"
            case 403:
                return "当前密钥没有访问该模型的权限。"
            case 404:
                return "找不到模型或接口地址。请检查模型名称与 Base URL。"
            case 429:
                return "请求过于频繁或已达到额度限制，请稍后重试。"
            case 500...599:
                return "模型服务暂时不可用（HTTP \(status)）。请稍后重试。"
            default:
                let suffix = message.map { "：\($0)" } ?? ""
                return "模型请求失败（HTTP \(status)）\(suffix)"
            }
        case .emptyResponse:
            return "模型返回了空内容，请重试。"
        case .truncated:
            return "模型输出达到长度上限，结果不完整。请重试或缩小报告规模。"
        case .refused(let reason):
            if let reason, !reason.isEmpty { return "模型拒绝生成：\(reason)" }
            return "模型拒绝生成此次内容。"
        case .malformed(let detail):
            return "模型返回的数据格式无法解析：\(detail)"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .http(let status, _): return status == 408 || status == 409 || status == 429 || status >= 500
        case .malformed: return true
        default: return false
        }
    }
}

final class LLMClient: @unchecked Sendable {
    static let shared = LLMClient()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 1_200
        config.httpAdditionalHeaders = [
            "User-Agent": "EndlessFrontier/1.0 (macOS)"
        ]
        session = URLSession(configuration: config)
    }

    func complete(
        system: String?,
        user: String,
        settings: AppSettings,
        maxTokens: Int = 16_000,
        stream: Bool = false,
        effort: String? = nil,
        onText: ((String) -> Void)? = nil
    ) async throws -> LLMResponse {
        let prepared = try await MainActor.run {
            try self.prepare(system: system, user: user, settings: settings, maxTokens: maxTokens, stream: stream, effort: effort)
        }
        if stream {
            return try await performStreaming(prepared, onText: onText)
        }
        return try await performNonStreaming(prepared)
    }

    nonisolated func testConnection(settings: AppSettings) async throws -> String {
        let response = try await complete(
            system: nil,
            user: "Reply with exactly one word: READY",
            settings: settings,
            maxTokens: 256,
            stream: false
        )
        return response.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Request construction

    private struct PreparedRequest {
        let request: URLRequest
        let provider: LLMProvider
        let model: String
    }

    @MainActor
    private func prepare(
        system: String?,
        user: String,
        settings: AppSettings,
        maxTokens: Int,
        stream: Bool,
        effort: String?
    ) throws -> PreparedRequest {
        guard let credential = settings.credential(for: settings.provider) else {
            throw LLMError.notConfigured("尚未配置模型 API 密钥。请打开设置并添加密钥后重试。")
        }
        let model = settings.activeModel
        guard !model.isEmpty else {
            throw LLMError.invalidConfiguration("尚未填写模型名称。请在设置中选择或输入模型。")
        }
        let base = credential.baseURL
        guard !base.isEmpty else {
            throw LLMError.invalidConfiguration("接口地址为空。请检查设置。")
        }

        var body: [String: Any]
        let url: URL

        switch settings.provider {
        case .anthropic:
            guard let endpoint = Self.anthropicEndpoint(base) else {
                throw LLMError.invalidConfiguration("Claude API 接口地址无效。")
            }
            url = endpoint
            var payload: [String: Any] = [
                "model": model,
                "max_tokens": maxTokens,
                "stream": stream,
                "messages": [["role": "user", "content": user]]
            ]
            if let system, !system.isEmpty { payload["system"] = system }
            if let effort, Self.supportsEffort(model) {
                payload["output_config"] = ["effort": effort]
            }
            body = payload

        case .openAICompatible:
            guard let endpoint = Self.openAIEndpoint(base) else {
                throw LLMError.invalidConfiguration("OpenAI 兼容接口地址无效。")
            }
            url = endpoint
            var messages: [[String: String]] = []
            if let system, !system.isEmpty {
                messages.append(["role": "system", "content": system])
            }
            messages.append(["role": "user", "content": user])
            body = [
                "model": model,
                "max_tokens": maxTokens,
                "stream": stream,
                "messages": messages
            ]
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(stream ? "text/event-stream" : "application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        switch settings.provider {
        case .anthropic:
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            if credential.isBearer {
                request.setValue("Bearer \(credential.token)", forHTTPHeaderField: "Authorization")
            } else {
                request.setValue(credential.token, forHTTPHeaderField: "x-api-key")
            }
        case .openAICompatible:
            request.setValue("Bearer \(credential.token)", forHTTPHeaderField: "Authorization")
        }

        return PreparedRequest(request: request, provider: settings.provider, model: model)
    }

    private static func anthropicEndpoint(_ base: String) -> URL? {
        let value = base
        if value.hasSuffix("/messages") { return URL(string: value) }
        if value.hasSuffix("/v1") { return URL(string: value + "/messages") }
        return URL(string: value + "/v1/messages")
    }

    private static func openAIEndpoint(_ base: String) -> URL? {
        var value = base
        while value.hasSuffix("/") { value.removeLast() }
        if value.hasSuffix("/chat/completions") { return URL(string: value) }
        if let url = URL(string: value), (url.path.isEmpty || url.path == "/") {
            value += "/v1"
        }
        return URL(string: value + "/chat/completions")
    }

    private static func supportsEffort(_ model: String) -> Bool {
        let supported = [
            "claude-fable-5-1", "claude-fable-5",
            "claude-opus-5-5", "claude-opus-5",
            "claude-sonnet-5-5", "claude-sonnet-5",
            "claude-haiku-5-5",
            "claude-opus-4-8", "claude-opus-4-7", "claude-opus-4-6",
            "claude-sonnet-4-6"
        ]
        return supported.contains { model == $0 || model.hasPrefix($0 + "-") }
    }

    // MARK: - Non-streaming

    private func performNonStreaming(_ prepared: PreparedRequest) async throws -> LLMResponse {
        var attempt = 0
        while true {
            do {
                return try await performNonStreamingOnce(prepared)
            } catch let error as LLMError where error.isRetryable && attempt < 2 {
                attempt += 1
                try await Task.sleep(nanoseconds: UInt64(attempt) * 1_100_000_000)
            } catch let error as URLError where error.code != .cancelled && attempt < 2 {
                attempt += 1
                try await Task.sleep(nanoseconds: UInt64(attempt) * 1_100_000_000)
            }
        }
    }

    private func performNonStreamingOnce(_ prepared: PreparedRequest) async throws -> LLMResponse {
        do {
            let (data, response) = try await session.data(for: prepared.request)
            guard let http = response as? HTTPURLResponse else {
                throw LLMError.invalidConfiguration("模型服务返回了无效响应。")
            }
            guard (200..<300).contains(http.statusCode) else {
                throw Self.httpError(status: http.statusCode, data: data)
            }
            let parsed = try parseNonStreaming(data, provider: prepared.provider)
            try Self.ensureUsable(stopReason: parsed.stopReason, text: parsed.text)
            return LLMResponse(text: parsed.text, stopReason: parsed.stopReason, model: prepared.model)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as LLMError {
            throw error
        } catch {
            throw LLMError.malformed(error.localizedDescription)
        }
    }

    private func parseNonStreaming(_ data: Data, provider: LLMProvider) throws -> (text: String, stopReason: String?) {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMError.malformed("响应不是 JSON。")
        }
        switch provider {
        case .anthropic:
            if let error = root["error"] as? [String: Any] {
                throw LLMError.http(200, error["message"] as? String)
            }
            let blocks = root["content"] as? [[String: Any]] ?? []
            let text = blocks.compactMap { block -> String? in
                guard block["type"] as? String == "text" else { return nil }
                return block["text"] as? String
            }.joined()
            return (text, root["stop_reason"] as? String)
        case .openAICompatible:
            if let error = root["error"] as? [String: Any] {
                throw LLMError.http(200, error["message"] as? String)
            }
            guard let choices = root["choices"] as? [[String: Any]], let first = choices.first else {
                throw LLMError.malformed("响应中没有 choices。")
            }
            let message = first["message"] as? [String: Any] ?? [:]
            let text: String
            if let string = message["content"] as? String {
                text = string
            } else if let blocks = message["content"] as? [[String: Any]] {
                text = blocks.compactMap { $0["text"] as? String }.joined()
            } else {
                text = ""
            }
            return (text, first["finish_reason"] as? String)
        }
    }

    // MARK: - Streaming

    private func performStreaming(_ prepared: PreparedRequest, onText: ((String) -> Void)?) async throws -> LLMResponse {
        var request = prepared.request
        request.timeoutInterval = 600
        let (bytes, response): (URLSession.AsyncBytes, URLResponse)
        do {
            (bytes, response) = try await session.bytes(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw LLMError.malformed(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw LLMError.invalidConfiguration("模型服务返回了无效响应。")
        }
        guard (200..<300).contains(http.statusCode) else {
            var data = Data()
            do {
                for try await byte in bytes {
                    data.append(byte)
                    if data.count > 200_000 { break }
                }
            } catch {}
            throw Self.httpError(status: http.statusCode, data: data)
        }

        var text = ""
        var stopReason: String?
        var apiErrorMessage: String?
        var receivedDone = false
        var pendingText = ""
        var lastFlush = Date.distantPast

        func flushPending() async {
            guard !pendingText.isEmpty else { return }
            let chunk = pendingText
            pendingText = ""
            await MainActor.run {
                onText?(chunk)
            }
        }

        do {
            for try await rawLine in bytes.lines {
                try Task.checkCancellation()
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                guard line.hasPrefix("data:") else { continue }
                let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                if payload == "[DONE]" {
                    receivedDone = true
                    break
                }
                guard let data = payload.data(using: .utf8),
                      let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    continue
                }

                switch prepared.provider {
                case .anthropic:
                    let type = event["type"] as? String ?? ""
                    switch type {
                    case "content_block_delta":
                        if let delta = event["delta"] as? [String: Any],
                           delta["type"] as? String == "text_delta",
                           let piece = delta["text"] as? String {
                            text += piece
                            pendingText += piece
                            if pendingText.count >= 400 || Date().timeIntervalSince(lastFlush) > 0.12 {
                                lastFlush = Date()
                                await flushPending()
                            }
                        }
                    case "message_delta":
                        if let delta = event["delta"] as? [String: Any] {
                            stopReason = delta["stop_reason"] as? String ?? stopReason
                        }
                    case "message_stop":
                        receivedDone = true
                    case "error":
                        apiErrorMessage = (event["error"] as? [String: Any])?["message"] as? String
                    default:
                        break
                    }

                case .openAICompatible:
                    if let error = event["error"] as? [String: Any] {
                        apiErrorMessage = error["message"] as? String
                        continue
                    }
                    guard let choices = event["choices"] as? [[String: Any]], let first = choices.first else {
                        continue
                    }
                    if let delta = first["delta"] as? [String: Any],
                       let piece = delta["content"] as? String {
                        text += piece
                        pendingText += piece
                        if pendingText.count >= 400 || Date().timeIntervalSince(lastFlush) > 0.12 {
                            lastFlush = Date()
                            await flushPending()
                        }
                    }
                    if let reason = first["finish_reason"] as? String, !reason.isEmpty {
                        stopReason = reason
                    }
                }
            }
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as CancellationError {
            throw error
        } catch {
            throw LLMError.malformed(error.localizedDescription)
        }

        await flushPending()
        if let apiErrorMessage {
            throw LLMError.http(200, apiErrorMessage)
        }
        if !receivedDone && text.isEmpty {
            throw LLMError.emptyResponse
        }
        try Self.ensureUsable(stopReason: stopReason, text: text)
        return LLMResponse(text: text, stopReason: stopReason, model: prepared.model)
    }

    // MARK: - Helpers

    private static func ensureUsable(stopReason: String?, text: String) throws {
        if stopReason == "refusal" {
            throw LLMError.refused(nil)
        }
        if stopReason == "max_tokens" || stopReason == "length" {
            throw LLMError.truncated
        }
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw LLMError.emptyResponse
        }
    }

    private static func httpError(status: Int, data: Data) -> LLMError {
        if let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = root["error"] as? [String: Any],
           let message = error["message"] as? String {
            return .http(status, message)
        }
        if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            return .http(status, String(text.prefix(400)))
        }
        return .http(status, nil)
    }
}
