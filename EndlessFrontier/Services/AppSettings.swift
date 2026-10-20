import Foundation
import SwiftUI

enum LLMProvider: String, CaseIterable, Identifiable {
    case anthropic
    case openAICompatible

    var id: String { rawValue }

    var titleEN: String {
        switch self {
        case .anthropic: return "Claude API"
        case .openAICompatible: return "OpenAI-compatible"
        }
    }

    var titleZH: String {
        switch self {
        case .anthropic: return "Claude API"
        case .openAICompatible: return "OpenAI 兼容接口"
        }
    }

    var defaultModel: String {
        switch self {
        case .anthropic: return "claude-opus-5-5"
        case .openAICompatible: return ""
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .anthropic: return "https://api.anthropic.com"
        case .openAICompatible: return "https://api.openai.com/v1"
        }
    }

    var keychainAccount: String {
        switch self {
        case .anthropic: return "anthropic-api-key"
        case .openAICompatible: return "openai-compatible-api-key"
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .anthropic: return "sk-ant-..."
        case .openAICompatible: return "sk-..."
        }
    }
}

enum TranslationMode: String, CaseIterable, Identifiable {
    case automatic
    case llmOnly
    case systemOnly
    case off

    var id: String { rawValue }

    var labelZH: String {
        switch self {
        case .automatic: return "自动选择"
        case .llmOnly: return "仅使用大模型"
        case .systemOnly: return "仅使用系统翻译"
        case .off: return "关闭"
        }
    }

    var labelEN: String {
        switch self {
        case .automatic: return "Automatic"
        case .llmOnly: return "Language model only"
        case .systemOnly: return "Apple Translation only"
        case .off: return "Off"
        }
    }
}

struct LLMCredential {
    let token: String
    let isBearer: Bool
    let baseURL: String
    let source: CredentialSource
}

enum CredentialSource: String {
    case app = "App"
    case environment = "Environment"
}

@MainActor
final class AppSettings: ObservableObject {
    private let defaults = UserDefaults.standard
    private var cachedKeys: [LLMProvider: String] = [:]

    @Published var provider: LLMProvider = .anthropic {
        didSet { defaults.set(provider.rawValue, forKey: Keys.provider) }
    }

    @Published var anthropicModel: String = LLMProvider.anthropic.defaultModel {
        didSet { defaults.set(anthropicModel, forKey: Keys.anthropicModel) }
    }

    @Published var anthropicBaseURL: String = LLMProvider.anthropic.defaultBaseURL {
        didSet { defaults.set(anthropicBaseURL, forKey: Keys.anthropicBaseURL) }
    }

    @Published var openAIModel: String = "" {
        didSet { defaults.set(openAIModel, forKey: Keys.openAIModel) }
    }

    @Published var openAIBaseURL: String = LLMProvider.openAICompatible.defaultBaseURL {
        didSet { defaults.set(openAIBaseURL, forKey: Keys.openAIBaseURL) }
    }

    @Published var translationMode: TranslationMode = .automatic {
        didSet { defaults.set(translationMode.rawValue, forKey: Keys.translationMode) }
    }

    @Published var autoTranslate: Bool = true {
        didSet { defaults.set(autoTranslate, forKey: Keys.autoTranslate) }
    }

    @Published var pageSize: Int = 25 {
        didSet { defaults.set(pageSize, forKey: Keys.pageSize) }
    }

    @Published private(set) var keyRevision: Int = 0

    init() {
        if let raw = defaults.string(forKey: Keys.provider), let value = LLMProvider(rawValue: raw) {
            provider = value
        }
        if let value = defaults.string(forKey: Keys.anthropicModel), !value.isEmpty {
            anthropicModel = value
        }
        if let value = defaults.string(forKey: Keys.anthropicBaseURL), !value.isEmpty {
            anthropicBaseURL = value
        }
        if let value = defaults.string(forKey: Keys.openAIModel) {
            openAIModel = value
        }
        if let value = defaults.string(forKey: Keys.openAIBaseURL), !value.isEmpty {
            openAIBaseURL = value
        }
        if let raw = defaults.string(forKey: Keys.translationMode), let mode = TranslationMode(rawValue: raw) {
            translationMode = mode
        }
        if defaults.object(forKey: Keys.autoTranslate) != nil {
            autoTranslate = defaults.bool(forKey: Keys.autoTranslate)
        }
        if let size = defaults.object(forKey: Keys.pageSize) as? Int, [20, 25, 50].contains(size) {
            pageSize = size
        }
        for provider in LLMProvider.allCases {
            cachedKeys[provider] = KeychainStore.read(account: provider.keychainAccount)
        }
    }

