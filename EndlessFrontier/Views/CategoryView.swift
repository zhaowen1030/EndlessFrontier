import SwiftUI
import AppKit

struct CategoryView: View {
    let category: ArxivCategory
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var downloads: DownloadManager

    @StateObject private var feedModel: CategoryFeedModel
    @ObservedObject private var exploreModel: ExploreModel
    @ObservedObject private var treeModel: KnowledgeTreeModel
    @ObservedObject private var systemTranslator: SystemTranslator

    @State private var searchText: String = ""
    @State private var didDebugDownload = false
    @State private var isAnnotatingReport = false
    @FocusState private var searchFocused: Bool

    init(category: ArxivCategory, services: AppServices) {
        self.category = category
        _feedModel = StateObject(wrappedValue: CategoryFeedModel(category: category, services: services))
        _exploreModel = ObservedObject(wrappedValue: services.reportGenerationCenter.model(for: category))
        _treeModel = ObservedObject(wrappedValue: services.knowledgeTreeCenter.model(for: category))
        _systemTranslator = ObservedObject(wrappedValue: services.systemTranslator)
    }

    private var group: CategoryGroup? { ArxivTaxonomy.group(category.groupID) }
    private var archive: CategoryArchive? { ArxivTaxonomy.archive(category.archiveID) }

