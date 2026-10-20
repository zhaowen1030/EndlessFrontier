import Foundation
import SwiftUI

@MainActor
final class CategoryFeedModel: ObservableObject {
    let category: ArxivCategory
    private let services: AppServices

    @Published private(set) var papers: [Paper] = []
    @Published private(set) var translations: [String: PaperTranslation] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var isTranslating = false
    @Published private(set) var individuallyTranslating: Set<String> = []
    @Published private(set) var individualTranslationErrors: [String: String] = [:]
    @Published private(set) var totalResults = 0
    @Published private(set) var hasMore = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var translationNotice: String?
    @Published private(set) var translationProgress: (done: Int, total: Int)?
    @Published private(set) var sort: ArxivSort = .newest
    @Published private(set) var query = ""
    @Published private(set) var hasLoadedOnce = false

    private var loadTask: Task<Void, Never>?
    private var loadMoreTask: Task<Void, Never>?
    private var translationTask: Task<Void, Never>?
    private var individualTranslationTasks: [String: Task<Void, Never>] = [:]

    init(category: ArxivCategory, services: AppServices) {
        self.category = category
        self.services = services
    }

    var translatedCount: Int {
        papers.reduce(0) { count, paper in
            count + (translations[paper.id] == nil ? 0 : 1)
        }
    }

    var untranslatedCount: Int {
        max(0, papers.count - translatedCount)
    }

    var canTranslate: Bool {
        services.settings.translationMode != .off && !isLoading
    }

    var displayCountTextZH: String {
        if totalResults > 0 {
            return "该分类共 \(Self.formatted(totalResults)) 篇论文"
        }
        return "arXiv 论文"
    }

    var displayCountBilingual: String {
        if totalResults > 0 {
            let count = Self.formatted(totalResults)
            return "\(count) 篇论文 · \(count) papers"
        }
        return "arXiv 学科分类 · arXiv discipline"
    }

    var translationSummary: String? {
        guard isTranslating, let progress = translationProgress else { return nil }
        return "翻译中 \(progress.done)/\(progress.total)"
    }

    func loadIfNeeded() {
        guard !hasLoadedOnce, !isLoading else { return }
        reload()
    }

