import Foundation
import PDFKit
import SwiftUI

enum PDFReaderDisplayMode: String, CaseIterable, Identifiable {
    case original
    case translated
    case bilingual
    case verticalSplit
    case horizontalSplit

    var id: String { rawValue }

    var labelZH: String {
        switch self {
        case .original: return "原文"
        case .translated: return "译文"
        case .bilingual: return "双语"
        case .verticalSplit: return "竖向分屏"
        case .horizontalSplit: return "横向分屏"
        }
    }

    var labelEN: String {
        switch self {
        case .original: return "Original"
        case .translated: return "Translated"
        case .bilingual: return "Bilingual"
        case .verticalSplit: return "Vertical Split"
        case .horizontalSplit: return "Horizontal Split"
        }
    }

    var symbol: String {
        switch self {
        case .original: return "doc.richtext"
        case .translated: return "doc.plaintext"
        case .bilingual: return "character.book.closed"
        case .verticalSplit: return "rectangle.split.1x2"
        case .horizontalSplit: return "rectangle.split.2x1"
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

struct PDFReaderParagraph: Identifiable, Hashable {
    let id: Int
    let source: String
    let chinese: String?
    let isMath: Bool
    let isHeading: Bool
}

struct PDFBilingualLinePair: Identifiable, Hashable {
    let id: String
    let blockID: Int
    let isFirstInBlock: Bool
    let english: String
    let chinese: String?
    let isMath: Bool
    let isHeading: Bool
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
    @Published private(set) var layoutBlocks: [PaperTextBlock] = []
    @Published private(set) var translation: PaperPageTranslation?
    @Published private(set) var translatedDocument: PDFDocument?
    @Published private(set) var isLoading = true
    @Published private(set) var isTranslating = false
    @Published private(set) var isBatchTranslating = false
    @Published private(set) var batchProgress: PDFBatchTranslationProgress?
    @Published private(set) var pendingPageCount = 0
    @Published private(set) var errorMessage: String?
    @Published private(set) var translationError: String?

    @Published var showChinese = true
    @Published var displayMode: PDFReaderDisplayMode = {
        #if DEBUG
        if DebugLaunchOptions.readerTranslatedMode { return .translated }
        if let raw = DebugLaunchOptions.readerMode {
            if raw == "split" { return .verticalSplit }
            if let mode = PDFReaderDisplayMode(rawValue: raw) { return mode }
        }
        #endif
        return .verticalSplit
    }()
    @Published var fitMode: PDFFitMode = .automatic
    @Published var showsVocabulary: Bool = {
        #if DEBUG
        return !DebugLaunchOptions.readerNoVocabulary
        #else
        return true
        #endif
    }()

    private var cache: PaperReadingDocument
    private var renderedPageCache: [Int: PDFDocument] = [:]
    private var cachedLinePairs: (page: Int, stamp: Date?, segmentCount: Int, pairs: [PDFBilingualLinePair])?
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

    var readerDocument: PDFDocument? { document }

    var pageLabel: String {
        "\(pageIndex + 1) / \(max(pageCount, 1))"
    }

    var hasText: Bool {
        layoutBlocks.contains { !$0.isMath } || !segments.isEmpty
    }

    var vocabulary: [PaperVocabularyEntry] { translation?.vocabulary ?? [] }

    var glossaryTerms: [PaperTerm] {
        (cache.glossary ?? [:])
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .prefix(40)
            .map { PaperTerm(source: $0.key, target: $0.value) }
    }

    var isLayoutComplete: Bool {
        translation?.isLayoutComplete ?? false
    }

    var hasLegacyTranslation: Bool {
        guard !isLayoutComplete, let translation, !translation.lines.isEmpty else { return false }
        return translation.isComplete(for: segments)
    }

    var isTranslationComplete: Bool { isLayoutComplete }

    var canTranslate: Bool {
        hasText && !isTranslating && !isLayoutComplete && settings.isConfigured
    }

    /// Paging is locked while a single page is being translated, but stays
    /// available during a whole-paper run so the reader can browse saved pages.
    var isNavigationLocked: Bool {
        isTranslating && !isBatchTranslating
    }

    var canTranslatePaper: Bool {
        pendingPageCount > 0 && !isTranslating && settings.isConfigured
    }

    var canExportTranslatedDocument: Bool {
        cache.pages.values.contains { $0.translation?.isLayoutComplete == true }
    }

    var displayParagraphs: [PDFReaderParagraph] {
        if let blocks = translation?.blocks, !blocks.isEmpty {
            return blocks.map {
                PDFReaderParagraph(
                    id: $0.id,
                    source: $0.source,
                    chinese: $0.chinese,
                    isMath: $0.isMath,
                    isHeading: $0.isHeading
                )
            }
        }
        // Untranslated pages have no stored layout blocks, but the extractor
        // already produced them for this page. Use the same block boundaries
        // as the translated view so paragraphs, headings and spacing do not
        // change when the page is translated.
        if translation == nil, !layoutBlocks.isEmpty {
            return layoutBlocks.map {
                PDFReaderParagraph(
                    id: $0.id,
                    source: $0.source,
                    chinese: nil,
                    isMath: $0.isMath,
                    isHeading: $0.isHeading
                )
            }
        }
        if !segments.isEmpty {
            return segments.enumerated().map { index, source in
                PDFReaderParagraph(
                    id: index + 1,
                    source: source,
                    chinese: translation?.chinese(forSegmentIndex: index),
                    isMath: false,
                    isHeading: false
                )
            }
        }
        return layoutBlocks.map {
            PDFReaderParagraph(
                id: $0.id,
                source: $0.source,
                chinese: nil,
                isMath: $0.isMath,
                isHeading: $0.isHeading
            )
        }
    }

    var displayLinePairs: [PDFBilingualLinePair] {
        let stamp = translation?.translatedAt
        if let cached = cachedLinePairs,
           cached.page == pageIndex,
           cached.stamp == stamp,
           cached.segmentCount == segments.count {
            return cached.pairs
        }
        let pairs = buildDisplayLinePairs()
        cachedLinePairs = (pageIndex, stamp, segments.count, pairs)
        return pairs
    }

    private func buildDisplayLinePairs() -> [PDFBilingualLinePair] {
        var result: [PDFBilingualLinePair] = []
        for paragraph in displayParagraphs {
            if paragraph.isMath {
                result.append(makePair(
                    block: paragraph,
                    index: 0,
                    english: paragraph.source,
                    chinese: nil
                ))
                continue
            }

            guard let chinese = paragraph.chinese, !chinese.isEmpty else {
                let lines = PDFSentenceSplitter.sentences(in: paragraph.source)
                for (index, sentence) in lines.enumerated() {
                    result.append(makePair(
                        block: paragraph,
                        index: index,
                        english: sentence,
                        chinese: nil
                    ))
                }
                continue
            }

            let pairs = PDFSentenceAligner.pairs(
                english: paragraph.source,
                chinese: chinese
            )
            for (index, pair) in pairs.enumerated() {
                result.append(makePair(
                    block: paragraph,
                    index: index,
                    english: pair.english,
                    chinese: pair.chinese
                ))
            }
        }
        return result
    }

    private func makePair(
        block: PDFReaderParagraph,
        index: Int,
        english: String,
        chinese: String?
    ) -> PDFBilingualLinePair {
        PDFBilingualLinePair(
            id: "\(block.id)-\(index)",
            blockID: block.id,
            isFirstInBlock: index == 0,
            english: english,
            chinese: chinese,
            isMath: block.isMath,
            isHeading: block.isHeading
        )
    }

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

    func translateCurrentPage(force: Bool = false) {
        guard !isTranslating else { return }
        guard settings.isConfigured else {
            translationError = settings.configurationHint
            return
        }
        guard force || !isLayoutComplete else { return }
        guard let page = document?.page(at: pageIndex) else { return }

        let targetPageIndex = pageIndex
        let targetBlocks = PDFLayoutExtractor.blocks(from: page)
        let targetSegments = PDFReadingText.segments(from: page)
        guard targetBlocks.contains(where: { !$0.isMath }) || !targetSegments.isEmpty else {
            translationError = PDFReadingError.noText.localizedDescription
            return
        }

        translationError = nil
        isTranslating = true
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Translating a paper page"
        )
        let title = record.paper.title
        let glossary = cache.glossary ?? [:]

        translationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result: PaperPageTranslation
                if targetBlocks.isEmpty {
                    result = try await PDFReadingTranslationService.translatePage(
                        paperTitle: title,
                        pageIndex: targetPageIndex,
                        totalPages: self.pageCount,
                        segments: targetSegments,
                        settings: self.settings
                    )
                } else {
                    result = try await PDFLayoutTranslationService.translatePage(
                        paperTitle: title,
                        pageIndex: targetPageIndex,
                        totalPages: self.pageCount,
                        blocks: targetBlocks,
                        glossary: glossary,
                        settings: self.settings
                    )
                }
                try Task.checkCancellation()
                self.storeTranslation(
                    result,
                    forPage: targetPageIndex,
                    blocks: targetBlocks,
                    segments: targetSegments
                )
                if self.pageIndex == targetPageIndex {
                    self.translation = result
                    self.layoutBlocks = targetBlocks
                    self.refreshTranslatedDocument()
                }
                self.endTranslation()
            } catch is CancellationError {
                self.endTranslation()
            } catch {
                self.endTranslation(error: error)
            }
        }
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
                    guard let page = self.document?.page(at: index) else { continue }
                    let blocks = PDFLayoutExtractor.blocks(from: page)
                    let pageSegments = PDFReadingText.segments(from: page)
                    guard blocks.contains(where: { !$0.isMath }) || !pageSegments.isEmpty else {
                        self.storeEmptyPage(index, segments: pageSegments)
                        self.batchProgress = PDFBatchTranslationProgress(
                            completed: offset + 1,
                            total: pending.count
                        )
                        continue
                    }
                    let result: PaperPageTranslation
                    if blocks.isEmpty {
                        result = try await PDFReadingTranslationService.translatePage(
                            paperTitle: title,
                            pageIndex: index,
                            totalPages: totalPages,
                            segments: pageSegments,
                            settings: self.settings
                        )
                    } else {
                        result = try await PDFLayoutTranslationService.translatePage(
                            paperTitle: title,
                            pageIndex: index,
                            totalPages: totalPages,
                            blocks: blocks,
                            glossary: self.cache.glossary ?? [:],
                            settings: self.settings
                        )
                    }
                    try Task.checkCancellation()
                    self.storeTranslation(result, forPage: index, blocks: blocks, segments: pageSegments)
                    if self.pageIndex == index {
                        self.translation = result
                        self.layoutBlocks = blocks
                        self.refreshTranslatedDocument()
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

    func makeExportDocument() -> PDFDocument? {
        var translations: [Int: [PaperTranslatedBlock]] = [:]
        for (key, stored) in cache.pages {
            guard let index = Int(key),
                  let blocks = stored.translation?.blocks,
                  stored.translation?.isLayoutComplete == true else { continue }
            translations[index] = blocks
        }
        guard let document else { return nil }
        return PDFTranslationRenderer.exportDocument(document: document, translations: translations)
    }

    func untranslatedPageCount() -> Int {
        untranslatedPageIndexes().count
    }

    private func untranslatedPageIndexes() -> [Int] {
        guard document != nil, pageCount > 0 else { return [] }
        var result: [Int] = []
        for index in 0..<pageCount {
            if let stored = cache.pages[String(index)] {
                if stored.translation?.isLayoutComplete == true { continue }
                if stored.segments.isEmpty, stored.translation == nil { continue }
                result.append(index)
            } else {
                result.append(index)
            }
        }
        return result
    }

    private func refreshPendingPageCount() {
        var settled = 0
        for index in 0..<pageCount {
            guard let stored = cache.pages[String(index)] else { continue }
            if stored.translation?.isLayoutComplete == true {
                settled += 1
            } else if stored.segments.isEmpty, stored.translation == nil {
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
        #if DEBUG
        let start = DebugLaunchOptions.readerPage.map { min(max($0, 0), count - 1) }
            ?? min(max(cache.lastPageIndex, 0), count - 1)
        #else
        let start = min(max(cache.lastPageIndex, 0), count - 1)
        #endif
        loadPage(start, persistLastPage: false)
        refreshPendingPageCount()
        isLoading = false
    }

    private func loadPage(_ index: Int, persistLastPage: Bool) {
        guard let document, let page = document.page(at: index) else { return }
        pageIndex = index
        translationError = nil
        layoutBlocks = PDFLayoutExtractor.blocks(from: page)

        if let stored = cache.pages[String(index)] {
            segments = stored.segments
            translation = stored.translation
        } else {
            segments = PDFReadingText.segments(from: page)
            translation = nil
            updateCachedPage(index, segments: segments, translation: nil)
        }

        refreshTranslatedDocument()

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

    private func storeEmptyPage(_ index: Int, segments: [String]) {
        cache.pages[String(index)] = StoredPaperPage(
            pageIndex: index,
            segments: segments,
            translation: nil
        )
        cache.updatedAt = Date()
        saveCache()
        refreshPendingPageCount()
    }

    private func storeTranslation(
        _ translation: PaperPageTranslation,
        forPage index: Int,
        blocks: [PaperTextBlock],
        segments: [String]
    ) {
        let storedSegments = blocks.isEmpty ? segments : blocks.map(\.source)
        cache.pages[String(index)] = StoredPaperPage(
            pageIndex: index,
            segments: storedSegments,
            translation: translation
        )
        mergeTerms(translation.terms)
        cache.updatedAt = Date()
        saveCache()
        renderedPageCache[index] = nil
        refreshPendingPageCount()
    }

    private func mergeTerms(_ terms: [PaperTerm]?) {
        guard let terms, !terms.isEmpty else { return }
        var glossary = cache.glossary ?? [:]
        for term in terms {
            glossary[term.source] = term.target
        }
        if glossary.count > 300 {
            glossary = Dictionary(uniqueKeysWithValues: glossary.sorted { $0.key < $1.key }.prefix(300).map { ($0.key, $0.value) })
        }
        cache.glossary = glossary
    }

    private func refreshTranslatedDocument() {
        guard let page = document?.page(at: pageIndex),
              let blocks = translation?.blocks,
              !blocks.isEmpty,
              isLayoutComplete else {
            translatedDocument = nil
            return
        }
        if let cached = renderedPageCache[pageIndex] {
            translatedDocument = cached
            return
        }
        if let rendered = PDFTranslationRenderer.renderedDocument(original: page, blocks: blocks) {
            renderedPageCache[pageIndex] = rendered
            translatedDocument = rendered
        } else {
            translatedDocument = nil
        }
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
