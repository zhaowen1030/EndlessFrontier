import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct PDFBilingualReaderView: View {
    @StateObject private var model: PDFReaderModel
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var translations: TranslationCache
    @Environment(\.openSettings) private var openSettings
    @State private var showBatchConfirmation = false
    @State private var batchPageCount = 0
    @State private var didDemoTranslate = false
    @State private var didDemoExport = false
    @State private var vocabularyWidth: CGFloat = 300
    @State private var vocabularyDragStart: CGFloat?
    @State private var isAdjustingVocabulary = false
    @State private var isTogglingVocabulary = false
    @State private var splitTopHeight: CGFloat = 330
    @State private var splitDragStart: CGFloat?
    @State private var isAdjustingSplit = false
    @State private var horizontalLeftWidth: CGFloat = 620
    @State private var horizontalDragStartWidth: CGFloat?
    @State private var isAdjustingHorizontalSplit = false
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
        .onAppear {
            #if DEBUG
            if DebugLaunchOptions.readerTranslatedMode {
                model.displayMode = .translated
            }
            if DebugLaunchOptions.translateReader {
                model.displayMode = .translated
                guard !didDemoTranslate else { return }
                didDemoTranslate = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    model.translateCurrentPage(force: true)
                }
            }
            if let path = DebugLaunchOptions.exportTranslatedPath, !didDemoExport {
                didDemoExport = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    if let document = model.makeExportDocument() {
                        document.write(to: URL(fileURLWithPath: path))
                    }
                }
            }
            #endif
        }
        .onChange(of: model.isLayoutComplete) { _, complete in
            #if DEBUG
            if complete, DebugLaunchOptions.translateReader {
                model.displayMode = .translated
            }
            #endif
        }
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
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                Spacer(minLength: 12)
                translationControl
            }

            HStack(spacing: 12) {
                pageNavigation
                modePicker
                displayToggles
                Spacer(minLength: 16)
                translationStatus
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var displayToggles: some View {
        HStack(spacing: 2) {
            if model.displayMode != .original && model.displayMode != .translated {
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
                toggleVocabulary()
            }
        }
        .padding(2)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func toggleVocabulary() {
        // Freeze PDFKit while the pane snaps to its new width, then refit once.
        isTogglingVocabulary = true
        model.showsVocabulary.toggle()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isTogglingVocabulary = false
        }
    }

    private var pageNavigation: some View {
        HStack(spacing: 3) {
            Button(action: model.previousPage) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 9.5, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(model.pageIndex == 0 || model.isNavigationLocked)
            .help("上一页")

            Text(model.pageLabel)
                .font(AppFont.mono(10, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(minWidth: 54)

            Button(action: model.nextPage) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9.5, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(model.pageIndex + 1 >= model.pageCount || model.isNavigationLocked)
            .help("下一页")
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
        .frame(width: 350)
        .help("原文 / 译文 / 双语 / 竖向分屏（上下） / 横向分屏（左右）")
    }

    private func toggleButton(
        symbol: String,
        help: String,
        active: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(active ? AppTheme.accent : .secondary)
                .frame(width: 26, height: 24)
                .background(
                    active ? AppTheme.accent.opacity(0.12) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    @ViewBuilder
    private var translationControl: some View {
        if model.isLoading || model.errorMessage != nil {
            EmptyView()
        } else if model.isTranslating {
            HStack(spacing: 8) {
                ProgressView().controlSize(.mini)
                Text(translationProgressLabel)
                    .font(AppFont.chinese(10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                Button("取消") { model.cancelTranslation() }
                    .buttonStyle(.plain)
                    .font(AppFont.chinese(10))
                    .foregroundStyle(AppTheme.danger)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(AppTheme.accent.opacity(0.07), in: Capsule())
        } else if !settings.isConfigured {
            Button { openSettings() } label: {
                Label("配置模型", systemImage: "key.horizontal")
            }
            .buttonStyle(SecondaryActionButtonStyle())
        } else {
            HStack(spacing: 8) {
                if model.isTranslationComplete {
                    Label("本页已翻译", systemImage: "checkmark.circle.fill")
                        .font(AppFont.chinese(10.5, weight: .medium))
                        .foregroundStyle(AppTheme.positive)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(AppTheme.positive.opacity(0.08), in: Capsule())
                } else {
                    Button {
                        model.translateCurrentPage(force: model.hasLegacyTranslation)
                    } label: {
                        Label(model.hasLegacyTranslation ? "重新翻译" : "翻译本页", systemImage: "sparkles")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(!model.canTranslate)
                    .help(model.hasLegacyTranslation
                          ? "旧版逐句译文不含版式；重新翻译可生成保留原始版面的译文"
                          : "仅翻译当前页；完成后会缓存，不会重复调用模型")
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
        return "翻译完成后，双语模式会按英文一句、中文一句交替显示，并在右侧生成术语与关键词汇。"
    }

    @ViewBuilder
    private var translationStatus: some View {
        if model.isLoading || model.errorMessage != nil {
            EmptyView()
        } else if model.isTranslating {
            Text(model.isBatchTranslating ? "正在逐页生成译文与关键词汇…" : "正在生成中文译文与关键词汇…")
                .font(AppFont.chinese(9.2))
                .foregroundStyle(.tertiary)
        } else if model.hasLegacyTranslation {
            Text("旧版逐句译文 · 重新翻译可生成保留版式的译文")
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

    private var isResizingPDF: Bool {
        isAdjustingVocabulary || isAdjustingSplit
            || isAdjustingHorizontalSplit || isTogglingVocabulary
    }

    private var readerContent: some View {
        // Keep the hierarchy stable while toggling the sidebar or switching
        // modes. A conditional HSplitView recreated the PDF hosting views and
        // reset the sidebar width, which caused flashing and layout shifts.
        HStack(spacing: 0) {
            readingArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            vocabularyDivider
                .frame(width: model.showsVocabulary ? 8 : 0)
                .opacity(model.showsVocabulary ? 1 : 0)
                .allowsHitTesting(model.showsVocabulary)

            PDFVocabularySidebar(
                entries: model.vocabulary,
                terms: model.glossaryTerms,
                isTranslated: model.isLayoutComplete,
                isTranslating: model.isTranslating
            )
            .frame(width: model.showsVocabulary ? vocabularyWidth : 0)
            .frame(maxHeight: .infinity)
            .opacity(model.showsVocabulary ? 1 : 0)
            .clipped()
            .allowsHitTesting(model.showsVocabulary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var vocabularyDivider: some View {
        ZStack {
            Color.primary.opacity(0.10)
                .frame(width: 1)
            Color.clear
                .contentShape(Rectangle())
        }
        .frame(width: 8)
        .frame(maxHeight: .infinity)
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    isAdjustingVocabulary = true
                    if vocabularyDragStart == nil {
                        vocabularyDragStart = vocabularyWidth
                    }
                    let start = vocabularyDragStart ?? vocabularyWidth
                    vocabularyWidth = min(max(start - value.translation.width, 220), 520)
                }
                .onEnded { _ in
                    vocabularyDragStart = nil
                    isAdjustingVocabulary = false
                }
        )
        .onHover { hovering in
            if hovering {
                NSCursor.resizeLeftRight.set()
            } else {
                NSCursor.arrow.set()
            }
        }
        .help("拖动调整关键词汇栏宽度")
    }

    @ViewBuilder
    private var readingArea: some View {
        switch model.displayMode {
        case .original:
            originalPane
        case .translated:
            translatedPane
        case .bilingual:
            textPane
        case .verticalSplit:
            GeometryReader { geometry in
                let topHeight = clampedSplitHeight(for: geometry.size.height)
                VStack(spacing: 0) {
                    originalPane
                        .frame(height: topHeight)
                    splitDivider
                    textPane
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        case .horizontalSplit:
            GeometryReader { geometry in
                let leftWidth = clampedHorizontalWidth(for: geometry.size.width)
                HStack(spacing: 0) {
                    originalPane
                        .frame(width: leftWidth)
                    horizontalSplitDivider(totalWidth: geometry.size.width)
                    textPane
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private func clampedHorizontalWidth(for total: CGFloat) -> CGFloat {
        let minimumLeft: CGFloat = 360
        let minimumRight: CGFloat = 320
        guard total > minimumLeft + minimumRight + 8 else {
            return max(0, total * 0.5)
        }
        return min(max(horizontalLeftWidth, minimumLeft), total - minimumRight - 8)
    }

    private func horizontalSplitDivider(totalWidth: CGFloat) -> some View {
        ZStack {
            Color.primary.opacity(0.10)
                .frame(width: 1)
            Color.clear
                .contentShape(Rectangle())
        }
        .frame(width: 8)
        .frame(maxHeight: .infinity)
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    isAdjustingHorizontalSplit = true
                    if horizontalDragStartWidth == nil {
                        horizontalDragStartWidth = clampedHorizontalWidth(for: totalWidth)
                    }
                    let start = horizontalDragStartWidth ?? horizontalLeftWidth
                    let maximum = max(360, totalWidth - 320 - 8)
                    horizontalLeftWidth = min(max(start + value.translation.width, 360), maximum)
                }
                .onEnded { _ in
                    horizontalDragStartWidth = nil
                    isAdjustingHorizontalSplit = false
                }
        )
        .onHover { hovering in
            if hovering {
                NSCursor.resizeLeftRight.set()
            } else {
                NSCursor.arrow.set()
            }
        }
        .help("拖动调整原文与译文区域宽度")
    }

    private func clampedSplitHeight(for total: CGFloat) -> CGFloat {
        let minimumTop: CGFloat = 190
        let minimumBottom: CGFloat = 200
        guard total > minimumTop + minimumBottom + 8 else {
            return max(0, total * 0.45)
        }
        let maximumTop = total - minimumBottom - 8
        return min(max(splitTopHeight, minimumTop), maximumTop)
    }

    private var splitDivider: some View {
        ZStack {
            Color.primary.opacity(0.10)
                .frame(height: 1)
            Color.clear
                .contentShape(Rectangle())
        }
        .frame(height: 8)
        .frame(maxWidth: .infinity)
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    isAdjustingSplit = true
                    if splitDragStart == nil {
                        splitDragStart = splitTopHeight
                    }
                    let start = splitDragStart ?? splitTopHeight
                    splitTopHeight = min(max(start + value.translation.height, 190), 700)
                }
                .onEnded { _ in
                    splitDragStart = nil
                    isAdjustingSplit = false
                }
        )
        .onHover { hovering in
            if hovering {
                NSCursor.resizeUpDown.set()
            } else {
                NSCursor.arrow.set()
            }
        }
        .help("拖动调整原文与译文区域高度")
    }

    private var translatedPane: some View {
        VStack(spacing: 0) {
            paneHeader(
                title: "版式译文",
                symbol: "doc.plaintext",
                detail: "保留原始版面、图表与公式；公式和变量名不翻译"
            ) {
                HStack(spacing: 9) {
                    Button {
                        exportTranslatedPDF()
                    } label: {
                        Label("导出 PDF", systemImage: "square.and.arrow.down")
                            .font(AppFont.chinese(9.5, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Color.primary.opacity(model.canExportTranslatedDocument ? 0.055 : 0.025),
                                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(model.canExportTranslatedDocument ? AppTheme.accent : Color.secondary)
                    .disabled(!model.canExportTranslatedDocument)
                    .help("导出保留原始版面的译文 PDF；未翻译页面保留原文")

                    Rectangle()
                        .fill(Color.primary.opacity(0.10))
                        .frame(width: 1, height: 14)

                    fitControls
                }
            }
            Divider()

            if let document = model.translatedDocument {
                PDFTranslatedPageView(document: document, fitMode: model.fitMode, isLiveResizing: isResizingPDF)
            } else if model.isTranslating {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("正在生成保留版式的译文…")
                        .font(AppFont.chinese(11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.hasLegacyTranslation {
                translatedUnavailableView(
                    title: "旧版译文没有版面数据",
                    message: "本页已有逐句中文译文。重新翻译一次即可生成与原始 PDF 版式一致、公式保持原文的译文页面。",
                    actionTitle: "重新翻译本页"
                ) {
                    model.translateCurrentPage(force: true)
                }
            } else {
                translatedUnavailableView(
                    title: "本页尚未生成版式译文",
                    message: "翻译后会按原始段落位置排版：英文被替换为中文，图表、表格和公式保留在原位，长句自动换行。",
                    actionTitle: settings.isConfigured ? "翻译本页" : nil
                ) {
                    model.translateCurrentPage()
                }
            }
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private func translatedUnavailableView(
        title: String,
        message: String,
        actionTitle: String?,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.plaintext")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(AppFont.chinese(14, weight: .semibold))
            Text(message)
                .font(AppFont.chinese(10.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            if let actionTitle {
                Button(action: action) {
                    Label(actionTitle, systemImage: "sparkles")
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(model.isTranslating || !settings.isConfigured)
            } else if !settings.isConfigured {
                Button { openSettings() } label: {
                    Label("配置模型", systemImage: "key.horizontal")
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func exportTranslatedPDF() {
        guard let document = model.makeExportDocument() else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        let title = ScienceText.display(model.record.paper.title)
            .components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>|\n\r\t"))
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        panel.nameFieldStringValue = "\(title)-译文.pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        document.write(to: url)
    }

    private var originalPane: some View {
        VStack(spacing: 0) {
            paneHeader(
                title: "PDF 原文",
                symbol: "doc.richtext",
                detail: "图表与公式保留原始排版"
            ) {
                fitControls
            }
            Divider()
            if let document = model.readerDocument {
                PDFPageDisplayView(
                    document: document,
                    pageIndex: model.pageIndex,
                    fitMode: model.fitMode,
                    isLiveResizing: isResizingPDF
                )
            } else {
                EmptyView()
            }
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private func paneHeader<Trailing: View>(
        title: String,
        symbol: String,
        detail: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 9) {
            Label(title, systemImage: symbol)
                .font(AppFont.chinese(10, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize()
            Text(detail)
                .font(AppFont.chinese(9))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(-1)
            Spacer(minLength: 12)
            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(.thinMaterial)
    }

    private var fitControls: some View {
        HStack(spacing: 2) {
            fitButton(mode: .automatic, symbol: "rectangle.arrowtriangle.2.outward", help: "整页适应")
            fitButton(mode: .width, symbol: "arrow.left.and.right", help: "适应宽度")
            fitButton(mode: .height, symbol: "arrow.up.and.down", help: "适应高度")
        }
        .padding(2)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
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
                .frame(width: 24, height: 22)
                .background(
                    model.fitMode == mode ? AppTheme.accent.opacity(0.12) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                )
                .contentShape(Rectangle())
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
                                action: settings.isConfigured
                                    ? { model.translateCurrentPage(force: model.hasLegacyTranslation) }
                                    : nil
                            )
                            .padding(.bottom, 12)
                        } else if model.hasLegacyTranslation && !model.isTranslating {
                            legacyTranslationHint
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

                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(model.displayLinePairs.enumerated()), id: \.element.id) { index, pair in
                                BilingualReadingLine(
                                    source: pair.english,
                                    chinese: pair.chinese,
                                    showsTranslation: model.showChinese,
                                    pageIsTranslated: model.isLayoutComplete || model.hasLegacyTranslation,
                                    vocabulary: model.vocabulary,
                                    isMath: pair.isMath,
                                    isHeading: pair.isHeading
                                )
                                .padding(.top, index == 0 ? 0 : (pair.isFirstInBlock ? 18 : 6))
                            }
                        }

                        if model.isLayoutComplete || model.hasLegacyTranslation {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "internaldrive")
                                    .font(.system(size: 9))
                                Text(model.isLayoutComplete
                                     ? "本页译文、术语与关键词汇已保存在本机；切换到其他页后再返回，不会再次调用模型。「译文」模式可查看保留原始版面的输出。"
                                     : "本页为旧版逐句译文；重新翻译可生成保留原始版面的译文，数据同样保存在本机。")
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
                Text("论文正文翻译由你手动触发。点击顶部的「翻译本页」只处理当前页，或点击「翻译全文」逐页翻译整篇论文；模型会按原始段落生成中文译文与关键词汇，并自动保存在本机。切换到「译文」模式可查看保留原始版面、图表和公式的输出。")
                    .font(AppFont.chinese(9.8))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(11)
        .background(AppTheme.accent.opacity(0.05), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private var legacyTranslationHint: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.warning)
            VStack(alignment: .leading, spacing: 5) {
                Text("当前为旧版逐句译文")
                    .font(AppFont.chinese(11, weight: .semibold))
                Text("旧版译文没有保存段落位置和版面信息。重新翻译本页后会按原始 PDF 的段落、分栏和位置排版，公式、变量名、图表与表格保持原文；术语会沿用本文已建立的译名。")
                    .font(AppFont.chinese(9.8))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    model.translateCurrentPage(force: true)
                } label: {
                    Label("重新翻译并生成版式", systemImage: "arrow.triangle.2.circlepath")
                        .font(AppFont.chinese(9.5, weight: .semibold))
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(model.isTranslating || !settings.isConfigured)
                .padding(.top, 2)
            }
            Spacer()
        }
        .padding(11)
        .background(AppTheme.warning.opacity(0.06), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
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
    var isMath = false
    var isHeading = false

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
            if isMath {
                Text(source)
                    .font(.system(size: 13.5, weight: .regular, design: .serif))
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 4) {
                    Image(systemName: "function")
                        .font(.system(size: 8.5, weight: .medium))
                    Text("公式 / 变量名保持原文")
                        .font(AppFont.chinese(9.2))
                }
                .foregroundStyle(.tertiary)
            } else {
                Text(highlightedSource)
                    .font(.system(
                        size: isHeading ? 17.5 : 15.5,
                        weight: isHeading ? .semibold : .regular,
                        design: .serif
                    ))
                    .lineSpacing(5)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)

                if showsTranslation, pageIsTranslated {
                    Text(displayChinese)
                        .font(AppFont.chinese(isHeading ? 14.5 : 13.2, weight: isHeading ? .semibold : .regular))
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
}

private struct PDFVocabularySidebar: View {
    let entries: [PaperVocabularyEntry]
    let terms: [PaperTerm]
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
            } else if entries.isEmpty && terms.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: isTranslated ? "checkmark.circle" : "text.bubble")
                        .font(.system(size: 29, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text(isTranslated ? "本页没有返回关键词汇" : "翻译本页后")
                        .font(AppFont.chinese(11, weight: .medium))
                    Text(isTranslated ? "可切换页面继续阅读。" : "这里会显示本页 4–8 个重点词汇的音标、词性、中文释义和例句，以及本文统一的术语译名。")
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
                        if !terms.isEmpty {
                            PDFTerminologyCard(terms: terms)
                        }
                        ForEach(entries) { entry in
                            PDFVocabularyCard(entry: entry)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(11)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct PDFTerminologyCard: View {
    let terms: [PaperTerm]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Image(systemName: "character.book.closed")
                    .font(.system(size: 9, weight: .medium))
                Text("术语对照")
                    .font(AppFont.chinese(10.5, weight: .semibold))
                Text("TERMINOLOGY")
                    .font(.system(size: 7.5, weight: .bold, design: .rounded))
                    .tracking(0.7)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("\(terms.count)")
                    .font(AppFont.mono(8))
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(AppTheme.accent)

            ForEach(Array(terms.prefix(12)), id: \.self) { term in
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(term.source)
                        .font(.system(size: 9.4, design: .serif))
                        .foregroundStyle(.primary.opacity(0.78))
                        .lineLimit(1)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    Text(term.target)
                        .font(AppFont.chinese(9.4, weight: .medium))
                        .foregroundStyle(AppTheme.accent)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.accent.opacity(0.045), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(AppTheme.accent.opacity(0.12), lineWidth: 1)
        }
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
