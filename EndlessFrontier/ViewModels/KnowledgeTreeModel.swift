import Foundation
import SwiftUI

@MainActor
final class KnowledgeTreeModel: ObservableObject {
    let category: ArxivCategory
    private let settings: AppSettings
    private let store: KnowledgeTreeStore

    @Published private(set) var tree: KnowledgeTree?
    @Published private(set) var isGeneratingTree = false
    @Published private(set) var streamedCharacters = 0
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var stageText = "正在构建知识树"
    @Published private(set) var errorMessage: String?

    @Published private(set) var expandingNodeID: String?
    @Published private(set) var expansionStreamedCharacters = 0
    @Published private(set) var expansionError: String?
    @Published private(set) var expansionStageText = "正在深入展开知识点"

    @Published var selectedNodeID: String?

    private var generationTask: Task<Void, Never>?
    private var expansionTask: Task<Void, Never>?
    private var clockTask: Task<Void, Never>?
    private var startedAt: Date?
    private var activityToken: NSObjectProtocol?
    private var rawTreeCharacters = 0
    private var rawExpansionCharacters = 0
    private var lastTreeUIUpdate = Date.distantPast
    private var lastExpansionUIUpdate = Date.distantPast

    init(category: ArxivCategory, settings: AppSettings, store: KnowledgeTreeStore) {
        self.category = category
        self.settings = settings
        self.store = store
        self.tree = store.tree(for: category.id)
    }

    var hasTree: Bool { tree != nil }
    var canGenerate: Bool { settings.isConfigured }
    var isExpanding: Bool { expandingNodeID != nil }
    var canExpandSelectedNode: Bool {
        guard selectedNode != nil else { return false }
        return settings.isConfigured && !isGeneratingTree && !isExpanding
    }

    var selectedNode: KnowledgeTreeNode? {
        guard let selectedNodeID, let tree else { return nil }
        return tree.node(id: selectedNodeID)
    }

    var selectedPath: [KnowledgeTreeNode] {
        guard let selectedNodeID, let tree else { return [] }
        return tree.path(to: selectedNodeID)
    }

    var configurationMessage: String {
        settings.isConfigured ? "" : settings.configurationHint
    }

    var elapsedText: String {
        let total = Int(elapsed.rounded())
        let minutes = total / 60
        let seconds = total % 60
        return minutes > 0 ? String(format: "%d分%02d秒", minutes, seconds) : "\(seconds)秒"
    }

    func generateTree(force: Bool = false) {
        guard !isGeneratingTree, !isExpanding else { return }
        if tree != nil && !force { return }
        guard settings.isConfigured else {
            errorMessage = settings.configurationHint
            return
        }
        errorMessage = nil
        expansionError = nil
        isGeneratingTree = true
        rawTreeCharacters = 0
        streamedCharacters = 0
        lastTreeUIUpdate = .distantPast
        elapsed = 0
        stageText = "正在梳理学科的核心领域"
        startedAt = Date()
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Building a discipline knowledge tree"
        )
        startClock()

        let system = KnowledgeTreePrompt.treeSystem()
        let user = KnowledgeTreePrompt.treeUserPrompt(category: category)
        let model = settings.activeModel
        #if DEBUG
        NSLog("EndlessFrontier: generating knowledge tree for \(category.id) with \(model)")
        #endif

        generationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await LLMClient.shared.complete(
                    system: system,
                    user: user,
                    settings: settings,
                    maxTokens: 16_000,
                    stream: true,
                    effort: "medium",
                    onText: { [weak self] piece in
                        self?.receiveTreePiece(piece)
                    }
                )
                try Task.checkCancellation()
                var parsed = try KnowledgeTreePrompt.parseTree(response.text, category: category, model: model)
                parsed.generatedAt = Date()
                self.tree = parsed
                self.store.save(parsed)
                #if DEBUG
                NSLog("EndlessFrontier: knowledge tree saved with \(parsed.nodeCount) nodes")
                #endif
                self.selectedNodeID = nil
                self.finishTreeGenerationSuccessfully()
            } catch is CancellationError {
                self.finishTreeGenerationCancelled()
            } catch {
                #if DEBUG
                NSLog("EndlessFrontier: knowledge tree generation failed: \(error.localizedDescription)")
                #endif
                self.finishTreeGeneration(with: error)
            }
        }
    }

    func cancelTreeGeneration() {
        generationTask?.cancel()
        generationTask = nil
        if isGeneratingTree { finishTreeGenerationCancelled() }
    }

    func expand(nodeID: String) {
        guard let tree,
              let node = tree.node(id: nodeID),
              settings.isConfigured,
              !isGeneratingTree,
              expandingNodeID == nil else { return }
        expansionError = nil
        rawExpansionCharacters = 0
        expansionStreamedCharacters = 0
        lastExpansionUIUpdate = .distantPast
        expandingNodeID = nodeID
        selectedNodeID = nodeID
        expansionStageText = "正在深入展开「\(node.nameZH)」"
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Expanding a knowledge tree node"
        )

        let path = tree.path(to: nodeID)
        let system = KnowledgeTreePrompt.detailSystem()
        let user = KnowledgeTreePrompt.detailUserPrompt(category: category, path: path, node: node)
        let model = settings.activeModel

        expansionTask = Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await LLMClient.shared.complete(
                    system: system,
                    user: user,
                    settings: settings,
                    maxTokens: 8_000,
                    stream: true,
                    effort: "medium",
                    onText: { [weak self] piece in
                        self?.receiveExpansionPiece(piece)
                    }
                )
                try Task.checkCancellation()
                let detail = try KnowledgeTreePrompt.parseDetail(response.text, model: model)
                guard var current = self.tree, current.setDetail(detail, for: nodeID) else {
                    throw KnowledgeTreeGenerationError.incomplete("树中已找不到该知识点。")
                }
                self.tree = current
                self.store.save(current)
                self.finishExpansionSuccessfully()
            } catch is CancellationError {
                self.finishExpansionCancelled()
            } catch {
                #if DEBUG
                NSLog("EndlessFrontier: knowledge node expansion failed: \(error.localizedDescription)")
                #endif
                self.finishExpansion(with: error)
            }
        }
    }

    func cancelExpansion() {
        expansionTask?.cancel()
        expansionTask = nil
        if expandingNodeID != nil { finishExpansionCancelled() }
    }

    func selectNode(id: String?) {
        selectedNodeID = id
        expansionError = nil
    }

    private func receiveTreePiece(_ piece: String) {
        rawTreeCharacters += piece.count
        switch rawTreeCharacters {
        case ..<1_500: stageText = "正在梳理学科的核心领域"
        case ..<4_000: stageText = "正在展开主要知识分支"
        case ..<8_000: stageText = "正在检查双语节点与层级结构"
        default: stageText = "正在校验并保存知识树"
        }
        let now = Date()
        if now.timeIntervalSince(lastTreeUIUpdate) > 0.5 {
            lastTreeUIUpdate = now
            streamedCharacters = rawTreeCharacters
        }
    }

    private func receiveExpansionPiece(_ piece: String) {
        rawExpansionCharacters += piece.count
        switch rawExpansionCharacters {
        case ..<900: expansionStageText = "正在解释概念定义"
        case ..<2_400: expansionStageText = "正在梳理相关知识"
        default: expansionStageText = "正在整理人物与应用场景"
        }
        let now = Date()
        if now.timeIntervalSince(lastExpansionUIUpdate) > 0.6 {
            lastExpansionUIUpdate = now
            expansionStreamedCharacters = rawExpansionCharacters
        }
    }

    private func startClock() {
        clockTask?.cancel()
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard let self, self.isGeneratingTree, let startedAt = self.startedAt else { return }
                self.elapsed = Date().timeIntervalSince(startedAt)
            }
        }
    }

    private func endActivity() {
        if let activityToken {
            ProcessInfo.processInfo.endActivity(activityToken)
            self.activityToken = nil
        }
    }

    private func finishTreeGenerationSuccessfully() {
        endActivity()
        isGeneratingTree = false
        streamedCharacters = rawTreeCharacters
        elapsed = startedAt.map { Date().timeIntervalSince($0) } ?? elapsed
        clockTask?.cancel()
        clockTask = nil
        generationTask = nil
        startedAt = nil
    }

    private func finishTreeGenerationCancelled() {
        endActivity()
        isGeneratingTree = false
        rawTreeCharacters = 0
        streamedCharacters = 0
        stageText = "正在构建知识树"
        clockTask?.cancel()
        clockTask = nil
        generationTask = nil
        startedAt = nil
    }

    private func finishTreeGeneration(with error: Error) {
        endActivity()
        isGeneratingTree = false
        streamedCharacters = rawTreeCharacters
        errorMessage = error.localizedDescription
        clockTask?.cancel()
        clockTask = nil
        generationTask = nil
        startedAt = nil
    }

    private func finishExpansionSuccessfully() {
        endActivity()
        expandingNodeID = nil
        rawExpansionCharacters = 0
        expansionStreamedCharacters = 0
        expansionTask = nil
    }

    private func finishExpansionCancelled() {
        endActivity()
        expandingNodeID = nil
        rawExpansionCharacters = 0
        expansionStreamedCharacters = 0
        expansionTask = nil
    }

    private func finishExpansion(with error: Error) {
        endActivity()
        expansionError = error.localizedDescription
        expandingNodeID = nil
        rawExpansionCharacters = 0
        expansionStreamedCharacters = 0
        expansionTask = nil
    }
}

@MainActor
final class KnowledgeTreeCenter {
    private let settings: AppSettings
    private let store: KnowledgeTreeStore
    private var models: [String: KnowledgeTreeModel] = [:]

    init(settings: AppSettings, store: KnowledgeTreeStore) {
        self.settings = settings
        self.store = store
    }

    func model(for category: ArxivCategory) -> KnowledgeTreeModel {
        if let existing = models[category.id] { return existing }
        let model = KnowledgeTreeModel(category: category, settings: settings, store: store)
        models[category.id] = model
        return model
    }
}
