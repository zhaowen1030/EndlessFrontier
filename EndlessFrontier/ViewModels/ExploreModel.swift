import Foundation
import SwiftUI

@MainActor
final class ExploreModel: ObservableObject {
    let category: ArxivCategory
    private let settings: AppSettings
    private let reports: ReportStore

    @Published private(set) var report: AIReport?
    @Published private(set) var isGenerating = false
    @Published private(set) var streamedCharacters = 0
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var stageText = "正在构建学科全景"
    @Published private(set) var stageDetail = "Preparing the research map"
    @Published private(set) var errorMessage: String?

    private var generationTask: Task<Void, Never>?
    private var clockTask: Task<Void, Never>?
    private var rawCharacterCount = 0
    private var rawResponse = ""
    private var lastLoggedChunk = 0
    private var lastUIUpdate = Date.distantPast
    private var startedAt: Date?
    private var activityToken: NSObjectProtocol?

    init(category: ArxivCategory, settings: AppSettings, reports: ReportStore) {
        self.category = category
        self.settings = settings
        self.reports = reports
        self.report = reports.report(for: category.id)
    }

    var hasReport: Bool { report != nil }
    var canGenerate: Bool { settings.isConfigured }

    var configurationMessage: String {
        settings.isConfigured ? "" : settings.configurationHint
    }

    var elapsedText: String {
        let total = Int(elapsed.rounded())
        let minutes = total / 60
        let seconds = total % 60
        return minutes > 0 ? String(format: "%d分%02d秒", minutes, seconds) : "\(seconds)秒"
    }

    var progressFraction: Double {
        // This is an intentional estimate, not a token-exact progress bar.
        if !isGenerating && report != nil { return 1 }
        return min(0.94, Double(streamedCharacters) / 16_000.0)
    }

    func generate(force: Bool = false) {
        guard !isGenerating else { return }
        if report != nil && !force { return }
        guard canGenerate else {
            errorMessage = settings.configurationHint
            return
        }
        errorMessage = nil

        isGenerating = true
        streamedCharacters = 0
        rawCharacterCount = 0
        elapsed = 0
        stageText = "正在梳理学科的历史脉络"
        stageDetail = "Mapping the intellectual history"
        startedAt = Date()
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Generating an AI research report"
        )
        startClock()

        let system = ReportPrompt.systemPrompt()
        let user = ReportPrompt.userPrompt(category: category)
        let model = settings.activeModel

        generationTask = Task { [weak self] in
            guard let self else { return }
            do {
                NSLog("EndlessFrontier: generating AI report for \(category.id) with \(model)")
                let response = try await LLMClient.shared.complete(
                    system: system,
                    user: user,
                    settings: settings,
                    maxTokens: 30_000,
                    stream: true,
                    effort: "medium",
                    onText: { [weak self] piece in
                        self?.rawResponse += piece
                        self?.receive(piece)
                    }
                )
                NSLog("EndlessFrontier: AI report response received (\(response.text.count) chars, stop=\(response.stopReason ?? "nil"))")
                try Task.checkCancellation()
                var parsed = try ReportPrompt.parse(response.text, category: category, model: model)
                parsed.generatedAt = Date()
                self.report = parsed
                self.reports.save(parsed)
                self.finishSuccessfully()
            } catch is CancellationError {
                self.finishCancelled()
            } catch {
                self.finish(with: error)
            }
        }
    }

    func cancel() {
        generationTask?.cancel()
        generationTask = nil
        finishCancelled()
    }

    private func receive(_ piece: String) {
        rawCharacterCount += piece.count
        if rawCharacterCount - lastLoggedChunk >= 8_000 {
            lastLoggedChunk = rawCharacterCount
            NSLog("EndlessFrontier: AI report streamed \(rawCharacterCount) chars")
        }
        let now = Date()
        if now.timeIntervalSince(lastUIUpdate) > 0.45 {
            lastUIUpdate = now
            streamedCharacters = rawCharacterCount
        }
        updateStage(for: rawCharacterCount)
    }

    private func updateStage(for count: Int) {
        let next: (String, String)
        switch count {
        case ..<1_400:
            next = ("正在梳理学科的历史脉络", "Mapping the intellectual history")
        case ..<4_000:
            next = ("正在辨识未解难题与前沿方向", "Locating open problems and frontiers")
        case ..<7_000:
            next = ("正在整理关键成果与人物", "Tracing landmark results and figures")
        case ..<10_500:
            next = ("正在建立交叉关系与术语体系", "Building cross-disciplinary links")
        default:
            next = ("正在校验公式并生成双语报告", "Validating equations and Chinese text")
        }
        if stageText != next.0 {
            stageText = next.0
            stageDetail = next.1
        }
    }

    private func startClock() {
        clockTask?.cancel()
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard let self, self.isGenerating, let startedAt = self.startedAt else { return }
                self.elapsed = Date().timeIntervalSince(startedAt)
            }
        }
    }

    private func finishSuccessfully() {
        endActivity()
        streamedCharacters = rawCharacterCount
        stageText = "报告已生成"
        stageDetail = "Research map complete"
        isGenerating = false
        elapsed = startedAt.map { Date().timeIntervalSince($0) } ?? elapsed
        clockTask?.cancel()
        clockTask = nil
        generationTask = nil
        startedAt = nil
        rawResponse = ""
    }

    private func finishCancelled() {
        endActivity()
        isGenerating = false
        streamedCharacters = 0
        stageText = "正在构建学科全景"
        stageDetail = "Preparing the research map"
        clockTask?.cancel()
        clockTask = nil
        generationTask = nil
        startedAt = nil
        rawResponse = ""
    }

    private func finish(with error: Error) {
        if error is CancellationError {
            finishCancelled()
            return
        }
        endActivity()
        errorMessage = error.localizedDescription
        isGenerating = false
        clockTask?.cancel()
        clockTask = nil
        generationTask = nil
        startedAt = nil
        persistDiagnostic(error: error)
        rawResponse = ""
    }

    private func endActivity() {
        if let activityToken {
            ProcessInfo.processInfo.endActivity(activityToken)
            self.activityToken = nil
        }
    }

    private func persistDiagnostic(error: Error) {
        let text = """
        Category: \(category.id)
        Model: \(settings.activeModel)
        Error: \(error.localizedDescription)
        Raw characters: \(rawCharacterCount)
        Generated at: \(Date())

        === RAW RESPONSE ===
        \(rawResponse)
        """
        let url = AppPaths.logsDirectory.appendingPathComponent("last-generation-error.txt")
        do {
            _ = try AppPaths.writeAtomically(Data(text.utf8), to: url)
        } catch {
            NSLog("EndlessFrontier: failed to write diagnostic: \(error)")
        }
    }
}
