import SwiftUI

struct ExploreView: View {
    @ObservedObject var model: ExploreModel
    let category: ArxivCategory
    @Binding var isAnnotating: Bool
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        ZStack {
            if model.isGenerating {
                GeneratingView(model: model, category: category)
                    .transition(.opacity.combined(with: .scale(scale: 0.99)))
            } else if let report = model.report {
                ReportContentView(
                    report: report,
                    category: category,
                    generationError: model.errorMessage,
                    onRegenerate: { model.generate(force: true) },
                    onRetry: { model.generate(force: true) },
                    isAnnotating: $isAnnotating
                )
                .transition(.opacity)
            } else {
                exploreLanding
            }
        }
        .animation(.easeInOut(duration: 0.24), value: model.isGenerating)
        .animation(.easeInOut(duration: 0.24), value: model.report?.generatedAt)
    }

    private var exploreLanding: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let error = model.errorMessage {
                    ErrorBanner(
                        title: "AI 探索生成失败",
                        message: error,
                        actionTitle: settings.isConfigured ? "重试" : nil,
                        action: settings.isConfigured ? { model.generate(force: true) } : nil
                    )
                }

                landingHero
                modulesGrid
                generationFootnote
            }
            .padding(24)
            .frame(maxWidth: 1040)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.automatic)
    }

    private var landingHero: some View {
        let tint = AppTheme.groupColor(category.groupID)
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.20), tint.opacity(0.055), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.background.opacity(0.28))
            constellation
                .allowsHitTesting(false)

            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 15) {
                    HStack(spacing: 7) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .semibold))
                        Text("AI RESEARCH MAP")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .tracking(1.5)
                        Text("学科全景探索")
                            .font(AppFont.chinese(10.5, weight: .semibold))
                    }
                    .foregroundStyle(tint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(tint.opacity(0.10), in: Capsule())

                    Text("让 AI 为你绘制\n\(category.nameZH)的知识版图")
                        .font(AppFont.display(31, weight: .semibold))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Map the history, unresolved questions, frontiers, people, equations, and interdisciplinary connections of \(category.nameEN).")
                        .font(AppFont.body(13))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                        .frame(maxWidth: 520, alignment: .leading)

                    HStack(spacing: 10) {
                        if settings.isConfigured {
                            Button {
                                model.generate()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "sparkles")
                                    Text("生成学科全景")
                                    Text("Generate")
                                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.62))
                                }
                            }
                            .buttonStyle(PrimaryActionButtonStyle(tint: tint))
                        } else {
                            Button {
                                openSettings()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "key.horizontal")
                                    Text("配置模型以启用")
                                }
                            }
                            .buttonStyle(PrimaryActionButtonStyle(tint: tint))
                        }

                        HStack(spacing: 5) {
                            Image(systemName: "internaldrive")
                            Text("结果自动保存在本地")
                        }
                        .font(AppFont.chinese(10))
                        .foregroundStyle(.secondary)
                    }

                    Text("通常需要 2–5 分钟 · 由 \(settings.isConfigured ? settings.activeModel : "所选大语言模型") 生成 · 不会自动重复生成")
                        .font(AppFont.mono(9.3))
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
                if !settings.isConfigured {
                    unavailableModelCard
                        .frame(maxWidth: 300)
                }
            }
            .padding(26)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(tint.opacity(0.16), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var constellation: some View {
        GeometryReader { proxy in
            let tint = AppTheme.groupColor(category.groupID)
            ZStack {
                ForEach(0..<7, id: \.self) { index in
                    let angle = Double(index) * 0.8
                    let x = proxy.size.width - 150 + cos(angle) * 95
                    let y = proxy.size.height * 0.45 + sin(angle) * 70
                    Circle()
                        .fill(index % 2 == 0 ? tint : AppTheme.gold)
                        .frame(width: index % 2 == 0 ? 4 : 2.5, height: index % 2 == 0 ? 4 : 2.5)
                        .opacity(0.45)
                        .position(x: x, y: y)
                }
                Circle()
                    .strokeBorder(tint.opacity(0.16), lineWidth: 1)
                    .frame(width: 260, height: 260)
                    .position(x: proxy.size.width - 135, y: proxy.size.height * 0.47)
                Circle()
                    .strokeBorder(AppTheme.gold.opacity(0.12), lineWidth: 1)
                    .frame(width: 190, height: 190)
                    .position(x: proxy.size.width - 135, y: proxy.size.height * 0.47)
                OrbitalMark(size: 130, color: tint)
                    .opacity(0.62)
                    .position(x: proxy.size.width - 135, y: proxy.size.height * 0.47)
            }
            .mask(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.9)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
    }

    private var unavailableModelCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "key.horizontal")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.warning)
                Text("需要连接大语言模型")
                    .font(AppFont.chinese(12, weight: .semibold))
            }
            Text(settings.configurationHint)
                .font(AppFont.chinese(11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("打开模型设置") { openSettings() }
                .buttonStyle(SecondaryActionButtonStyle())
            Text("AI 探索为手动触发，只在你点击生成时发送学科名称与分类信息。")
                .font(AppFont.chinese(9.5))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(15)
        .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(AppTheme.warning.opacity(0.15), lineWidth: 1)
        }
    }

    private var modulesGrid: some View {
        let modules: [(String, String, String, String)] = [
            ("clock.arrow.circlepath", "发展历史", "History & Evolution", "从思想源头到当代范式，梳理学科如何形成。"),
            ("questionmark.circle", "未解难题", "Open Problems", "识别真正悬而未决的问题与可能突破的路径。"),
            ("telescope", "前沿进展", "Research Frontiers", "定位当下最活跃的研究方向与方法论变革。"),
            ("lightbulb", "关键成果与应用", "Achievements & Impact", "把标志性成果连接到真实世界的应用场景。"),
            ("person.2.wave.2", "关键人物", "Key Figures", "理解奠基者与推动者的具体贡献。"),
            ("point.3.connected.trianglepath.dotted", "交叉关系", "Interdisciplinary Links", "构建与其他学科的双向知识关联。"),
            ("character.book.closed", "关键名词", "Key Concepts", "以双语解释领域内最重要的术语。"),
            ("function", "关键公式", "Equations", "呈现核心方程、含义与适用边界。")
        ]
        return VStack(alignment: .leading, spacing: 12) {
            SectionLabel(english: "What you will get", chinese: "报告包含", symbol: "square.grid.2x2")
                .padding(.horizontal, 2)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 235), spacing: 10)], spacing: 10) {
                ForEach(Array(modules.enumerated()), id: \.offset) { index, module in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: module.0)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.groupColor(category.groupID))
                            .frame(width: 27, height: 27)
                            .background(AppTheme.groupColor(category.groupID).opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 5) {
                                Text(module.1)
                                    .font(AppFont.chinese(12, weight: .semibold))
                                Text(module.2)
                                    .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.tertiary)
                            }
                            Text(module.3)
                                .font(AppFont.chinese(10.5))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(11)
                    .frame(maxWidth: .infinity, minHeight: 68, alignment: .topLeading)
                    .background(Color.primary.opacity(0.026), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
                    }
                }
            }
        }
    }

    private var generationFootnote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
            Text("报告由大语言模型基于其训练知识严谨综合生成，可能存在滞后或错误；关键事实、公式与人物信息请以原始文献与权威资料为准。报告生成后自动保存在本机，切换分类或重启应用都不会丢失。")
                .font(AppFont.chinese(10))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 3)
    }
}