    var body: some View {
        VStack(spacing: 0) {
            header
            HairlineDivider().opacity(0.65)
            actionBar
            HairlineDivider().opacity(0.45)
            content
        }
        .background(PageBackdrop(tint: AppTheme.groupColor(category.groupID)))
        .navigationTitle(category.nameEN)
        .navigationSubtitle(category.nameZH)
        .onAppear {
            if appState.categoryTab == .papers {
                feedModel.loadIfNeeded()
            }
            #if DEBUG
            if DebugLaunchOptions.autoGenerateReport,
               exploreModel.report == nil,
               !exploreModel.isGenerating {
                appState.categoryTab = .explore
                exploreModel.generate()
            }
            #endif
        }
        .onChange(of: appState.categoryTab) { _, newTab in
            if newTab == .papers { feedModel.loadIfNeeded() }
            if newTab != .explore { isAnnotatingReport = false }
        }
        .onChange(of: exploreModel.hasReport) { _, hasReport in
            if !hasReport { isAnnotatingReport = false }
        }
        .onChange(of: feedModel.papers.count) { _, newCount in
            #if DEBUG
            guard DebugLaunchOptions.downloadFirstPaper, !didDebugDownload, newCount > 0 else { return }
            didDebugDownload = true
            if let first = feedModel.papers.first {
                downloads.download(first)
            }
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshPapers)) { _ in
            if appState.categoryTab == .papers { feedModel.reload() }
        }
        .onDisappear {
            feedModel.stopWork()
        }
    }

    private var header: some View {
        let tint = AppTheme.groupColor(category.groupID)
        return VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 7) {
                    if let group {
                        Label {
                            Text(group.nameEN)
                                .font(AppFont.body(10, weight: .semibold))
                        } icon: {
                            Image(systemName: group.symbol)
                                .font(.system(size: 9.5, weight: .medium))
                        }
                        .foregroundStyle(tint)
                    }
                    Text("/")
                        .font(AppFont.body(9))
                        .foregroundStyle(.quaternary)
                    if let archive, archive.id != group?.id {
                        Text(archive.nameEN)
                            .font(AppFont.body(10, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("/")
                            .font(AppFont.body(9))
                            .foregroundStyle(.quaternary)
                    }
                    Text(category.id)
                        .font(AppFont.mono(10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.quaternary)
                    Text(feedModel.displayCountBilingual)
                        .font(AppFont.chinese(9.5))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    headerActions(tint: tint)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(category.nameEN)
                        .font(AppFont.display(29, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.97))
                        .lineLimit(2)
                        .textSelection(.enabled)
                    HStack(spacing: 8) {
                        Text(category.nameZH)
                            .font(AppFont.chinese(16, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.62))
                        if exploreModel.hasReport {
                            HStack(spacing: 3) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 8, weight: .semibold))
                                Text("AI 报告已存档")
                                    .font(AppFont.chinese(9.5, weight: .medium))
                            }
                            .foregroundStyle(AppTheme.gold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.gold.opacity(0.09), in: Capsule())
                        }
                    }
                }
            }
        .padding(.horizontal, 24)
        .padding(.top, 19)
        .padding(.bottom, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            GeometryReader { proxy in
                ZStack(alignment: .topTrailing) {
                    LinearGradient(
                        colors: [tint.opacity(0.20), tint.opacity(0.055), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Circle()
                        .fill(tint.opacity(0.10))
                        .frame(width: 300, height: 300)
                        .blur(radius: 8)
                        .offset(x: 110, y: -180)
                    Circle()
                        .strokeBorder(tint.opacity(0.13), lineWidth: 1)
                        .frame(width: 210, height: 210)
                        .offset(x: 38, y: -200)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
            }
        }
        .clipped()
    }

    private func headerActions(tint: Color) -> some View {
        HStack(spacing: 7) {
            Button {
                appState.openGraph(focus: category.id)
            } label: {
                Image(systemName: "point.3.connected.trianglepath.dotted")
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 26)
            .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .help("在知识图谱中查看 View in knowledge graph")

            Button {
                feedModel.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .rotationEffect(.degrees(feedModel.isLoading ? 360 : 0))
                    .animation(feedModel.isLoading ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: feedModel.isLoading)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 26)
            .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .help("刷新 Refresh")

            Button {
                withAnimation(.snappy(duration: 0.22)) { appState.categoryTab = .explore }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10.5, weight: .semibold))
                    Text("AI 探索")
                        .font(AppFont.chinese(11.5, weight: .semibold))
                    Text("Explore")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.62))
                }
            }
            .buttonStyle(PrimaryActionButtonStyle(tint: tint))
        }
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            SegmentedTabControl(
                selection: $appState.categoryTab,
                reportAvailable: exploreModel.hasReport,
                treeAvailable: treeModel.hasTree
            )

            if appState.categoryTab == .papers {
                Spacer(minLength: 8)
                searchField
                sortMenu
                translationControls
            } else if appState.categoryTab == .explore {
                Spacer(minLength: 8)
                if exploreModel.hasReport {
                    Text("本地已保存")
                        .font(AppFont.chinese(9.5))
                        .foregroundStyle(.tertiary)
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            isAnnotatingReport.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isAnnotatingReport ? "checkmark" : "paintbrush.pointed")
                                .font(.system(size: 10, weight: .semibold))
                            Text(isAnnotatingReport ? "完成标注" : "划词标色")
                                .font(AppFont.chinese(10.5, weight: .medium))
                        }
                    }
                    .buttonStyle(SecondaryActionButtonStyle(tint: isAnnotatingReport ? AppTheme.accent : .primary))
                    .help("开启后选中报告正文，在底部选择颜色；再次选中已标记文字可修改或清除。标注仅保存在本机。")
                } else {
                    Text("手动生成 · 自动保存")
                        .font(AppFont.chinese(10))
                        .foregroundStyle(.tertiary)
                }
            } else {
                Spacer(minLength: 8)
                if treeModel.hasTree, let tree = treeModel.tree {
                    Text("\(tree.nodeCount) 个知识点 · 本地已保存")
                        .font(AppFont.chinese(9.5))
                        .foregroundStyle(.tertiary)
                } else {
                    Text("手动生成 · 自动保存")
                        .font(AppFont.chinese(10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 9)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.6))
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("在分类中搜索 Search", text: $searchText)
                .textFieldStyle(.plain)
                .font(AppFont.chinese(11))
                .focused($searchFocused)
                .onSubmit { applySearch() }
            if !searchText.isEmpty || !feedModel.query.isEmpty {
                Button {
                    searchText = ""
                    feedModel.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .frame(width: 220)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(searchFocused ? AppTheme.accent.opacity(0.35) : Color.primary.opacity(0.06), lineWidth: 1)
        }
        .onChange(of: searchText) { _, newValue in
            if newValue.isEmpty && !feedModel.query.isEmpty {
                feedModel.clearSearch()
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            ForEach(ArxivSort.allCases) { option in
                Button {
                    feedModel.changeSort(option)
                } label: {
                    if option == feedModel.sort {
                        Label("\(option.labelZH) · \(option.labelEN)", systemImage: "checkmark")
                    } else {
                        Text("\(option.labelZH) · \(option.labelEN)")
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 9.5, weight: .medium))
                Text(feedModel.sort.labelZH)
                    .font(AppFont.chinese(10.5))
                Image(systemName: "chevron.down")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    @ViewBuilder
    private var translationControls: some View {
        if feedModel.isTranslating {
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Text(systemTranslator.isPreparing ? "准备系统翻译…" : (feedModel.translationSummary ?? "翻译中…"))
                    .font(AppFont.chinese(10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(AppTheme.accent.opacity(0.06), in: Capsule())
        } else if feedModel.untranslatedCount > 0, feedModel.canTranslate {
            Button {
                feedModel.translateAll()
            } label: {
                Label("翻译本页", systemImage: "character.book.closed")
                    .font(AppFont.chinese(10.5))
            }
            .buttonStyle(QuietIconButtonStyle())
            .help("将本页论文翻译为中文 Translate this page")
        } else if !feedModel.papers.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 9.5))
                Text("已双语")
                    .font(AppFont.chinese(10))
            }
            .foregroundStyle(AppTheme.positive.opacity(0.9))
        }
    }

    @ViewBuilder
    private var content: some View {
        switch appState.categoryTab {
        case .papers:
            papersContent
        case .explore:
            ExploreView(model: exploreModel, category: category, isAnnotating: $isAnnotatingReport)
        case .knowledgeTree:
            KnowledgeTreePage(model: treeModel, category: category)
        }
    }

    private var papersContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 13) {
                if !feedModel.query.isEmpty {
                    HStack(spacing: 6) {
                        Text("搜索结果")
                            .font(AppFont.chinese(11, weight: .semibold))
                        Text("“\(feedModel.query)”")
                            .font(AppFont.body(11))
                            .foregroundStyle(.secondary)
                        Text("· \(feedModel.papers.count)")
                            .font(AppFont.mono(9.5))
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Button("清除搜索") {
                            searchText = ""
                            feedModel.clearSearch()
                        }
                        .buttonStyle(.plain)
                        .font(AppFont.chinese(10))
                        .foregroundStyle(AppTheme.accent)
                    }
                    .padding(.horizontal, 2)
                }

                if let notice = feedModel.translationNotice {
                    ErrorBanner(
                        title: "中文翻译未完成",
                        message: notice,
                        actionTitle: "重试",
                        action: { feedModel.retryFailedTranslations() }
                    )
                }

                if let error = feedModel.errorMessage, !feedModel.papers.isEmpty {
                    ErrorBanner(
                        title: feedModel.hasMore ? "加载更多论文失败" : "arXiv 请求失败",
                        message: error,
                        actionTitle: "重试",
                        action: {
                            if feedModel.hasMore { feedModel.loadMore() } else { feedModel.reload() }
                        }
                    )
                }

                if feedModel.isLoading && feedModel.papers.isEmpty {
                    ForEach(0..<4, id: \.self) { _ in PaperRowSkeleton() }
                } else if feedModel.papers.isEmpty {
                    if let error = feedModel.errorMessage {
                        EmptyState(
                            icon: "antenna.radiowaves.left.and.right.slash",
                            titleEN: "Could not reach arXiv",
                            titleZH: "无法连接 arXiv",
                            message: error,
                            actionTitle: "重试",
                            action: { feedModel.reload() }
                        )
                        .frame(minHeight: 380)
                    } else {
                        EmptyState(
                            icon: feedModel.query.isEmpty ? "doc.text.magnifyingglass" : "magnifyingglass",
                            titleEN: feedModel.query.isEmpty ? "No papers here yet" : "No matching papers",
                            titleZH: feedModel.query.isEmpty ? "这个分类还没有论文" : "没有找到匹配的论文",
                            message: feedModel.query.isEmpty
                                ? "Try refreshing in a moment. arXiv may be updating its index."
                                : "Try a shorter query, different spelling, or search the whole catalog in another category.",
                            actionTitle: feedModel.query.isEmpty ? "刷新" : "清除搜索",
                            action: {
                                if feedModel.query.isEmpty {
                                    feedModel.reload()
                                } else {
                                    searchText = ""
                                    feedModel.clearSearch()
                                }
                            }
                        )
                        .frame(minHeight: 380)
                    }
                } else {
                    ForEach(feedModel.papers) { paper in
                        PaperRow(
                            paper: paper,
                            translation: feedModel.translations[paper.id],
                            translationPending: (feedModel.isTranslating || feedModel.individuallyTranslating.contains(paper.id))
                                && feedModel.translations[paper.id] == nil,
                            canTranslate: feedModel.canTranslate,
                            translationError: feedModel.individualTranslationErrors[paper.id],
                            downloadState: downloads.state(for: paper.id),
                            onDownload: { downloads.download(paper) },
                            onOpen: { NSWorkspace.shared.open(paper.absURL) },
                            onReveal: { downloads.reveal(paper) },
                            onRedownload: { downloads.download(paper, force: true) },
                            onTranslate: { feedModel.translate(paper: paper) }
                        )
                    }

                    if feedModel.hasMore {
                        HStack {
                            Spacer()
                            Button {
                                feedModel.loadMore()
                            } label: {
                                if feedModel.isLoadingMore {
                                    HStack(spacing: 7) {
                                        ProgressView().controlSize(.small)
                                        Text("加载中…")
                                    }
                                } else {
                                    Label("加载更多论文", systemImage: "arrow.down.to.line")
                                }
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                            .disabled(feedModel.isLoadingMore)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }

                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.seal")
                            .font(.system(size: 8.5))
                        Text(translationFooterText)
                            .font(AppFont.chinese(9))
                        Spacer()
                        Text("仅用于研究与学习")
                            .font(AppFont.chinese(9))
                    }
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 2)
                    .padding(.bottom, 22)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .frame(maxWidth: 1_000)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.automatic)
    }

    private var translationFooterText: String {
        switch settings.translationMode {
        case .off:
            return "论文元数据来自 arXiv.org · 中文翻译未启用"
        default:
            return "论文元数据来自 arXiv.org · 中文翻译由\(translationSourceLabel)生成"
        }
    }

    private var translationSourceLabel: String {
        switch settings.translationMode {
        case .systemOnly:
            return " Apple 系统翻译"
        case .automatic:
            return settings.isConfigured ? "大语言模型" : " Apple 系统翻译"
        case .llmOnly:
            return "大语言模型"
        case .off:
            return "（未启用）"
        }
    }

    private func applySearch() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        feedModel.applySearch(trimmed)
    }
}
