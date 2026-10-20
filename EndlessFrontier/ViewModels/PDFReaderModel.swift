import Foundation
import PDFKit
import SwiftUI

enum PDFReaderDisplayMode: String, CaseIterable, Identifiable {
    case original
    case bilingual
    case split

    var id: String { rawValue }

    var labelZH: String {
        switch self {
        case .original: return "原文"
        case .bilingual: return "双语"
        case .split: return "分屏"
        }
    }

    var labelEN: String {
        switch self {
        case .original: return "Original"
        case .bilingual: return "Bilingual"
        case .split: return "Split"
        }
    }

    var symbol: String {
        switch self {
        case .original: return "doc.richtext"
        case .bilingual: return "character.book.closed"
        case .split: return "rectangle.split.2x1"
        }
    }
}

struct PDFBatchTranslationProgress: Equatable {
    var completed: Int
    var total: Int
}

struct PDFPageTranslationFailure: LocalizedError {
    let pageIndex: Int
    let underlying: String

    var errorDescription: String? {
        "第 \(pageIndex + 1) 页翻译失败：\(underlying)"
    }
}

enum PDFFitMode: String, CaseIterable {
    case automatic
    case width
    case height

    var labelZH: String {
        switch self {
        case .automatic: return "整页"
        case .width: return "适应宽度"
        case .height: return "适应高度"
        }
    }
}

@MainActor
final class PDFReaderModel: ObservableObject {
    let record: DownloadedPaper
    let pdfURL: URL
    private let settings: AppSettings
    private var document: PDFDocument?

    @Published private(set) var pageCount: Int = 0
    @Published private(set) var pageIndex: Int = 0
    @Published private(set) var segments: [String] = []
    @Published private(set) var translation: PaperPageTranslation?
    @Published private(set) var isLoading = true
    @Published private(set) var isTranslating = false
    @Published private(set) var isBatchTranslating = false
    @Published private(set) var batchProgress: PDFBatchTranslationProgress?
    @Published private(set) var pendingPageCount = 0
    @Published private(set) var errorMessage: String?
    @Published private(set) var translationError: String?

    @Published var showChinese = true
    @Published var displayMode: PDFReaderDisplayMode = .split
    @Published var fitMode: PDFFitMode = .automatic
    @Published var showsVocabulary = true

    private var cache: PaperReadingDocument
    private var translationTask: Task<Void, Never>?
    private var activityToken: NSObjectProtocol?

    init(record: DownloadedPaper, settings: AppSettings) {
        self.record = record
        self.pdfURL = record.localURL
        self.settings = settings
        self.cache = PaperReadingDocument(
            paperID: record.paper.id,
            pdfPath: record.localPath,
            fingerprint: "",
            pages: [:],
            lastPageIndex: 0,
            updatedAt: Date()
        )
        load()
    }

    var pageLabel: String {
        "\(pageIndex + 1) / \(max(pageCount, 1))"
    }

    var hasText: Bool { !segments.isEmpty }
    var vocabulary: [PaperVocabularyEntry] { translation?.vocabulary ?? [] }

    var isTranslationComplete: Bool {
        translation?.isComplete(for: segments) ?? false
    }

    var canTranslate: Bool {
        hasText && !isTranslating && !isTranslationComplete && settings.isConfigured
    }

    /// Paging is locked while a single page is being translated, but stays
    /// available during a whole-paper run so the reader can browse saved pages.
    var isNavigationLocked: Bool {
        isTranslating && !isBatchTranslating
    }

    var modelLabel: String { settings.activeModel }

    func goToPage(_ index: Int) {
        guard !isNavigationLocked, pageCount > 0 else { return }
        let clamped = min(max(index, 0), pageCount - 1)
        guard clamped != pageIndex else { return }
        loadPage(clamped, persistLastPage: true)
    }

    func nextPage() {
        guard pageIndex + 1 < pageCount else { return }
        goToPage(pageIndex + 1)
    }

    func previousPage() {
        guard pageIndex > 0 else { return }
        goToPage(pageIndex - 1)
    }