    var activeModel: String {
        switch provider {
        case .anthropic: return anthropicModel.trimmingCharacters(in: .whitespacesAndNewlines)
        case .openAICompatible: return openAIModel.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    var activeBaseURL: String {
        switch provider {
        case .anthropic: return anthropicBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        case .openAICompatible: return openAIBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    var isConfigured: Bool {
        credential(for: provider) != nil
            && !activeModel.isEmpty
            && URL(string: activeBaseURL) != nil
    }

    var configurationHint: String {
        if activeModel.isEmpty {
            return "请先选择一个模型。"
        }
        if credential(for: provider) == nil {
            return "请先在设置中填写 API 密钥。"
        }
        if URL(string: activeBaseURL) == nil {
            return "接口地址无效。"
        }
        return ""
    }

    func hasKey(for provider: LLMProvider) -> Bool {
        cachedKeys[provider]?.isEmpty == false
    }

    func credentialSource(for provider: LLMProvider) -> CredentialSource? {
        credential(for: provider)?.source
    }

    func setAPIKey(_ value: String, for provider: LLMProvider) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            KeychainStore.delete(account: provider.keychainAccount)
            cachedKeys[provider] = nil
        } else {
            KeychainStore.save(trimmed, account: provider.keychainAccount)
            cachedKeys[provider] = trimmed
        }
        keyRevision += 1
    }

    func removeAPIKey(for provider: LLMProvider) {
        setAPIKey("", for: provider)
    }

    func credential(for provider: LLMProvider) -> LLMCredential? {
        switch provider {
        case .anthropic:
            if let stored = cachedKeys[.anthropic], !stored.isEmpty {
                return LLMCredential(
                    token: stored,
                    isBearer: false,
                    baseURL: normalizedBase(anthropicBaseURL),
                    source: .app
                )
            }
            if let env = nonEmpty(ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]) {
                return LLMCredential(
                    token: env,
                    isBearer: false,
                    baseURL: normalizedBase(ProcessInfo.processInfo.environment["ANTHROPIC_BASE_URL"] ?? anthropicBaseURL),
                    source: .environment
                )
            }
            if let env = nonEmpty(ProcessInfo.processInfo.environment["ANTHROPIC_AUTH_TOKEN"]) {
                return LLMCredential(
                    token: env,
                    isBearer: true,
                    baseURL: normalizedBase(ProcessInfo.processInfo.environment["ANTHROPIC_BASE_URL"] ?? anthropicBaseURL),
                    source: .environment
                )
            }
            return nil
        case .openAICompatible:
            if let stored = cachedKeys[.openAICompatible], !stored.isEmpty {
                return LLMCredential(
                    token: stored,
                    isBearer: true,
                    baseURL: normalizedBase(openAIBaseURL),
                    source: .app
                )
            }
            if let env = nonEmpty(ProcessInfo.processInfo.environment["OPENAI_API_KEY"]) {
                return LLMCredential(
                    token: env,
                    isBearer: true,
                    baseURL: normalizedBase(openAIBaseURL),
                    source: .environment
                )
            }
            return nil
        }
    }

    func effectiveBaseURL(for provider: LLMProvider) -> String {
        if provider == .anthropic,
           cachedKeys[.anthropic] == nil,
           let env = nonEmpty(ProcessInfo.processInfo.environment["ANTHROPIC_BASE_URL"]) {
            return normalizedBase(env)
        }
        switch provider {
        case .anthropic: return normalizedBase(anthropicBaseURL)
        case .openAICompatible: return normalizedBase(openAIBaseURL)
        }
    }

    private func normalizedBase(_ value: String) -> String {
        var string = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while string.hasSuffix("/") { string.removeLast() }
        return string
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }

    private enum Keys {
        static let provider = "endlessfrontier.provider"
        static let anthropicModel = "endlessfrontier.anthropic.model"
        static let anthropicBaseURL = "endlessfrontier.anthropic.baseURL"
        static let openAIModel = "endlessfrontier.openai.model"
        static let openAIBaseURL = "endlessfrontier.openai.baseURL"
        static let translationMode = "endlessfrontier.translation.mode"
        static let autoTranslate = "endlessfrontier.translation.auto"
        static let pageSize = "endlessfrontier.pageSize"
    }
}
