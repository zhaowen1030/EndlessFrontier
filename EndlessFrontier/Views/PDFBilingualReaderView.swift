import SwiftUI
import AppKit

struct PDFBilingualReaderView: View {
    @StateObject private var model: PDFReaderModel
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var translations: TranslationCache
    @Environment(\.openSettings) private var openSettings
    @State private var showBatchConfirmation = false
    @State private var batchPageCount = 0
    private let onClose: () -> Void

    init(record: DownloadedPaper, settings: AppSettings, onClose: @escaping () -> Void) {
        _model = StateObject(wrappedValue: PDFReaderModel(record: record, settings: settings))
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 0) {
            readerHeader
            HairlineDivider()
            if model.isLoading {
                loadingView
            } else if let error = model.errorMessage {
                errorView(error)
            } else {
                readerContent
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .navigationTitle("双语阅读")
        .navigationSubtitle("PDF Bilingual Reader")
        .onDisappear {
            model.cancelTranslation()
        }
        .confirmationDialog(
            "翻译全文",
            isPresented: $showBatchConfirmation,
            titleVisibility: .visible
        ) {
            Button("翻译剩余 \(batchPageCount) 页") {
                model.translateAllPages()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将按顺序逐页调用大模型翻译尚未完成的页面，已翻译页面会自动跳过。长论文可能需要较长时间并产生较多 API 费用，可随时取消；已完成的页面会保存在本机。")
        }
    }

    private var readerHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 9) {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("返回下载列表")

                VStack(alignment: .leading, spacing: 1) {
                    Text(model.record.paper.title)
                        .font(AppFont.display(17, weight: .semibold))
                        .lineLimit(1)
                    if let zh = translations.translation(for: model.record.paper.id)?.titleZH, !zh.isEmpty {
                        Text(zh)
                            .font(AppFont.chinese(10.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("PDF · \(model.record.paper.primaryCategory) · 本地双语阅读")
                            .font(AppFont.chinese(9.5))
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer(minLength: 8)
                translationControl
            }

            HStack(spacing: 8) {
                pageNavigation
                modePicker
                if model.displayMode != .original {
                    toggleButton(
                        symbol: model.showChinese ? "character.book.closed.fill" : "character.book.closed",
                        help: model.showChinese ? "隐藏中文 Hide Chinese" : "显示中文 Show Chinese",
                        active: model.showChinese
                    ) {
                        model.showChinese.toggle()
                    }
                }
                toggleButton(
                    symbol: "sidebar.right",
                    help: model.showsVocabulary ? "隐藏关键词汇" : "显示关键词汇",
                    active: model.showsVocabulary
                ) {
                    model.showsVocabulary.toggle()
                }
                Spacer(minLength: 4)
                translationStatus
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var pageNavigation: some View {
        HStack(spacing: 2) {
            Button(action: model.previousPage) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 9, weight: .semibold))
                    .frame(width: 23, height: 22)
            }
            .buttonStyle(.plain)
            .disabled(model.pageIndex == 0 || model.isNavigationLocked)
            .help("上一页")

            Text(model.pageLabel)
                .font(AppFont.mono(10, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(minWidth: 52)

            Button(action: model.nextPage) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .frame(width: 23, height: 22)
            }
            .buttonStyle(.plain)
            .disabled(model.pageIndex + 1 >= model.pageCount || model.isNavigationLocked)
            .help("下一页")
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private var modePicker: some View {
        Picker("", selection: $model.displayMode) {
            ForEach(PDFReaderDisplayMode.allCases) { mode in
                Label(mode.labelZH, systemImage: mode.symbol)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 208)
        .help("原文 / 双语 / 分屏")
    }

    private func toggleButton(
        symbol: String,
        help: String,
        active: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(active ? AppTheme.accent : .secondary)
                .frame(width: 24, height: 22)
                .background(
                    (active ? AppTheme.accent.opacity(0.10) : Color.primary.opacity(0.04)),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }

    @ViewBuilder
    private var translationControl: some View {
        if model.isLoading || model.errorMessage != nil {
            EmptyView()
        } else if model.isTranslating {
            HStack(spacing: 7) {
                ProgressView().controlSize(.mini)
                Text(translationProgressLabel)
                    .font(AppFont.chinese(10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                Button("取消") { model.cancelTranslation() }
                    .buttonStyle(.plain)
                    .font(AppFont.chinese(10))
                    .foregroundStyle(AppTheme.danger)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(AppTheme.accent.opacity(0.07), in: Capsule())
        } else if !settings.isConfigured {
            Button { openSettings() } label: {
                Label("配置模型", systemImage: "key.horizontal")
            }
            .buttonStyle(SecondaryActionButtonStyle())
        } else {
            HStack(spacing: 6) {
                if model.isTranslationComplete {
                    Label("本页已翻译", systemImage: "checkmark.circle.fill")
                        .font(AppFont.chinese(10.5, weight: .medium))
                        .foregroundStyle(AppTheme.positive)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(AppTheme.positive.opacity(0.08), in: Capsule())
                } else {
                    Button {
                        model.translateCurrentPage()
                    } label: {
                        Label("翻译本页", systemImage: "sparkles")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(!model.canTranslate)
                    .help("仅翻译当前页；完成后会缓存，不会重复调用模型")
                }

                Button {
                    let count = model.untranslatedPageCount()
                    if count > 0 {
                        batchPageCount = count
                        showBatchConfirmation = true
                    }
                } label: {
                    Label(
                        model.pendingPageCount > 0 ? "翻译全文" : "全文已翻译",
                        systemImage: model.pendingPageCount > 0 ? "text.book.closed" : "checkmark.circle"
                    )
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .disabled(!model.canTranslatePaper)
                .help("手动逐页翻译整篇论文；已翻译的页面会自动跳过")
            }
        }
    }

    private var translationProgressLabel: String {
        if model.isBatchTranslating, let progress = model.batchProgress {
            return "翻译全文 \(progress.completed)/\(progress.total)"
        }
        return "翻译中…"
    }

    private var batchTranslationMessage: String {
        if model.isBatchTranslating, let progress = model.batchProgress {
            return "已完成 \(progress.completed)/\(progress.total) 页。中文译文与关键词汇会逐页保存在本机，可随时取消并稍后继续。"
        }
        return "翻译完成后，英文段落下方会出现中文译文，并在右侧生成关键词汇释义。"
    }

    @ViewBuilder
    private var translationStatus: some View {
        if model.isLoading || model.errorMessage != nil {
            EmptyView()
        } else if model.isTranslating {
            Text(model.isBatchTranslating ? "正在逐页生成译文与关键词汇…" : "正在生成中文译文与关键词汇…")
                .font(AppFont.chinese(9.2))
                .foregroundStyle(.tertiary)
        } else if let translation = model.translation, model.isTranslationComplete {
            Text("\(translation.provider) · \(translation.model) · \(translation.translatedAt.shortChinese)")
                .font(AppFont.mono(8.5))
                .foregroundStyle(.quaternary)
        } else if !model.hasText {
            Text("本页没有可提取文字")
                .font(AppFont.chinese(9.2))
                .foregroundStyle(.tertiary)
        } else {
            Text("手动翻译本页 · 完成后自动保存在本机")
                .font(AppFont.chinese(9.2))
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var readerContent: some View {
        if model.showsVocabulary {
            HSplitView {
                readingArea
                    .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
                PDFVocabularySidebar(
                    entries: model.vocabulary,
                    isTranslated: model.isTranslationComplete,
                    isTranslating: model.isTranslating
                )
                .frame(minWidth: 220, idealWidth: 300, maxWidth: 480)
                .frame(maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            readingArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var readingArea: some View {
        switch model.displayMode {
        case .original:
            originalPane
        case .bilingual:
            textPane
        case .split:
            VSplitView {
                originalPane
                    .frame(minHeight: 190, idealHeight: 335)
                textPane
                    .frame(minHeight: 200)
            }
        }
    }

    private var originalPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                Label("PDF 原文", systemImage: "doc.richtext")
                    .font(AppFont.chinese(10, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("图表与公式保留原始排版")
                    .font(AppFont.chinese(9))
                    .foregroundStyle(.tertiary)
                Spacer()
                fitButton(mode: .automatic, symbol: "rectangle.arrowtriangle.2.outward", help: "整页适应")
                fitButton(mode: .width, symbol: "arrow.left.and.right", help: "适应宽度")
                fitButton(mode: .height, symbol: "arrow.up.and.down", help: "适应高度")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.thinMaterial)
            Divider()
            PDFPageDisplayView(
                url: model.pdfURL,
                pageIndex: model.pageIndex,
                fitMode: model.fitMode
            )
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private func fitButton(mode: PDFFitMode, symbol: String, help: String) -> some View {
        Button {
            if model.fitMode == mode, mode != .automatic {
                model.fitMode = .automatic
            } else {
                model.fitMode = mode
            }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(model.fitMode == mode ? AppTheme.accent : .secondary)
                .frame(width: 23, height: 20)
                .background(
                    model.fitMode == mode ? AppTheme.accent.opacity(0.10) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var textPane: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear.frame(height: 0).id("reader-page-top")
                    if !model.hasText {
                        emptyPageView
                    } else {
                        if let error = model.translationError {
                            ErrorBanner(
                                title: "本页翻译失败",
                                message: error,
                                actionTitle: settings.isConfigured ? "重试" : nil,
                                action: settings.isConfigured ? { model.translateCurrentPage() } : nil
                            )
                            .padding(.bottom, 12)
                        } else if !model.isTranslationComplete && !model.isTranslating {
                            untranslatedHint
                                .padding(.bottom, 12)
                        }
                        if model.isTranslating {
                            InfoBanner(
                                icon: "character.book.closed",
                                title: model.isBatchTranslating ? "正在翻译整篇论文" : "正在翻译本页",
                                message: batchTranslationMessage
                            )
                            .padding(.bottom, 12)
                        }

                        LazyVStack(alignment: .leading, spacing: 22) {
                            ForEach(Array(model.segments.enumerated()), id: \.offset) { index, source in
                                BilingualReadingLine(
                                    source: source,
                                    chinese: model.translation?.chinese(forSegmentIndex: index),
                                    showsTranslation: model.showChinese,
                                    pageIsTranslated: model.isTranslationComplete,
                                    vocabulary: model.vocabulary
                                )
                            }
                        }

                        if model.isTranslationComplete {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "internaldrive")
                                    .font(.system(size: 9))
                                Text("本页译文与关键词汇已保存在本机；切换到其他页后再返回，不会再次调用模型。图表与公式请查看原文或分屏。")
                                    .font(AppFont.chinese(9))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .foregroundStyle(.tertiary)
                            .padding(.top, 22)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .frame(maxWidth: 780, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: model.pageIndex) { _, _ in
                proxy.scrollTo("reader-page-top", anchor: .top)
            }
        }
    }

    private var untranslatedHint: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text("本页尚未翻译")
                    .font(AppFont.chinese(11, weight: .semibold))
                Text("论文正文翻译由你手动触发。点击顶部的「翻译本页」只处理当前页，或点击「翻译全文」逐页翻译整篇论文；模型会生成逐句中文译文与关键词汇释义，并自动保存在本机。")
                    .font(AppFont.chinese(9.8))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(11)
        .background(AppTheme.accent.opacity(0.05), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private var emptyPageView: some View {
        VStack(spacing: 9) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.tertiary)
            Text("这一页没有可提取的文字")
                .font(AppFont.chinese(13, weight: .semibold))
            Text("可能是插图页或扫描页。请切换到「原文」或「分屏」查看保留原版的图表、公式和版面。")
                .font(AppFont.chinese(10.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("正在载入论文与本地译文…")
                .font(AppFont.chinese(11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        EmptyState(
            icon: "doc.text.magnifyingglass",
            titleEN: "Could not open this PDF",
            titleZH: "无法打开论文",
            message: message,
            actionTitle: "返回下载列表",
            action: onClose
        )
    }
}

private struct BilingualReadingLine: View {
    let source: String
    let chinese: String?
    let showsTranslation: Bool
    let pageIsTranslated: Bool
    let vocabulary: [PaperVocabularyEntry]

    private var highlightedSource: AttributedString {
        var attributed = AttributedString(source)
        guard !vocabulary.isEmpty else { return attributed }
        let terms = vocabulary
            .map { $0.word.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted { $0.count > $1.count }
        let fullRange = NSRange(source.startIndex..., in: source)
        for term in terms {
            let escaped = NSRegularExpression.escapedPattern(for: term)
            let pattern = "(?<![\\p{L}\\p{N}])\(escaped)(?![\\p{L}\\p{N}])"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            for match in regex.matches(in: source, range: fullRange) {
                guard let stringRange = Range(match.range, in: source),
                      let attributeRange = Range(stringRange, in: attributed) else { continue }
                attributed[attributeRange].foregroundColor = AppTheme.accent
                attributed[attributeRange].backgroundColor = AppTheme.accent.opacity(0.13)
            }
        }
        return attributed
    }

    private var displayChinese: String {
        guard let chinese, !chinese.isEmpty else {
            return pageIsTranslated ? "（此句未返回译文）" : ""
        }
        return chinese
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(highlightedSource)
                .font(.system(size: 15.5, weight: .regular, design: .serif))
                .lineSpacing(5)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            if showsTranslation, pageIsTranslated {
                Text(displayChinese)
                    .font(AppFont.chinese(13.2))
                    .foregroundStyle(displayChinese.isEmpty ? Color.secondary.opacity(0.6) : Color.secondary)
                    .lineSpacing(4.5)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(AppTheme.accent.opacity(0.28))
                            .frame(width: 2)
                            .padding(.vertical, 2)
                    }
            }
        }
    }
}

private struct PDFVocabularySidebar: View {
    let entries: [PaperVocabularyEntry]
    let isTranslated: Bool
    let isTranslating: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                Text("关键词汇")
                    .font(AppFont.chinese(13, weight: .semibold))
                Text("KEY TERMS")
                    .font(.system(size: 7.5, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.tertiary)
                Spacer()
                if !entries.isEmpty {
                    Text("\(entries.count)")
                        .font(AppFont.mono(8.5))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            Divider()

            if isTranslating {
                VStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("正在整理本页关键词汇…")
                        .font(AppFont.chinese(10))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if entries.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: isTranslated ? "checkmark.circle" : "text.bubble")
                        .font(.system(size: 29, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text(isTranslated ? "本页没有返回关键词汇" : "翻译本页后")
                        .font(AppFont.chinese(11, weight: .medium))
                    Text(isTranslated ? "可切换页面继续阅读。" : "这里会显示本页 4–8 个重点词汇的音标、词性、中文释义和例句。")
                        .font(AppFont.chinese(9.5))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 240)
                }
                .padding(18)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 9) {
                        ForEach(entries) { entry in
                            PDFVocabularyCard(entry: entry)
                        }
                    }
                    .padding(11)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct PDFVocabularyCard: View {
    let entry: PaperVocabularyEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(entry.word)
                    .font(AppFont.display(13, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let phonetic = entry.phonetic {
                    Text(phonetic)
                        .font(AppFont.mono(8.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 2)
                if let partOfSpeech = entry.partOfSpeech {
                    Text(partOfSpeech)
                        .font(AppFont.mono(7.8, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1.5)
                        .background(Color.primary.opacity(0.05), in: Capsule())
                }
            }
            Text(entry.meaning)
                .font(AppFont.chinese(10.2))
                .foregroundStyle(.primary.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
            if let example = entry.example {
                VStack(alignment: .leading, spacing: 2) {
                    Text(example)
                        .font(.system(size: 9.3, design: .serif))
                        .foregroundStyle(.secondary)
                    if let zh = entry.exampleTranslation {
                        Text(zh)
                            .font(AppFont.chinese(9.1))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.top, 1)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}
