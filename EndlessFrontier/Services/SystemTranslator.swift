import Foundation
import SwiftUI
@preconcurrency import Translation

enum SystemTranslationError: LocalizedError {
    case unavailable
    case preparationFailed(String)
    case timedOut
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "系统翻译暂不支持英语到简体中文。请在系统设置中检查翻译语言。"
        case .preparationFailed(let detail):
            return "无法准备系统翻译语言包：\(detail)"
        case .timedOut:
            return "系统翻译语言包准备超时。请重试，或在系统设置中下载英语与简体中文语言包。"
        case .emptyResult:
            return "系统翻译没有返回结果。"
        }
    }
}

/// Uses Apple's on-device Translation framework through a hidden SwiftUI host.
/// The host supplies a live `TranslationSession`; requests are queued until the
/// language assets are ready, and the session is intentionally kept alive while
/// the app is running so later batches do not need to re-prepare.
@MainActor
final class SystemTranslator: ObservableObject {
    @Published private(set) var configuration: TranslationSession.Configuration?
    @Published private(set) var isPreparing = false
    @Published private(set) var lastError: String?

    private let sourceLanguage = Locale.Language(identifier: "en")
    private let targetLanguage = Locale.Language(identifier: "zh-Hans")
    private var activeSession: TranslationSession?
    private var waiters: [CheckedContinuation<TranslationSession, Error>] = []
    private var timeoutTask: Task<Void, Never>?

    func translate(_ texts: [String]) async throws -> [String] {
        guard !texts.isEmpty else { return [] }
        let session = try await acquireSession()
        do {
            let requests = texts.enumerated().map {
                TranslationSession.Request(sourceText: $1, clientIdentifier: String($0))
            }
            let responses = try await session.translations(from: requests)
            var result = [String](repeating: "", count: texts.count)
            for response in responses {
                if let identifier = response.clientIdentifier,
                   let index = Int(identifier),
                   result.indices.contains(index) {
                    result[index] = response.targetText
                }
            }
            guard result.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                throw SystemTranslationError.emptyResult
            }
            lastError = nil
            return result
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    func handle(session: TranslationSession) async {
        activeSession = session
        isPreparing = true
        do {
            try await session.prepareTranslation()
        } catch {
            let message = error.localizedDescription
            lastError = message
            failWaiters(SystemTranslationError.preparationFailed(message))
            activeSession = nil
            configuration = nil
            isPreparing = false
            return
        }

        timeoutTask?.cancel()
        timeoutTask = nil
        isPreparing = false
        lastError = nil
        let pending = waiters
        waiters.removeAll()
        for waiter in pending { waiter.resume(returning: session) }

        // Keep the action (and therefore the TranslationSession) alive. The
        // framework cancels this task when the view or configuration changes.
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 60_000_000_000)
        }
        activeSession = nil
        configuration = nil
    }

    func reset() {
        timeoutTask?.cancel()
        timeoutTask = nil
        failWaiters(SystemTranslationError.preparationFailed("会话已重置。"))
        activeSession = nil
        configuration = nil
        isPreparing = false
    }

    private func acquireSession() async throws -> TranslationSession {
        if let activeSession { return activeSession }

        let availability = await LanguageAvailability().status(from: sourceLanguage, to: targetLanguage)
        if availability == .unsupported {
            throw SystemTranslationError.unavailable
        }

        isPreparing = true
        lastError = nil
        if configuration == nil {
            configuration = TranslationSession.Configuration(source: sourceLanguage, target: targetLanguage)
        }
        if timeoutTask == nil {
            timeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 240_000_000_000)
                guard !Task.isCancelled else { return }
                self?.failWaiters(SystemTranslationError.timedOut)
                self?.configuration = nil
                self?.isPreparing = false
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func failWaiters(_ error: Error) {
        timeoutTask?.cancel()
        timeoutTask = nil
        let pending = waiters
        waiters.removeAll()
        for waiter in pending { waiter.resume(throwing: error) }
    }
}

struct SystemTranslationHost: View {
    @ObservedObject var translator: SystemTranslator

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .translationTask(translator.configuration) { session in
                await translator.handle(session: session)
            }
    }
}