    func reload() {
        loadTask?.cancel()
        loadMoreTask?.cancel()
        translationTask?.cancel()
        isLoading = true
        isLoadingMore = false
        errorMessage = nil
        translationNotice = nil
        translationProgress = nil
        isTranslating = false
        individualTranslationErrors = [:]

        let query = query
        let sort = sort
        let count = services.settings.pageSize

        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let page = try await ArxivService.shared.fetchPage(
                    category: category.id,
                    query: query,
                    sort: sort,
                    start: 0,
                    count: count
                )
                try Task.checkCancellation()
                self.papers = page.papers
                self.totalResults = page.totalResults
                self.hasMore = page.papers.count < page.totalResults && !page.papers.isEmpty
                self.translations = self.services.translations.translations(for: page.papers.map(\.id))
                self.hasLoadedOnce = true
                self.isLoading = false
                self.services.downloads.restoreDownloadedStates(for: page.papers)
                self.startTranslationsIfNeeded()
            } catch is CancellationError {
                // A newer request superseded this one.
            } catch {
                self.isLoading = false
                self.hasLoadedOnce = true
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func loadMore() {
        guard hasMore, !isLoading, !isLoadingMore, loadMoreTask == nil else { return }
        isLoadingMore = true
        errorMessage = nil
        let start = papers.count
        let query = query
        let sort = sort
        let count = services.settings.pageSize

        loadMoreTask = Task { [weak self] in
            guard let self else { return }
            defer { self.isLoadingMore = false; self.loadMoreTask = nil }
            do {
                let page = try await ArxivService.shared.fetchPage(
                    category: category.id,
                    query: query,
                    sort: sort,
                    start: start,
                    count: count
                )
                try Task.checkCancellation()
                let existing = Set(self.papers.map(\.id))
                let fresh = page.papers.filter { !existing.contains($0.id) }
                self.papers.append(contentsOf: fresh)
                self.errorMessage = nil
                self.totalResults = max(page.totalResults, self.papers.count)
                self.hasMore = !page.papers.isEmpty && self.papers.count < page.totalResults
                let newTranslations = self.services.translations.translations(for: fresh.map(\.id))
                self.translations.merge(newTranslations) { current, _ in current }
                self.services.downloads.restoreDownloadedStates(for: fresh)
                self.startTranslationsIfNeeded()
            } catch is CancellationError {
                // Ignore stale pagination.
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func changeSort(_ newSort: ArxivSort) {
        guard newSort != sort else { return }
        sort = newSort
        clearResultsForNewQuery()
        reload()
    }

    func applySearch(_ text: String) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned != query else { return }
        query = cleaned
        clearResultsForNewQuery()
        reload()
    }

    func clearSearch() {
        guard !query.isEmpty else { return }
        query = ""
        clearResultsForNewQuery()
        reload()
    }

    private func clearResultsForNewQuery() {
        papers = []
        translations = [:]
        totalResults = 0
        hasMore = false
        hasLoadedOnce = false
    }

    func translateAll() {
        translationNotice = nil
        startTranslations(forceAllMissing: true)
    }

    /// Translate one paper on demand from its card. This uses the same engine
    /// and cache as page-wide translation, and is ignored while that paper is
    /// already translated or a page-wide pass is running.
    func translate(paper: Paper) {
        guard services.settings.translationMode != .off else { return }
        guard !isLoading, !isTranslating else { return }
        guard translations[paper.id] == nil else { return }
        guard individualTranslationTasks[paper.id] == nil else { return }

        translationNotice = nil
        individualTranslationErrors[paper.id] = nil
        individuallyTranslating.insert(paper.id)

        let task = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.services.translationService.translate(
                    papers: [paper],
                    category: self.category,
                    onBatch: { [weak self] batch in
                        self?.mergeTranslations(batch)
                    },
                    onProgress: { _, _ in }
                )
                if self.translations[paper.id] == nil,
                   let cached = self.services.translations.translation(for: paper.id) {
                    self.mergeTranslations([cached])
                }
            } catch is CancellationError {
                // No user-visible error: this task is only cancelled with the view.
            } catch {
                self.individualTranslationErrors[paper.id] = error.localizedDescription
                self.translationNotice = "《\(ScienceText.display(paper.title))》翻译失败：\(error.localizedDescription)"
            }
            self.individuallyTranslating.remove(paper.id)
            self.individualTranslationTasks[paper.id] = nil
        }
        individualTranslationTasks[paper.id] = task
    }

    private func mergeTranslations(_ batch: [PaperTranslation]) {
        for translation in batch {
            translations[translation.arxivID] = translation
            individualTranslationErrors[translation.arxivID] = nil
        }
    }

    func retryFailedTranslations() {
        translateAll()
    }

    func stopWork() {
        loadTask?.cancel()
        loadMoreTask?.cancel()
        translationTask?.cancel()
        loadTask = nil
        loadMoreTask = nil
        translationTask = nil
        isTranslating = false
        isLoading = false
        isLoadingMore = false
    }

    private func startTranslationsIfNeeded() {
        #if DEBUG
        if DebugLaunchOptions.suppressAutoTranslation { return }
        #endif
        guard services.settings.autoTranslate else { return }
        guard services.settings.translationMode != .off else { return }
        guard !papers.isEmpty else { return }
        guard untranslatedCount > 0 else { return }
        startTranslations(forceAllMissing: false)
    }

    private func startTranslations(forceAllMissing: Bool) {
        guard !isTranslating else { return }
        translationTask?.cancel()
        translationNotice = nil
        let missing = papers.filter {
            translations[$0.id] == nil && !individuallyTranslating.contains($0.id)
        }
        guard !missing.isEmpty else {
            translationProgress = (papers.count, papers.count)
            return
        }
        isTranslating = true
        translationProgress = (0, missing.count)

        translationTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.services.translationService.translate(
                    papers: missing,
                    category: self.category,
                    onBatch: { [weak self] batch in
                        self?.mergeTranslations(batch)
                    },
                    onProgress: { [weak self] done, total in
                        self?.translationProgress = (done, total)
                    }
                )
                self.isTranslating = false
                if self.untranslatedCount > 0, forceAllMissing {
                    self.translationNotice = "部分论文未能翻译，请重试。"
                }
            } catch is CancellationError {
                self.isTranslating = false
            } catch {
                self.isTranslating = false
                self.translationNotice = "中文翻译未完成：\(error.localizedDescription)"
            }
            self.translationTask = nil
        }
    }

    private static func formatted(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
