import SwiftUI
import AppKit

struct KnowledgeTreePage: View {
    @ObservedObject var model: KnowledgeTreeModel
    let category: ArxivCategory

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.openSettings) private var openSettings
    @State private var expandedIDs: Set<String> = []
    @State private var confirmRegenerate = false

    private var tint: Color { AppTheme.groupColor(category.groupID) }

    var body: some View {
        ZStack(alignment: .trailing) {
            content

            if !model.isGeneratingTree, let node = model.selectedNode {
                KnowledgeNodeInspector(
                    model: model,
                    node: node,
                    path: model.selectedPath,
                    category: category
                )
                .frame(width: 382)
                .padding(.trailing, 16)
                .padding(.top, 96)
                .padding(.bottom, 16)
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(20)
            }
        }
        .background(PageBackdrop(tint: tint))
        .confirmationDialog(
            "重新生成知识树？",
            isPresented: $confirmRegenerate,
            titleVisibility: .visible
        ) {
            Button("重新生成并覆盖本地知识树", role: .destructive) {
                model.generateTree(force: true)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("知识树及所有知识点的 AI 深入展开内容都会被替换。此操作由你手动触发，不会自动发生。")
        }
        .onAppear {
            syncExpansion(reset: true)
            #if DEBUG
            if let target = DebugLaunchOptions.knowledgeTreeNodeID,
               model.tree?.node(id: target) != nil {
                model.selectNode(id: target)
            }
            #endif
        }
        .onChange(of: model.tree?.generatedAt) { _, _ in
            syncExpansion(reset: true)
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isGeneratingTree {
            treeGeneratingView
        } else if let tree = model.tree {
            treeBoard(tree)
        } else {
            treeLanding
        }
    }

    private var treeLanding: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let error = model.errorMessage {
                    ErrorBanner(
                        title: "知识树生成失败",
                        message: error,
                        actionTitle: settings.isConfigured ? "重试" : nil,
                        action: settings.isConfigured ? { model.generateTree(force: true) } : nil
                    )
                }

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.17), tint.opacity(0.045), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.background.opacity(0.25))

                    HStack(alignment: .top, spacing: 24) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 7) {
                                Image(systemName: "list.bullet.indent")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("AI KNOWLEDGE TREE")
                                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                    .tracking(1.4)
                                Text("学科知识树")
                                    .font(AppFont.chinese(10.5, weight: .semibold))
                            }
                            .foregroundStyle(tint)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(tint.opacity(0.10), in: Capsule())

                            Text("让 AI 为\(category.nameZH)\n生长一棵知识树")
                                .font(AppFont.display(30, weight: .semibold))
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("A top-down bilingual concept tree for \(category.nameEN): major domains branch into specific knowledge points you can open and explore further.")
                                .font(AppFont.body(12.5))
                                .foregroundStyle(.secondary)
                                .lineSpacing(3)
                                .frame(maxWidth: 540, alignment: .leading)

                            HStack(spacing: 10) {
                                if settings.isConfigured {
                                    Button {
                                        model.generateTree()
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "sparkles")
                                            Text("生成知识树")
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
                                        Label("配置模型以启用", systemImage: "key.horizontal")
                                    }
                                    .buttonStyle(PrimaryActionButtonStyle(tint: tint))
                                }

                                Label("自动保存在本机", systemImage: "internaldrive")
                                    .font(AppFont.chinese(10))
                                    .foregroundStyle(.secondary)
                            }

                            Text("手动触发 · 通常需要 1–3 分钟 · 只使用你配置的大语言模型，不会自动重复生成")
                                .font(AppFont.mono(9.2))
                                .foregroundStyle(.tertiary)
                        }
                        Spacer(minLength: 0)
                        KnowledgeTreeMotif(tint: tint)
                            .frame(width: 260, height: 215)
                            .padding(.top, 2)
                    }
                    .padding(26)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(tint.opacity(0.14), lineWidth: 1)
                }

                VStack(alignment: .leading, spacing: 11) {
                    SectionLabel(english: "How the tree works", chinese: "知识树如何生长", symbol: "point.topleft.down.to.point.bottomright.curvepath")
                        .padding(.horizontal, 2)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 10)], spacing: 10) {
                        treeFeature("list.bullet.indent", "顶向下层级", "Top-down hierarchy", "从学科根节点逐层展开核心领域与知识点。")
                        treeFeature("character.book.closed", "中英双语", "Bilingual concepts", "每个知识点都保留英文名与中文名，摘要同样双语。")
                        treeFeature("sparkles", "节点可深入", "AI node expansion", "对任一知识点手动生成概念定义、相关知识、核心人物和应用场景。")
                        treeFeature("internaldrive", "仅保存在本机", "Saved locally", "生成结果按学科保存，重新打开无需再次生成，可手动重新生成。")
                    }
                }

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                    Text("知识树的层级与知识点由大语言模型综合生成，可能存在遗漏或错误。关键概念、人物与应用请结合权威教材和原始文献核实。")
                        .font(AppFont.chinese(10))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 3)
            }
            .padding(24)
            .frame(maxWidth: 1_020)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.automatic)
    }

    private func treeFeature(_ symbol: String, _ zh: String, _ en: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(zh)
                        .font(AppFont.chinese(11.5, weight: .semibold))
                    Text(en)
                        .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
                Text(detail)
                    .font(AppFont.chinese(10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 67, alignment: .topLeading)
        .background(Color.primary.opacity(0.026), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        }
    }

    private var treeGeneratingView: some View {
        VStack(spacing: 22) {
            Spacer()
            VStack(spacing: 22) {
                GrowingTreeMotif(tint: tint)
                    .frame(width: 240, height: 165)

                VStack(spacing: 7) {
                    Text(model.stageText)
                        .font(AppFont.chinese(18, weight: .semibold))
                    Text("\(category.nameZH) · \(category.id) · \(model.elapsedText)")
                        .font(AppFont.mono(9.5))
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 10) {
                    Button("取消生成") { model.cancelTreeGeneration() }
                        .buttonStyle(SecondaryActionButtonStyle())
                    Text("已接收 \(model.streamedCharacters.formatted()) 字符")
                        .font(AppFont.mono(9))
                        .foregroundStyle(.tertiary)
                        .contentTransition(.numericText())
                }

                Text("知识树生成后会自动保存在本机。请保持应用运行，通常需要 1–3 分钟。")
                    .font(AppFont.chinese(9.5))
                    .foregroundStyle(.tertiary)
            }
            .padding(34)
            .frame(maxWidth: 540)
            .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(tint.opacity(0.13), lineWidth: 1)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RadialGradient(colors: [tint.opacity(0.09), .clear], center: .center, startRadius: 20, endRadius: 500)
        }
    }

    private func treeBoard(_ tree: KnowledgeTree) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let error = model.errorMessage {
                    ErrorBanner(
                        title: "上一次知识树生成未完成",
                        message: error,
                        actionTitle: settings.isConfigured ? "重试" : nil,
                        action: settings.isConfigured ? { model.generateTree(force: true) } : nil
                    )
                }

                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 7) {
                            Image(systemName: "list.bullet.indent")
                                .font(.system(size: 10, weight: .semibold))
                            Text("AI KNOWLEDGE TREE")
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .tracking(1.4)
                            Text("学科知识树")
                                .font(AppFont.chinese(10.5, weight: .semibold))
                        }
                        .foregroundStyle(tint)

                        Text("\(category.nameEN) Knowledge Tree")
                            .font(AppFont.display(24, weight: .semibold))
                        Text("\(category.nameZH)知识树")
                            .font(AppFont.chinese(13, weight: .medium))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            Text("\(tree.nodeCount) 个知识点")
                            Text("·")
                            Text("生成于 \(tree.generatedAt.shortChinese) \(tree.generatedAt.formatted(date: .omitted, time: .shortened))")
                            Text("·")
                            Text(tree.model)
                                .font(AppFont.mono(8.5))
                            Text("·")
                            Text("仅保存在本机")
                        }
                        .font(AppFont.chinese(9.3))
                        .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    HStack(spacing: 7) {
                        Button {
                            expandedIDs = tree.expandableNodeIDs
                        } label: {
                            Label("全部展开", systemImage: "arrow.down.right.and.arrow.up.left")
                        }
                        .buttonStyle(SecondaryActionButtonStyle())

                        Button {
                            expandedIDs = []
                        } label: {
                            Label("全部收起", systemImage: "arrow.up.left.and.arrow.down.right")
                        }
                        .buttonStyle(SecondaryActionButtonStyle())

                        Button {
                            confirmRegenerate = true
                        } label: {
                            Label("重新生成", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                        .disabled(model.isExpanding || !settings.isConfigured)
                        .help(settings.isConfigured ? "重新生成会替换知识树及节点展开内容" : "请先配置模型")
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: "cursorarrow.click.2")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(tint)
                    Text("点击知识点在右侧查看详情；可手动使用 AI 深入展开概念定义、相关知识、核心人物和应用场景。")
                        .font(AppFont.chinese(9.8))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 2)

                VStack(alignment: .leading, spacing: 3) {
                    KnowledgeTreeBranchView(
                        node: tree.root,
                        depth: 0,
                        selectedID: model.selectedNodeID,
                        expandedIDs: expandedIDs,
                        expandingNodeID: model.expandingNodeID,
                        tint: tint,
                        onToggle: { id in
                            if expandedIDs.contains(id) { expandedIDs.remove(id) }
                            else { expandedIDs.insert(id) }
                        },
                        onSelect: { model.selectNode(id: $0) }
                    )
                }
                .padding(17)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.018), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                }

                Text("知识树与节点展开内容仅保存在本机：KnowledgeTrees/\(category.id).json")
                    .font(AppFont.mono(8.5))
                    .foregroundStyle(.quaternary)
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .frame(maxWidth: 1_040)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.automatic)
    }

    private func syncExpansion(reset: Bool) {
        guard reset else { return }
        if let tree = model.tree {
            expandedIDs = tree.expandableNodeIDs
        } else {
            expandedIDs = []
        }
    }
}

