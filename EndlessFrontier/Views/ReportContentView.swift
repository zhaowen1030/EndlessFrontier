import SwiftUI

struct ReportContentView: View {
    let report: AIReport
    let category: ArxivCategory
    let generationError: String?
    let onRegenerate: () -> Void
    let onRetry: () -> Void

    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var appState: AppState
    @Environment(\.openSettings) private var openSettings
    @StateObject private var annotations: ReportAnnotationStore
    @State private var highlightController = HighlightSelectionController()
    @Binding var isAnnotating: Bool
    @State private var confirmRegenerate = false

    init(
        report: AIReport,
        category: ArxivCategory,
        generationError: String?,
        onRegenerate: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        isAnnotating: Binding<Bool>
    ) {
        self.report = report
        self.category = category
        self.generationError = generationError
        self.onRegenerate = onRegenerate
        self.onRetry = onRetry
        _isAnnotating = isAnnotating
        _annotations = StateObject(wrappedValue: ReportAnnotationStore(
            categoryID: category.id,
            reportGeneratedAt: report.generatedAt
        ))
    }

    private var tint: Color { AppTheme.groupColor(category.groupID) }

    private var sections: [ReportSectionDescriptor] {
        var items: [ReportSectionDescriptor] = [
            .init(id: "overview", zh: "学科概览", en: "Overview", symbol: "scope", show: true)
        ]
        items.append(.init(id: "history", zh: "发展历史", en: "History", symbol: "clock.arrow.circlepath", show: !report.history.isEmpty))
        items.append(.init(id: "problems", zh: "未解难题", en: "Open Problems", symbol: "questionmark.circle", show: !report.openProblems.isEmpty))
        items.append(.init(id: "frontiers", zh: "前沿进展", en: "Frontiers", symbol: "telescope", show: !report.frontiers.isEmpty))
        items.append(.init(id: "achievements", zh: "关键成果与应用", en: "Achievements", symbol: "lightbulb", show: !report.achievements.isEmpty))
        items.append(.init(id: "figures", zh: "关键人物", en: "Key Figures", symbol: "person.2.wave.2", show: !report.figures.isEmpty))
        items.append(.init(id: "relations", zh: "交叉关系", en: "Connections", symbol: "point.3.connected.trianglepath.dotted", show: !report.relations.isEmpty))
        items.append(.init(id: "terms", zh: "关键名词", en: "Key Terms", symbol: "character.book.closed", show: !report.terms.isEmpty))
        items.append(.init(id: "equations", zh: "关键公式", en: "Equations", symbol: "function", show: !report.equations.isEmpty))
        return items.filter(\.show)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { proxy in
                ScrollView {
                LazyVStack(alignment: .leading, spacing: 26) {
                    if let generationError {
                        ErrorBanner(
                            title: "上一次重新生成未完成",
                            message: generationError,
                            actionTitle: settings.isConfigured ? "重试" : nil,
                            action: settings.isConfigured ? onRetry : nil
                        )
                    }

                    reportHeader
                    sectionNavigation(proxy: proxy)

                    overviewSection
                        .id("overview")
                    if !report.history.isEmpty {
                        historySection.id("history")
                    }
                    if !report.openProblems.isEmpty {
                        problemsSection.id("problems")
                    }
                    if !report.frontiers.isEmpty {
                        frontiersSection.id("frontiers")
                    }
                    if !report.achievements.isEmpty {
                        achievementsSection.id("achievements")
                    }
                    if !report.figures.isEmpty {
                        figuresSection.id("figures")
                    }
                    if !report.relations.isEmpty {
                        relationsSection.id("relations")
                    }
                    if !report.terms.isEmpty {
                        termsSection.id("terms")
                    }
                    if !report.equations.isEmpty {
                        equationsSection.id("equations")
                    }
                    reportFooter
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 34)
                .frame(maxWidth: 1_060)
                .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.automatic)
                .onAppear {
                    #if DEBUG
                    if let target = DebugLaunchOptions.reportSection {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            proxy.scrollTo(target, anchor: .top)
                        }
                    }
                    #endif
                }
            }