    func translateCurrentPage() {
        guard !isTranslating, hasText else { return }
        guard settings.isConfigured else {
            translationError = settings.configurationHint
            return
        }
        guard !isTranslationComplete else { return }
        let targetPageIndex = pageIndex
        let targetSegments = segments
        translationError = nil
        isTranslating = true
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Translating a paper page"
        )
        let title = record.paper.title

        translationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await PDFReadingTranslationService.translatePage(
                    paperTitle: title,
                    pageIndex: targetPageIndex,
                    totalPages: self.pageCount,
                    segments: targetSegments,
                    settings: self.settings
                )
                try Task.checkCancellation()
                self.storeTranslation(
                    result,
                    forPage: targetPageIndex,
                    segments: targetSegments
                )
                if self.pageIndex == targetPageIndex {
                    self.translation = result
                }
                self.endTranslation()
            } catch is CancellationError {
                self.endTranslation()
            } catch {
                self.endTranslation(error: error)
            }
        }
    }

    var canTranslatePaper: Bool {
        pendingPageCount > 0 && !isTranslating && settings.isConfigured
    }

    func translateAllPages() {
        guard !isTranslating else { return }
        guard settings.isConfigured else {
            translationError = settings.configurationHint
            return
        }
        let pending = untranslatedPageIndexes()
        guard !pending.isEmpty else {
            pendingPageCount = 0
            return
        }

        let title = record.paper.title
        let totalPages = pageCount
        translationError = nil
        isTranslating = true
        isBatchTranslating = true
        batchProgress = PDFBatchTranslationProgress(completed: 0, total: pending.count)
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Translating a paper"
        )

        translationTask = Task { [weak self] in
            guard let self else { return }
            for (offset, index) in pending.enumerated() {
                if Task.isCancelled { break }
                do {
                    let pageSegments = self.segments(forPage: index)
                    guard !pageSegments.isEmpty else {
                        self.batchProgress = PDFBatchTranslationProgress(
                            completed: offset + 1,
                            total: pending.count
                        )
                        continue
                    }
                    let result = try await PDFReadingTranslationService.translatePage(
                        paperTitle: title,
                        pageIndex: index,
                        totalPages: totalPages,
                        segments: pageSegments,
                        settings: self.settings
                    )
                    try Task.checkCancellation()
                    self.storeTranslation(result, forPage: index, segments: pageSegments)
                    if self.pageIndex == index {
                        self.translation = result
                    }
                    self.batchProgress = PDFBatchTranslationProgress(
                        completed: offset + 1,
                        total: pending.count
                    )
                } catch is CancellationError {
                    self.endTranslation()
                    return
                } catch {
                    self.endTranslation(error: PDFPageTranslationFailure(
                        pageIndex: index,
                        underlying: error.localizedDescription
                    ))
                    return
                }
            }
            self.endTranslation()
        }
    }

    func cancelTranslation() {
        translationTask?.cancel()
        translationTask = nil
        endTranslation()
    }

    func untranslatedPageCount() -> Int {
        untranslatedPageIndexes().count
    }

    private func untranslatedPageIndexes() -> [Int] {
        guard document != nil, pageCount > 0 else { return [] }
        var result: [Int] = []
        for index in 0..<pageCount {
            if let stored = cache.pages[String(index)] {
                if stored.segments.isEmpty { continue }
                if stored.translation?.isComplete(for: stored.segments) == true { continue }
                result.append(index)
            } else {
                let pageSegments = segments(forPage: index)
                if pageSegments.isEmpty {
                    cacheEmptyPage(index)
                } else {
                    result.append(index)
                }
            }
        }
        return result
    }

    private func segments(forPage index: Int) -> [String] {
        if let stored = cache.pages[String(index)], !stored.segments.isEmpty {
            return stored.segments
        }
        guard let page = document?.page(at: index) else { return [] }
        return PDFReadingText.segments(from: page)
    }

    private func cacheEmptyPage(_ index: Int) {
        guard cache.pages[String(index)] == nil else { return }
        cache.pages[String(index)] = StoredPaperPage(
            pageIndex: index,
            segments: [],
            translation: nil
        )
        cache.updatedAt = Date()
        saveCache()
    }

    private func refreshPendingPageCount() {
        var settled = 0
        for index in 0..<pageCount {
            guard let stored = cache.pages[String(index)] else { continue }
            if stored.segments.isEmpty
                || stored.translation?.isComplete(for: stored.segments) == true {
                settled += 1
            }
        }
        pendingPageCount = max(pageCount - settled, 0)
    }

    private func load() {
        AppPaths.ensureDirectories()
        guard FileManager.default.fileExists(atPath: pdfURL.path) else {
            errorMessage = "本地 PDF 文件不存在，可能已被移动或删除。"
            isLoading = false
            return
        }
        guard let pdf = PDFDocument(url: pdfURL) else {
            errorMessage = PDFReadingError.cannotOpen.localizedDescription
            isLoading = false
            return
        }
        guard !pdf.isLocked else {
            errorMessage = PDFReadingError.locked.localizedDescription
            isLoading = false
            return
        }
        let count = pdf.pageCount
        guard count > 0 else {
            errorMessage = PDFReadingError.noText.localizedDescription
            isLoading = false
            return
        }
        document = pdf
        pageCount = count
        loadCacheDocument()
        let start = min(max(cache.lastPageIndex, 0), count - 1)
        loadPage(start, persistLastPage: false)
        refreshPendingPageCount()
        isLoading = false
    }

    private func loadPage(_ index: Int, persistLastPage: Bool) {
        guard let document, let page = document.page(at: index) else { return }
        pageIndex = index
        translationError = nil

        if let stored = cache.pages[String(index)] {
            segments = stored.segments
            translation = stored.translation
            if segments.isEmpty {
                segments = PDFReadingText.segments(from: page)
                updateCachedPage(index, segments: segments, translation: stored.translation)
            }
        } else {
            segments = PDFReadingText.segments(from: page)
            updateCachedPage(index, segments: segments, translation: nil)
        }
        if persistLastPage {
            cache.lastPageIndex = index
            cache.updatedAt = Date()
            saveCache()
        }
    }

    private func updateCachedPage(
        _ index: Int,
        segments: [String],
        translation: PaperPageTranslation?
    ) {
        cache.pages[String(index)] = StoredPaperPage(
            pageIndex: index,
            segments: segments,
            translation: translation
        )
        cache.updatedAt = Date()
        cache.lastPageIndex = index
        saveCache()
        refreshPendingPageCount()
    }

    private func storeTranslation(
        _ translation: PaperPageTranslation,
        forPage index: Int,
        segments: [String]
    ) {
        cache.pages[String(index)] = StoredPaperPage(
            pageIndex: index,
            segments: segments,
            translation: translation
        )
        cache.updatedAt = Date()
        saveCache()
        refreshPendingPageCount()
    }

    private func endTranslation(error: Error? = nil) {
        if let activityToken {
            ProcessInfo.processInfo.endActivity(activityToken)
            self.activityToken = nil
        }
        isTranslating = false
        isBatchTranslating = false
        batchProgress = nil
        translationTask = nil
        refreshPendingPageCount()
        if let error {
            translationError = error.localizedDescription
        }
    }

    private func loadCacheDocument() {
        let fingerprint = fileFingerprint()
        let url = AppPaths.readerFileURL(paperID: record.paper.id)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: url),
           let decoded = try? decoder.decode(PaperReadingDocument.self, from: data),
           decoded.paperID == record.paper.id,
           decoded.pdfPath == record.localPath,
           decoded.fingerprint == fingerprint {
            cache = decoded
        } else {
            cache = PaperReadingDocument(
                paperID: record.paper.id,
                pdfPath: record.localPath,
                fingerprint: fingerprint,
                pages: [:],
                lastPageIndex: 0,
                updatedAt: Date()
            )
            saveCache()
        }
    }

    private func saveCache() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(cache)
            try AppPaths.writeAtomically(data, to: AppPaths.readerFileURL(paperID: record.paper.id))
        } catch {
            NSLog("EndlessFrontier: failed to save PDF reading data: \(error)")
        }
    }

    private func fileFingerprint() -> String {
        let attributes = try? FileManager.default.attributesOfItem(atPath: pdfURL.path)
        let size = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        let modified = (attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        return "\(size)-\(Int(modified))"
    }
}