// MARK: - Recursive tree rows

private struct KnowledgeTreeBranchView: View {
    let node: KnowledgeTreeNode
    let depth: Int
    let selectedID: String?
    let expandedIDs: Set<String>
    let expandingNodeID: String?
    let tint: Color
    let onToggle: (String) -> Void
    let onSelect: (String) -> Void

    private var isExpanded: Bool { expandedIDs.contains(node.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Button {
                    onSelect(node.id)
                } label: {
                    KnowledgeTreeNodeCard(
                        node: node,
                        depth: depth,
                        isSelected: selectedID == node.id,
                        isExpanding: expandingNodeID == node.id,
                        tint: tint
                    )
                }
                .buttonStyle(.plain)

                if !node.children.isEmpty {
                    Button {
                        onToggle(node.id)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .frame(width: 24, height: 24)
                            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help(isExpanded ? "收起分支" : "展开分支")
                    .padding(.top, 10)
                }
            }

            if isExpanded, !node.children.isEmpty {
                HStack(alignment: .top, spacing: 0) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.10))
                        .frame(width: 1)
                        .padding(.leading, 16)
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(node.children) { child in
                            AnyView(KnowledgeTreeBranchView(
                                node: child,
                                depth: depth + 1,
                                selectedID: selectedID,
                                expandedIDs: expandedIDs,
                                expandingNodeID: expandingNodeID,
                                tint: tint,
                                onToggle: onToggle,
                                onSelect: onSelect
                            ))
                        }
                    }
                    .padding(.leading, 14)
                }
                .padding(.top, 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct KnowledgeTreeNodeCard: View {
    let node: KnowledgeTreeNode
    let depth: Int
    let isSelected: Bool
    let isExpanding: Bool
    let tint: Color

    private var isRoot: Bool { depth == 0 }
    private var corner: CGFloat { isRoot ? 14 : 12 }
    private var levelZH: String {
        switch depth {
        case 0: return "学科根节点"
        case 1: return "核心领域"
        case 2: return "知识点"
        default: return "子概念"
        }
    }
    private var levelEN: String {
        switch depth {
        case 0: return "ROOT"
        case 1: return "CORE DOMAIN"
        case 2: return "KNOWLEDGE POINT"
        default: return "SUB-CONCEPT"
        }
    }
    private var levelColor: Color {
        isRoot ? Color.white.opacity(0.75) : tint
    }
    private var levelZhColor: Color {
        isRoot ? Color.white.opacity(0.62) : Color.secondary
    }
    private var childCountColor: Color {
        isRoot ? Color.white.opacity(0.55) : Color.secondary.opacity(0.55)
    }
    private var titleColor: Color {
        isRoot ? Color.white : Color.primary.opacity(0.94)
    }
    private var titleZHColor: Color {
        isRoot ? Color.white.opacity(0.68) : Color.secondary
    }
    private var summaryENColor: Color {
        isRoot ? Color.white.opacity(0.67) : Color.primary.opacity(0.62)
    }
    private var summaryZHColor: Color {
        isRoot ? Color.white.opacity(0.56) : Color.secondary.opacity(0.85)
    }
    private var detailColor: Color {
        isRoot ? AppTheme.gold : AppTheme.gold.opacity(0.9)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            headerRow
            Text(node.nameEN)
                .font(AppFont.display(isRoot ? 20 : 13.5, weight: .semibold))
                .foregroundStyle(titleColor)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(node.nameZH)
                .font(AppFont.chinese(isRoot ? 13 : 11.5, weight: .medium))
                .foregroundStyle(titleZHColor)
                .lineLimit(2)
            summaryBlock
        }
        .padding(isRoot ? 17 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(cardBorder)
        .contentShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .help("点击查看「\(node.nameZH)」详情")
    }

    private var headerRow: some View {
        HStack(spacing: 6) {
            Text(levelEN)
                .font(.system(size: isRoot ? 8 : 7.5, weight: .bold, design: .rounded))
                .tracking(0.9)
                .foregroundStyle(levelColor)
            Text(levelZH)
                .font(AppFont.chinese(9))
                .foregroundStyle(levelZhColor)
            if !node.children.isEmpty {
                Text("· \(node.children.count) 子项")
                    .font(AppFont.chinese(8.5))
                    .foregroundStyle(childCountColor)
            }
            Spacer(minLength: 4)
            if isExpanding {
                ProgressView().controlSize(.mini)
            } else if node.detail != nil {
                Label("AI 已展开", systemImage: "sparkles")
                    .font(AppFont.chinese(8.3, weight: .medium))
                    .foregroundStyle(detailColor)
            }
        }
    }

    @ViewBuilder
    private var summaryBlock: some View {
        if !node.summaryEN.isEmpty || !node.summaryZH.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                if !node.summaryEN.isEmpty {
                    Text(node.summaryEN)
                        .font(AppFont.body(isRoot ? 10.5 : 9.8))
                        .foregroundStyle(summaryENColor)
                        .lineLimit(isRoot ? 2 : 1)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !node.summaryZH.isEmpty {
                    Text(node.summaryZH)
                        .font(AppFont.chinese(isRoot ? 10.2 : 9.5))
                        .foregroundStyle(summaryZHColor)
                        .lineLimit(isRoot ? 2 : 1)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private var cardBackground: some View {
        if isRoot {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.88), tint.opacity(0.56)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(Color.black.opacity(0.10))
                }
        } else {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(Color.primary.opacity(isSelected ? 0.07 : 0.025))
        }
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .strokeBorder(
                isSelected ? tint.opacity(0.8) : (isRoot ? Color.white.opacity(0.16) : Color.primary.opacity(0.06)),
                lineWidth: isSelected ? 1.4 : 1
            )
    }
}

// MARK: - Inspector

private struct KnowledgeNodeInspector: View {
    @ObservedObject var model: KnowledgeTreeModel
    let node: KnowledgeTreeNode
    let path: [KnowledgeTreeNode]
    let category: ArxivCategory

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.openSettings) private var openSettings

    private var tint: Color { AppTheme.groupColor(category.groupID) }
    private var detail: KnowledgeNodeDetail? { node.detail }
    private var isExpandingThisNode: Bool { model.expandingNodeID == node.id }
    private var anotherExpansionRunning: Bool {
        model.expandingNodeID != nil && model.expandingNodeID != node.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("KNOWLEDGE NODE")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(tint)
                Spacer()
                Button {
                    model.selectNode(id: nil)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(Color.primary.opacity(0.05), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 11)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(node.nameEN)
                            .font(AppFont.display(20, weight: .semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(node.nameZH)
                            .font(AppFont.chinese(13.5, weight: .medium))
                            .foregroundStyle(.secondary)
                        if path.count > 1 {
                            Text(path.dropLast().map(\.nameZH).joined(separator: " › "))
                                .font(AppFont.chinese(8.8))
                                .foregroundStyle(.tertiary)
                                .lineLimit(2)
                        }
                    }

                    if !node.summaryEN.isEmpty || !node.summaryZH.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            if !node.summaryEN.isEmpty {
                                Text(node.summaryEN)
                                    .font(AppFont.body(10.8))
                                    .foregroundStyle(.primary.opacity(0.72))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if !node.summaryZH.isEmpty {
                                Text(node.summaryZH)
                                    .font(AppFont.chinese(10.6))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }

                    if isExpandingThisNode {
                        expansionProgress
                    } else if let detail {
                        detailContent(detail)
                    } else {
                        expansionPrompt
                    }

                    if let error = model.expansionError {
                        ErrorBanner(title: "知识点展开失败", message: error)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.never)
        }
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 24, y: 10)
    }

    private var expansionProgress: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                ProgressView().controlSize(.small)
                Text("AI 正在深入展开")
                    .font(AppFont.chinese(11.5, weight: .semibold))
                Spacer()
            }
            Text(model.expansionStageText)
                .font(AppFont.chinese(10.5))
                .foregroundStyle(.secondary)
            Text("已接收 \(model.expansionStreamedCharacters.formatted()) 字符")
                .font(AppFont.mono(8.8))
                .foregroundStyle(.tertiary)
            Button("取消展开") { model.cancelExpansion() }
                .buttonStyle(SecondaryActionButtonStyle())
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.055), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(tint.opacity(0.12), lineWidth: 1)
        }
    }

    private var expansionPrompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("用 AI 展开这个知识点，生成概念定义、相关知识、核心人物与真实应用场景。")
                .font(AppFont.chinese(10.8))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !settings.isConfigured {
                Button {
                    openSettings()
                } label: {
                    Label("配置模型以启用", systemImage: "key.horizontal")
                }
                .buttonStyle(SecondaryActionButtonStyle())
            } else if anotherExpansionRunning {
                Text("另一个知识点正在展开，请稍候。")
                    .font(AppFont.chinese(9.5))
                    .foregroundStyle(.tertiary)
            } else {
                Button {
                    model.expand(nodeID: node.id)
                } label: {
                    Label("AI 深入展开", systemImage: "sparkles")
                }
                .buttonStyle(PrimaryActionButtonStyle(tint: tint))
                .disabled(!model.canExpandSelectedNode)
            }
            Text("手动触发 · 结果自动保存在知识树中")
                .font(AppFont.chinese(8.8))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func detailContent(_ detail: KnowledgeNodeDetail) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            inspectorSection("概念定义", "Definition", "text.book.closed") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(detail.definitionEN)
                        .font(AppFont.body(10.9))
                        .foregroundStyle(.primary.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail.definitionZH)
                        .font(AppFont.chinese(10.7))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !detail.relatedKnowledge.isEmpty {
                inspectorSection("相关知识", "Related Knowledge", "point.3.connected.trianglepath.dotted") {
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(Array(detail.relatedKnowledge.enumerated()), id: \.offset) { _, item in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(item.nameEN)
                                        .font(AppFont.body(10.3, weight: .semibold))
                                    Text(item.nameZH)
                                        .font(AppFont.chinese(9.6))
                                        .foregroundStyle(.secondary)
                                }
                                Text(item.relationEN)
                                    .font(AppFont.body(9.3))
                                    .foregroundStyle(.primary.opacity(0.60))
                                Text(item.relationZH)
                                    .font(AppFont.chinese(9.2))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }

            if !detail.keyFigures.isEmpty {
                inspectorSection("核心人物", "Key Figures", "person.2.wave.2") {
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(Array(detail.keyFigures.enumerated()), id: \.offset) { _, figure in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(figure.nameEN)
                                        .font(AppFont.body(10.3, weight: .semibold))
                                    Text(figure.nameZH)
                                        .font(AppFont.chinese(9.6))
                                        .foregroundStyle(AppTheme.gold)
                                }
                                Text(figure.contributionEN)
                                    .font(AppFont.body(9.3))
                                    .foregroundStyle(.primary.opacity(0.60))
                                Text(figure.contributionZH)
                                    .font(AppFont.chinese(9.2))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }

            if !detail.applications.isEmpty {
                inspectorSection("应用场景", "Applications", "lightbulb") {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(Array(detail.applications.enumerated()), id: \.offset) { _, application in
                            HStack(alignment: .top, spacing: 6) {
                                Circle()
                                    .fill(AppTheme.positive.opacity(0.8))
                                    .frame(width: 3.5, height: 3.5)
                                    .padding(.top, 5)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(application.en)
                                        .font(AppFont.body(9.5))
                                        .foregroundStyle(.primary.opacity(0.65))
                                    Text(application.zh)
                                        .font(AppFont.chinese(9.4))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
            }

            HStack(spacing: 7) {
                Text("\(detail.model.isEmpty ? "AI" : detail.model) · \(detail.generatedAt.shortChinese)")
                    .font(AppFont.mono(8))
                    .foregroundStyle(.quaternary)
                Spacer()
                if !anotherExpansionRunning {
                    Button {
                        model.expand(nodeID: node.id)
                    } label: {
                        Label("重新展开", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .disabled(isExpandingThisNode)
                }
            }
        }
    }

    private func inspectorSection<Content: View>(
        _ zh: String,
        _ en: String,
        _ symbol: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(tint)
                Text(zh)
                    .font(AppFont.chinese(10.5, weight: .semibold))
                Text(en.uppercased())
                    .font(.system(size: 7.3, weight: .bold, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(.tertiary)
            }
            content()
        }
        .padding(.bottom, 2)
    }
}

// MARK: - Decorative tree motifs

private struct KnowledgeTreeMotif: View {
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: w * 0.5, y: 47))
                    path.addLine(to: CGPoint(x: w * 0.20, y: h * 0.55))
                    path.move(to: CGPoint(x: w * 0.5, y: 47))
                    path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.55))
                    path.move(to: CGPoint(x: w * 0.5, y: 47))
                    path.addLine(to: CGPoint(x: w * 0.80, y: h * 0.55))
                }
                .stroke(tint.opacity(0.30), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

                motifNode(w: w * 0.5, h: 47, label: "ROOT", color: tint, prominent: true)
                motifNode(w: w * 0.20, h: h * 0.55, label: "领域", color: AppTheme.cyan)
                motifNode(w: w * 0.50, h: h * 0.55, label: "领域", color: AppTheme.gold)
                motifNode(w: w * 0.80, h: h * 0.55, label: "领域", color: AppTheme.positive)

                Path { path in
                    path.move(to: CGPoint(x: w * 0.20, y: h * 0.62))
                    path.addLine(to: CGPoint(x: w * 0.20, y: h * 0.77))
                    path.move(to: CGPoint(x: w * 0.50, y: h * 0.62))
                    path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.77))
                    path.move(to: CGPoint(x: w * 0.80, y: h * 0.62))
                    path.addLine(to: CGPoint(x: w * 0.80, y: h * 0.77))
                }
                .stroke(tint.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

                motifNode(w: w * 0.20, h: h * 0.84, label: "知识点", color: AppTheme.cyan.opacity(0.7), small: true)
                motifNode(w: w * 0.50, h: h * 0.84, label: "知识点", color: AppTheme.gold.opacity(0.8), small: true)
                motifNode(w: w * 0.80, h: h * 0.84, label: "知识点", color: AppTheme.positive.opacity(0.8), small: true)
            }
        }
        .opacity(0.9)
    }

    private func motifNode(w: CGFloat, h: CGFloat, label: String, color: Color, prominent: Bool = false, small: Bool = false) -> some View {
        VStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color.opacity(prominent ? 0.22 : 0.12))
                .frame(width: small ? 42 : (prominent ? 72 : 58), height: small ? 15 : (prominent ? 22 : 19))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(color.opacity(0.45), lineWidth: 0.8)
                }
            Text(label)
                .font(AppFont.chinese(6.5))
                .foregroundStyle(.tertiary)
        }
        .position(x: w, y: h)
    }
}