struct GeneratingView: View {
    @ObservedObject var model: ExploreModel
    let category: ArxivCategory
    @State private var spin = false

    private let stages: [(String, String, Int)] = [
        ("梳理学科起源与发展脉络", "Mapping origins and evolution", 0),
        ("辨识未解难题与前沿方向", "Locating open problems and frontiers", 1_400),
        ("整理关键成果、人物与应用", "Tracing landmark results and people", 4_000),
        ("建立交叉关系与术语体系", "Building interdisciplinary links", 7_000),
        ("校验公式并生成双语报告", "Validating equations and bilingual text", 10_500)
    ]

    var body: some View {
        let tint = AppTheme.groupColor(category.groupID)
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .strokeBorder(tint.opacity(0.10), lineWidth: 1)
                        .frame(width: 184, height: 184)
                    Circle()
                        .trim(from: 0, to: max(0.035, model.progressFraction))
                        .stroke(
                            AngularGradient(colors: [tint, AppTheme.cyan, AppTheme.gold, tint], center: .center),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                        )
                        .frame(width: 156, height: 156)
                        .rotationEffect(.degrees(-90))
                    Circle()
                        .strokeBorder(tint.opacity(0.18), lineWidth: 0.7)
                        .frame(width: 112, height: 112)
                        .rotationEffect(.degrees(spin ? 360 : 0))
                    OrbitalMark(size: 70, color: tint)
                        .scaleEffect(1.25)
                    Circle()
                        .fill(AppTheme.gold)
                        .frame(width: 5, height: 5)
                        .glow(color: AppTheme.gold, radius: 6)
                        .offset(y: -92)
                        .rotationEffect(.degrees(spin ? 360 : 0))
                }
                .frame(height: 190)
                .onAppear {
                    withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) {
                        spin = true
                    }
                }

                VStack(spacing: 7) {
                    Text(model.stageText)
                        .font(AppFont.chinese(19, weight: .semibold))
                    Text(model.stageDetail.uppercased())
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(tint)
                    Text("\(category.nameZH) · \(category.id) · \(model.elapsedText)")
                        .font(AppFont.mono(10))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }

                VStack(spacing: 8) {
                    ForEach(Array(stages.enumerated()), id: \.offset) { index, stage in
                        HStack(spacing: 9) {
                            Group {
                                if model.streamedCharacters >= nextThreshold(index) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppTheme.positive)
                                } else if isCurrent(index) {
                                    ProgressView().controlSize(.mini)
                                } else {
                                    Circle().strokeBorder(Color.primary.opacity(0.18), lineWidth: 1)
                                }
                            }
                            .font(.system(size: 11))
                            .frame(width: 13, height: 13)
                            Text(stage.0)
                                .font(AppFont.chinese(11.5, weight: isCurrent(index) ? .semibold : .regular))
                                .foregroundStyle(isCurrent(index) ? .primary : .secondary)
                            Text(stage.1)
                                .font(.system(size: 9, weight: .regular, design: .rounded))
                                .foregroundStyle(.tertiary)
                            Spacer()
                        }
                        .frame(width: 380)
                    }
                }
                .padding(.top, 3)

                HStack(spacing: 10) {
                    Button("取消生成") { model.cancel() }
                        .buttonStyle(SecondaryActionButtonStyle())
                    Text("已接收 \(model.streamedCharacters.formatted()) 字符")
                        .font(AppFont.mono(9))
                        .foregroundStyle(.tertiary)
                        .contentTransition(.numericText())
                }
                .padding(.top, 2)

                Text("报告生成后会自动保存。生成期间请勿关闭应用，通常需要 2–5 分钟。")
                    .font(AppFont.chinese(9.5))
                    .foregroundStyle(.tertiary)
            }
            .padding(36)
            .frame(maxWidth: 560)
            .background(.background.opacity(0.48), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(tint.opacity(0.12), lineWidth: 1)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RadialGradient(
                colors: [tint.opacity(0.10), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 520
            )
        }
    }

    private func isCurrent(_ index: Int) -> Bool {
        let count = model.streamedCharacters
        let start = stages[index].2
        let end = index + 1 < stages.count ? stages[index + 1].2 : Int.max
        return count >= start && count < end
    }

    private func nextThreshold(_ index: Int) -> Int {
        index + 1 < stages.count ? stages[index + 1].2 : Int.max
    }
}

private extension View {
    func glow(color: Color, radius: CGFloat) -> some View {
        shadow(color: color.opacity(0.7), radius: radius)
    }
}