            HighlightPalette(controller: highlightController, annotationStore: annotations)
                .zIndex(80)
        }
        .onChange(of: report.generatedAt) { _, newValue in
            annotations.reconcile(reportGeneratedAt: newValue)
        }
        .onChange(of: isAnnotating) { _, enabled in
            if !enabled { highlightController.clear() }
        }
        .onAppear {
            #if DEBUG
            if DebugLaunchOptions.forceAnnotationMode {
                isAnnotating = true
            }
            #endif
        }
        .confirmationDialog(
            "重新生成报告？",
            isPresented: $confirmRegenerate,
            titleVisibility: .visible
        ) {
            Button("重新生成并覆盖本地报告", role: .destructive) { onRegenerate() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("现有报告会被新的 AI 生成结果替换。此操作会消耗模型额度，且不会自动发生。正文变化后已有文本底色会清除。")
        }
    }

    private var reportHeader: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.13), Color.primary.opacity(0.02), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 7) {
                            Text("AI RESEARCH DOSSIER")
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .tracking(1.5)
                            Text("学科研究档案")
                                .font(AppFont.chinese(10.5, weight: .semibold))
                        }
                        .foregroundStyle(tint)
                        Text(category.nameEN)
                            .font(AppFont.display(24, weight: .semibold))
                        Text(category.nameZH)
                            .font(AppFont.chinese(14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        if settings.isConfigured {
                            Button {
                                confirmRegenerate = true
                            } label: {
                                Label("重新生成", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                        } else {
                            Button {
                                openSettings()
                            } label: {
                                Label("配置模型", systemImage: "key.horizontal")
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                        }
                        Text("\(report.generatedAt.shortChinese) · \(report.generatedAt.formatted(date: .omitted, time: .shortened))")
                            .font(AppFont.chinese(9.5))
                            .foregroundStyle(.tertiary)
                        Text(report.model.isEmpty ? "AI generated" : report.model)
                            .font(AppFont.mono(8.8))
                            .foregroundStyle(.tertiary)
                    }
                }

                HStack(spacing: 6) {
                    Chip(text: "\(report.history.count) 历史节点", tint: tint)
                    Chip(text: "\(report.openProblems.count) 未解难题", tint: AppTheme.warning)
                    Chip(text: "\(report.frontiers.count) 前沿方向", tint: AppTheme.cyan)
                    Chip(text: "\(report.relations.count) 交叉学科", tint: AppTheme.accent)
                    Chip(text: "\(report.figures.count) 关键人物", tint: AppTheme.gold)
                    Spacer(minLength: 0)
                    Text("本地已存档 · 无需重复生成")
                        .font(AppFont.chinese(9.5))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(18)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(tint.opacity(0.13), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func sectionNavigation(proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(sections) { section in
                    Button {
                        withAnimation(.snappy(duration: 0.3)) {
                            proxy.scrollTo(section.id, anchor: .top)
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: section.symbol)
                                .font(.system(size: 9, weight: .medium))
                            Text(section.zh)
                                .font(AppFont.chinese(10.5, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.035), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.never)
        .padding(.vertical, -6)
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ReportSectionHeader(
                number: "00",
                titleEN: "The Discipline at a Glance",
                titleZH: "学科概览",
                subtitleEN: "What this field studies, why it matters, and how it thinks.",
                tint: tint,
                symbol: "scope"
            )

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    LanguageTag(text: "EN")
                    Text("Overview")
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                markedText(
                    report.overviewEN,
                    fieldID: "overview.en",
                    size: 15,
                    lineSpacing: 5
                )

                HairlineDivider()

                HStack {
                    LanguageTag(text: "中文", highlighted: true)
                    Text("学科概览")
                        .font(AppFont.chinese(9.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                markedText(
                    report.overviewZH,
                    fieldID: "overview.zh",
                    size: 14,
                    tone: .secondary,
                    lineSpacing: 7
                )
            }
            .padding(20)
            .cardSurface(radius: 15, tint: tint.opacity(0.025), stroke: tint.opacity(0.10))
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ReportSectionHeader(
                number: "01",
                titleEN: "Origins and Evolution",
                titleZH: "发展历史",
                subtitleEN: "How the field's central questions and methods took shape.",
                tint: AppTheme.accent,
                symbol: "clock.arrow.circlepath"
            )

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(report.history.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .trailing, spacing: 7) {
                            Text(item.period)
                                .font(AppFont.mono(10, weight: .semibold))
                                .foregroundStyle(AppTheme.accent)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 112, alignment: .trailing)
                            Circle()
                                .fill(index == 0 ? AppTheme.accent : Color.primary.opacity(0.15))
                                .frame(width: index == 0 ? 8 : 6, height: index == 0 ? 8 : 6)
                                .overlay {
                                    if index == 0 {
                                        Circle()
                                            .strokeBorder(AppTheme.accent.opacity(0.25), lineWidth: 4)
                                            .frame(width: 16, height: 16)
                                    }
                                }
                            if index < report.history.count - 1 {
                                Rectangle()
                                    .fill(Color.primary.opacity(0.09))
                                    .frame(width: 1)
                                    .frame(minHeight: 72)
                            }
                        }
                        .frame(width: 128, alignment: .trailing)

                        VStack(alignment: .leading, spacing: 7) {
                            Text(item.titleEN)
                                .font(AppFont.body(14, weight: .semibold))
                            Text(item.titleZH)
                                .font(AppFont.chinese(12.5, weight: .semibold))
                                .foregroundStyle(.secondary)
                            markedText(
                                item.detailEN,
                                fieldID: "history.\(index).detail.en",
                                size: 12.3,
                                lineSpacing: 3.5
                            )
                            markedText(
                                item.detailZH,
                                fieldID: "history.\(index).detail.zh",
                                size: 12.2,
                                tone: .secondary,
                                lineSpacing: 4.5
                            )
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.026), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 1)
                        }
                        .padding(.bottom, 12)
                    }
                }
            }
        }
    }

    private var problemsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ReportSectionHeader(
                number: "02",
                titleEN: "Unresolved Questions",
                titleZH: "未解难题",
                subtitleEN: "What the field still cannot explain, decide, or build.",
                tint: AppTheme.warning,
                symbol: "questionmark.circle"
            )

            VStack(spacing: 10) {
                ForEach(Array(report.openProblems.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 15) {
                        Text(String(format: "%02d", index + 1))
                            .font(.system(size: 19, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.warning.opacity(0.55))
                            .frame(width: 30, alignment: .leading)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 7) {
                                Text(item.titleEN)
                                    .font(AppFont.body(14, weight: .semibold))
                                Chip(text: "OPEN", tint: AppTheme.warning, monospaced: true)
                            }
                            Text(item.titleZH)
                                .font(AppFont.chinese(12.5, weight: .semibold))
                                .foregroundStyle(.secondary)
                            markedText(
                                item.detailEN,
                                fieldID: "problems.\(index).detail.en",
                                size: 12.2,
                                lineSpacing: 3.5
                            )
                            markedText(
                                item.detailZH,
                                fieldID: "problems.\(index).detail.zh",
                                size: 12.1,
                                tone: .secondary,
                                lineSpacing: 4.5
                            )
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .background(AppTheme.warning.opacity(0.035), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(AppTheme.warning.opacity(0.10), lineWidth: 1)
                    }
                }
            }
        }
    }

    private var frontiersSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ReportSectionHeader(
                number: "03",
                titleEN: "Active Frontiers",
                titleZH: "前沿进展",
                subtitleEN: "Where the field is moving now, and what is still at the edge.",
                tint: AppTheme.cyan,
                symbol: "telescope"
            )

            VStack(spacing: 10) {
                ForEach(Array(report.frontiers.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.cyan.opacity(0.09))
                                .frame(width: 30, height: 30)
                            Image(systemName: index % 2 == 0 ? "sparkles" : "arrow.up.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppTheme.cyan)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.titleEN)
                                .font(AppFont.body(14, weight: .semibold))
                            Text(item.titleZH)
                                .font(AppFont.chinese(12.5, weight: .semibold))
                                .foregroundStyle(.secondary)
                            markedText(
                                item.detailEN,
                                fieldID: "problems.\(index).detail.en",
                                size: 12.2,
                                lineSpacing: 3.5
                            )
                            markedText(
                                item.detailZH,
                                fieldID: "problems.\(index).detail.zh",
                                size: 12.1,
                                tone: .secondary,
                                lineSpacing: 4.5
                            )
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.055), lineWidth: 1)
                    }
                }
            }
        }
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ReportSectionHeader(
                number: "04",
                titleEN: "Landmark Results and Real-World Impact",
                titleZH: "关键成果与应用",
                subtitleEN: "Results that changed what the field can do, and where they show up in life.",
                tint: AppTheme.positive,
                symbol: "lightbulb"
            )

            VStack(spacing: 12) {
                ForEach(Array(report.achievements.enumerated()), id: \.offset) { index, item in
                    VStack(alignment: .leading, spacing: 11) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(String(format: "%02d", index + 1))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.positive)
                            Text(item.titleEN)
                                .font(AppFont.body(14.5, weight: .semibold))
                            Spacer()
                        }
                        Text(item.titleZH)
                            .font(AppFont.chinese(12.8, weight: .semibold))
                            .foregroundStyle(.secondary)
                        markedText(
                            item.detailEN,
                            fieldID: "achievements.\(index).detail.en",
                            size: 12.2,
                            lineSpacing: 3.5
                        )
                        markedText(
                            item.detailZH,
                            fieldID: "achievements.\(index).detail.zh",
                            size: 12.1,
                            tone: .secondary,
                            lineSpacing: 4.5
                        )

                        if !item.applications.isEmpty {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.turn.down.right")
                                    .font(.system(size: 8.5, weight: .medium))
                                Text("现实应用 · Applications")
                                    .font(AppFont.chinese(9.5, weight: .semibold))
                            }
                            .foregroundStyle(AppTheme.positive.opacity(0.85))
                            .padding(.top, 2)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 235), spacing: 8)], spacing: 8) {
                                ForEach(Array(item.applications.enumerated()), id: \.offset) { _, application in
                                    HStack(alignment: .top, spacing: 7) {
                                        Image(systemName: "circle.fill")
                                            .font(.system(size: 3.5))
                                            .foregroundStyle(AppTheme.positive)
                                            .padding(.top, 6)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(application.en)
                                                .font(AppFont.body(10.5, weight: .medium))
                                                .foregroundStyle(.primary.opacity(0.74))
                                                .fixedSize(horizontal: false, vertical: true)
                                            Text(application.zh)
                                                .font(AppFont.chinese(10.2))
                                                .foregroundStyle(.secondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                    .padding(9)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(AppTheme.positive.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                    }
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppTheme.positive.opacity(0.35))
                            .frame(width: 2.5)
                            .padding(.vertical, 14)
                    }
                }
            }
        }
    }

    private var figuresSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ReportSectionHeader(
                number: "05",
                titleEN: "People Who Shaped the Field",
                titleZH: "关键人物",
                subtitleEN: "Founders and builders, described through their specific contributions.",
                tint: AppTheme.gold,
                symbol: "person.2.wave.2"
            )

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 265), spacing: 11, alignment: .top)],
                alignment: .leading,
                spacing: 11
            ) {
                ForEach(Array(report.figures.enumerated()), id: \.offset) { index, figure in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [AppTheme.gold.opacity(0.25), tint.opacity(0.12)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                Text(avatarInitial(figure))
                                    .font(AppFont.display(18, weight: .semibold))
                                    .foregroundStyle(AppTheme.gold)
                            }
                            .frame(width: 44, height: 44)
                            .overlay {
                                Circle().strokeBorder(AppTheme.gold.opacity(0.16), lineWidth: 1)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(figure.nameEN)
                                    .font(AppFont.body(13, weight: .semibold))
                                Text(figure.nameZH)
                                    .font(AppFont.chinese(11.5))
                                    .foregroundStyle(.secondary)
                                if let era = figure.era, !era.trimmed.isEmpty {
                                    Text(era)
                                        .font(AppFont.mono(8.8))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        HStack(spacing: 5) {
                            Text(figure.fieldEN)
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(AppTheme.gold)
                            Text("·")
                                .foregroundStyle(.quaternary)
                            Text(figure.fieldZH)
                                .font(AppFont.chinese(9))
                                .foregroundStyle(.secondary)
                        }
                        markedText(
                            figure.contributionEN,
                            fieldID: "figures.\(index).contribution.en",
                            size: 11.2,
                            lineSpacing: 3
                        )
                        markedText(
                            figure.contributionZH,
                            fieldID: "figures.\(index).contribution.zh",
                            size: 11,
                            tone: .secondary,
                            lineSpacing: 3.5
                        )
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
                    .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.055), lineWidth: 1)
                    }
                }
            }
        }
    }

    private var relationsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ReportSectionHeader(
                number: "06",
                titleEN: "Interdisciplinary Connections",
                titleZH: "交叉关系",
                subtitleEN: "Substantive exchanges with other arXiv disciplines. Each node can be explored with AI.",
                tint: AppTheme.accent,
                symbol: "point.3.connected.trianglepath.dotted"
            )

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 295), spacing: 10, alignment: .top)],
                alignment: .leading,
                spacing: 10
            ) {
                ForEach(Array(report.relations.enumerated()), id: \.offset) { _, relation in
                    let exists = ArxivTaxonomy.category(relation.categoryID) != nil
                    Button {
                        guard exists else { return }
                        appState.openCategory(relation.categoryID, tab: .explore)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Text(relation.categoryID)
                                    .font(AppFont.mono(9, weight: .semibold))
                                    .foregroundStyle(AppTheme.accent)
                                Spacer()
                                ForEach(0..<3, id: \.self) { dot in
                                    Circle()
                                        .fill(dot < relation.strength ? AppTheme.accent : Color.primary.opacity(0.10))
                                        .frame(width: 4, height: 4)
                                }
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            HStack(alignment: .firstTextBaseline, spacing: 5) {
                                Text(relation.nameEN)
                                    .font(AppFont.body(12.5, weight: .semibold))
                                Text(relation.nameZH)
                                    .font(AppFont.chinese(10.5))
                                    .foregroundStyle(.secondary)
                            }
                            Text(relation.relationEN)
                                .font(AppFont.body(10.8))
                                .foregroundStyle(.primary.opacity(0.70))
                                .fixedSize(horizontal: false, vertical: true)
                            Text(relation.relationZH)
                                .font(AppFont.chinese(10.6))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 7.5))
                                Text("点击进入 AI 探索")
                                    .font(AppFont.chinese(8.8))
                            }
                            .foregroundStyle(AppTheme.accent.opacity(exists ? 0.85 : 0.3))
                            .padding(.top, 1)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
                        .background(AppTheme.accent.opacity(0.035), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(AppTheme.accent.opacity(0.10), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!exists)
                }
            }
        }
    }

    private var termsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ReportSectionHeader(
                number: "07",
                titleEN: "Concepts You Need",
                titleZH: "关键名词",
                subtitleEN: "The vocabulary that makes the field legible.",
                tint: AppTheme.cyan,
                symbol: "character.book.closed"
            )

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 285), spacing: 10, alignment: .top)],
                alignment: .leading,
                spacing: 10
            ) {
                ForEach(Array(report.terms.enumerated()), id: \.offset) { index, term in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text(term.termEN)
                                .font(AppFont.body(12.2, weight: .semibold))
                            Text(term.termZH)
                                .font(AppFont.chinese(10.5))
                                .foregroundStyle(AppTheme.cyan)
                            Spacer(minLength: 0)
                        }
                        markedText(
                            term.definitionEN,
                            fieldID: "terms.\(index).definition.en",
                            size: 10.7,
                            lineSpacing: 2.5
                        )
                        markedText(
                            term.definitionZH,
                            fieldID: "terms.\(index).definition.zh",
                            size: 10.5,
                            tone: .secondary,
                            lineSpacing: 3
                        )
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                    .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
                    }
                }
            }
        }
    }

    private var equationsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ReportSectionHeader(
                number: "08",
                titleEN: "Canonical Equations",
                titleZH: "关键公式",
                subtitleEN: "The compact formal statements that organize the field.",
                tint: AppTheme.accent,
                symbol: "function"
            )

            VStack(spacing: 10) {
                ForEach(Array(report.equations.enumerated()), id: \.offset) { _, equation in
                    EquationCard(equation: equation)
                }
            }
        }
    }

    private var reportFooter: some View {
        VStack(alignment: .leading, spacing: 11) {
            HairlineDivider()
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 5) {
                    Text("关于这份报告 · About this report")
                        .font(AppFont.chinese(11, weight: .semibold))
                    if let caveatEN = report.caveatEN {
                        Text(caveatEN)
                            .font(AppFont.body(10))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let caveatZH = report.caveatZH {
                        Text(caveatZH)
                            .font(AppFont.chinese(10))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("由 \(report.model.isEmpty ? "大语言模型" : report.model) 于 \(report.generatedAt.shortChinese) 生成，并保存在本机。AI 综合内容可能包含滞后、简化或错误，请对照权威综述与原始文献核实关键事实、公式和人物信息。")
                        .font(AppFont.chinese(9.5))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            HStack {
                Text("ENDLESS FRONTIER · \(report.categoryID)")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.quaternary)
                Spacer()
                Text("报告文件：Reports/\(report.categoryID).json")
                    .font(AppFont.mono(8))
                    .foregroundStyle(.quaternary)
            }
            .padding(.top, 2)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func markedText(
        _ text: String,
        fieldID: String,
        size: CGFloat,
        weight: AnnotationFontWeight = .regular,
        tone: AnnotationTextTone = .body,
        lineSpacing: CGFloat
    ) -> some View {
        let style = AnnotationTextStyle(size: size, weight: weight, tone: tone, lineSpacing: lineSpacing)
        let highlights = annotations.highlights(for: fieldID)
        if isAnnotating {
            HighlightableText(
                text: text,
                style: style,
                highlights: highlights,
                onSelect: { range in
                    highlightController.select(fieldID: fieldID, range: range)
                }
            )
        } else {
            ReadOnlyHighlightedText(text: text, style: style, highlights: highlights)
        }
    }

    private func avatarInitial(_ figure: KeyFigure) -> String {
        if let first = figure.nameEN.first {
            return String(first).uppercased()
        }
        if let first = figure.nameZH.first {
            return String(first)
        }
        return "?"
    }
}

struct ReportSectionDescriptor: Identifiable {
    let id: String
    let zh: String
    let en: String
    let symbol: String
    let show: Bool
}

struct ReportSectionHeader: View {
    let number: String
    let titleEN: String
    let titleZH: String
    let subtitleEN: String
    let tint: Color
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.system(size: 31, weight: .light, design: .rounded))
                .foregroundStyle(tint.opacity(0.25))
                .frame(width: 40, alignment: .leading)
                .padding(.top, -3)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Image(systemName: symbol)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(tint)
                    Text(titleEN.uppercased())
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(tint)
                    Text(titleZH)
                        .font(AppFont.chinese(13.5, weight: .semibold))
                }
                Text(subtitleEN)
                    .font(AppFont.body(10.8))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.top, 6)
    }
}