private struct GrowingTreeMotif: View {
    let tint: Color
    @State private var pulse = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                let x = [0.22, 0.5, 0.78][index] * 240
                Path { path in
                    path.move(to: CGPoint(x: 120, y: 25))
                    path.addQuadCurve(
                        to: CGPoint(x: x, y: 112),
                        control: CGPoint(x: (120 + x) / 2, y: 55)
                    )
                }
                .stroke(tint.opacity(0.25), lineWidth: 1)
                Circle()
                    .fill(index == 1 ? AppTheme.gold : tint)
                    .frame(width: 9, height: 9)
                    .overlay { Circle().strokeBorder(Color.white.opacity(0.5), lineWidth: 1) }
                    .position(x: x, y: 112)
                    .opacity(pulse ? 0.45 : 1)
                    .animation(.easeInOut(duration: 1.2).repeatForever().delay(Double(index) * 0.2), value: pulse)
            }
            Circle()
                .fill(tint.opacity(0.18))
                .frame(width: 42, height: 42)
                .overlay { Circle().strokeBorder(tint.opacity(0.5), lineWidth: 1) }
                .position(x: 120, y: 25)
            Image(systemName: "list.bullet.indent")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tint)
                .position(x: 120, y: 25)
        }
        .onAppear { pulse = true }
    }
}
