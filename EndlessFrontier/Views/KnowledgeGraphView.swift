import SwiftUI

struct KnowledgeGraphView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var reports: ReportStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var graph = KnowledgeGraph(nodes: [], edges: [])
    @State private var selectedID: String?
    @State private var hoveredID: String?
    @State private var search = ""
    @State private var scale: CGFloat = 0.9
    @State private var pan: CGSize = .zero
    @State private var viewport: CGSize = .zero
    @GestureState private var dragTranslation: CGSize = .zero
    @GestureState private var magnification: CGFloat = 1
    @FocusState private var searchFocused: Bool

    private let contentSize = CGSize(width: 1_440, height: 920)
    private let minScale: CGFloat = 0.30
    private let maxScale: CGFloat = 1.75

    private var fingerprint: String {
        reports.reports.values
            .sorted { $0.categoryID < $1.categoryID }
            .map { "\($0.categoryID):\(Int($0.generatedAt.timeIntervalSince1970)):\($0.relations.count)" }
            .joined(separator: "|")
    }

    private var selectedNode: KnowledgeNode? {
        guard let selectedID else { return nil }
        return graph.nodes.first { $0.id == selectedID }
    }

    private var selectedEdges: [KnowledgeEdge] {
        guard let selectedID else { return [] }
        return graph.edges.filter { $0.source == selectedID || $0.target == selectedID }
    }

    private var searchMatches: [KnowledgeNode] {
        let needle = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return [] }
        return graph.nodes.filter {
            $0.category.nameEN.lowercased().contains(needle)
                || $0.category.nameZH.contains(needle)
                || $0.category.id.lowercased().contains(needle)
        }
        .sorted { $0.category.nameEN < $1.category.nameEN }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            HairlineDivider().opacity(0.55)
            GeometryReader { proxy in
                ZStack {
                    dotGrid
                    Color.clear
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .overlay {
                            graphCanvas(in: proxy.size)
                        }
                        .clipped()
                    if let node = selectedNode {
                        inspector(node: node, container: proxy.size)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                            .zIndex(20)
                    }
                    graphOverlays(container: proxy.size)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .onAppear {
                    viewport = proxy.size
                    initialViewportFit(in: proxy.size)
                }
                .onChange(of: proxy.size) { _, newSize in
                    viewport = newSize
                    initialViewportFit(in: newSize)
                }
            }
        }
        .background(PageBackdrop())
        .navigationTitle("学科交叉知识图谱")
        .navigationSubtitle("Interdisciplinary Knowledge Graph")
        .onAppear {
            rebuildGraph()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                handleExternalFocus()
            }
        }
        .onChange(of: fingerprint) { _, _ in
            rebuildGraph()
        }
        .onChange(of: appState.graphFocusCategory) { _, _ in
            handleExternalFocus()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("学科交叉知识图谱")
                        .font(AppFont.display(23, weight: .semibold))
                    Text("INTERDISCIPLINARY KNOWLEDGE GRAPH")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(AppTheme.accent.opacity(0.08), in: Capsule())
                }
                HStack(spacing: 12) {
                    Label("\(graph.nodes.count) 学科节点", systemImage: "circle.hexagongrid")
                    Label("\(graph.edges.count) 条交叉关系", systemImage: "point.3.connected.trianglepath.dotted")
                    Label("\(reports.count) 份 AI 档案", systemImage: "sparkles")
                }
                .font(AppFont.chinese(9.5))
                .foregroundStyle(.secondary)
            }
            Spacer()
            searchControl
            Button {
                fitGraph()
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 10.5, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .frame(width: 27, height: 26)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .help("适应窗口 Fit graph")
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 13)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.72))
        .zIndex(5)
    }

    private var searchControl: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("搜索节点 Search nodes", text: $search)
                .textFieldStyle(.plain)
                .font(AppFont.chinese(11))
                .focused($searchFocused)
            if !search.isEmpty {
                Button {
                    search = ""
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
        .frame(width: 210)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(searchFocused ? AppTheme.accent.opacity(0.35) : Color.primary.opacity(0.06), lineWidth: 1)
        }
        .overlay(alignment: .topLeading) {
            if !searchMatches.isEmpty {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(searchMatches.prefix(6)) { node in
                        Button {
                            search = ""
                            searchFocused = false
                            select(node: node, shouldFocus: true)
                        } label: {
                            HStack(spacing: 7) {
                                Circle()
                                    .fill(node.color)
                                    .frame(width: 5, height: 5)
                                Text(node.category.nameEN)
                                    .font(AppFont.body(10.5, weight: .medium))
                                Text(node.category.nameZH)
                                    .font(AppFont.chinese(9.5))
                                    .foregroundStyle(.secondary)
                                Spacer(minLength: 2)
                                Text(node.category.id)
                                    .font(AppFont.mono(8))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .frame(width: 330)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.14), radius: 16, y: 8)
                .offset(y: 32)
                .zIndex(60)
            }
        }
        .zIndex(60)
    }

    private var dotGrid: some View {
        Canvas { context, size in
            let spacing: CGFloat = 25
            let color = colorScheme == .dark ? Color.white.opacity(0.050) : Color.black.opacity(0.060)
            var y: CGFloat = spacing
            while y < size.height {
                var x: CGFloat = spacing
                while x < size.width {
                    let rect = CGRect(x: x, y: y, width: 1.2, height: 1.2)
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                    x += spacing
                }
                y += spacing
            }
        }
        .background {
            RadialGradient(
                colors: [AppTheme.accent.opacity(0.055), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 700
            )
        }
        .allowsHitTesting(false)
    }

    private func graphCanvas(in size: CGSize) -> some View {
        let effectiveScale = clampScale(scale * magnification)
        return ZStack {
            edgesLayer

            ForEach(graph.nodes) { node in
                GraphNodeCard(
                    node: node,
                    isSelected: selectedID == node.id,
                    isHovered: hoveredID == node.id,
                    hasReport: reports.report(for: node.id) != nil
                ) {
                    select(node: node, shouldFocus: false)
                }
                .onHover { hovering in
                    hoveredID = hovering ? node.id : (hoveredID == node.id ? nil : hoveredID)
                }
                .position(node.position)
                .zIndex(selectedID == node.id ? 10 : 4)
                .contextMenu {
                    Button("AI 探索 \(node.category.nameZH)") {
                        appState.openCategory(node.id, tab: .explore)
                    }
                    Button("知识树") {
                        appState.openCategory(node.id, tab: .knowledgeTree)
                    }
                    Button("浏览论文") {
                        appState.openCategory(node.id, tab: .papers)
                    }
                }
                .help("\(node.category.nameEN) / \(node.category.nameZH) · \(node.category.id)")
            }

        }
        .frame(width: contentSize.width, height: contentSize.height)
        .scaleEffect(effectiveScale)
        .offset(x: pan.width + dragTranslation.width, y: pan.height + dragTranslation.height)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 4)
                .updating($dragTranslation) { value, state, _ in
                    state = value.translation
                }
                .onEnded { value in
                    pan.width += value.translation.width
                    pan.height += value.translation.height
                }
        )
        .simultaneousGesture(
            MagnifyGesture(minimumScaleDelta: 0.01)
                .updating($magnification) { value, state, _ in
                    state = value.magnification
                }
                .onEnded { value in
                    scale = clampScale(scale * value.magnification)
                }
        )
    }

    private var edgesLayer: some View {
        Canvas { context, _ in
            for edge in graph.edges {
                guard let from = graph.nodes.first(where: { $0.id == edge.source }),
                      let to = graph.nodes.first(where: { $0.id == edge.target }) else { continue }
                let selected = selectedID.map { edge.source == $0 || edge.target == $0 } ?? false
                let hovered = hoveredID.map { edge.source == $0 || edge.target == $0 } ?? false
                let isActive = selected || hovered
                let baseColor = from.color
                let color = isActive
                    ? baseColor.opacity(selected ? 0.82 : 0.62)
                    : baseColor.opacity(colorScheme == .dark ? 0.17 : 0.24)
                let lineWidth = isActive ? CGFloat(1.0 + Double(edge.strength) * 0.6) : CGFloat(0.7 + Double(edge.strength) * 0.26)
                let path = curvedPath(from: from.position, to: to.position, source: edge.source, target: edge.target)
                if isActive {
                    context.stroke(path, with: .color(baseColor.opacity(0.08)), lineWidth: lineWidth + 7)
                }
                context.stroke(
                    path,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: edge.isAI ? [3.5, 3.5] : [])
                )
            }
        }
        .allowsHitTesting(false)
    }

    private func graphOverlays(container: CGSize) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            HStack(alignment: .bottom) {
                legend
                Spacer(minLength: 8)
                hint
                Spacer(minLength: 8)
                zoomControls
            }
            .padding(16)
        }
        .frame(width: container.width, height: container.height, alignment: .bottom)
        .allowsHitTesting(true)
        .zIndex(15)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Text("学科群")
                    .font(AppFont.chinese(9.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("GROUPS")
                    .font(.system(size: 7.5, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.tertiary)
            }
            LazyVGrid(columns: [GridItem(.fixed(116), alignment: .leading), GridItem(.fixed(116), alignment: .leading)], alignment: .leading, spacing: 4) {
                ForEach(ArxivTaxonomy.groups) { group in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(group.color)
                            .frame(width: 4.5, height: 4.5)
                        Text(group.nameZH)
                            .font(AppFont.chinese(9))
                            .foregroundStyle(.primary.opacity(0.72))
                        Text(group.nameEN.split(separator: " ").first.map(String.init) ?? group.nameEN)
                            .font(.system(size: 7.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        }
    }

    private var hint: some View {
        HStack(spacing: 5) {
            Image(systemName: "hand.draw")
                .font(.system(size: 8.5))
            Text("拖拽平移 · 双指缩放 · 点击节点")
                .font(AppFont.chinese(8.8))
            Text("·")
                .foregroundStyle(.quaternary)
            Text("AI 报告会补充新节点")
                .font(AppFont.chinese(8.8))
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
        .overlay { Capsule().strokeBorder(Color.primary.opacity(0.06), lineWidth: 1) }
    }

    private var zoomControls: some View {
        HStack(spacing: 1) {
            controlButton("minus") { scale = clampScale(scale / 1.18) }
            divider
            controlButton("plus") { scale = clampScale(scale * 1.18) }
            divider
            controlButton("arrow.up.left.and.arrow.down.right") { fitGraph() }
            divider
            controlButton("scope") { centerSelectedOrReset() }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(width: 1, height: 14)
    }

    private func controlButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func inspector(node: KnowledgeNode, container: CGSize) -> some View {
        let group = node.group
        let neighbors = neighborDetails(for: node.id)
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("DISCIPLINE NODE")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(node.color)
                Spacer()
                Button {
                    withAnimation(.snappy(duration: 0.2)) { selectedID = nil }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(Color.primary.opacity(0.05), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 12)

            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(node.color)
                    .frame(width: 4, height: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text(node.category.nameEN)
                        .font(AppFont.display(18, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(node.category.nameZH)
                        .font(AppFont.chinese(13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 5) {
                Chip(text: node.category.id, tint: node.color, monospaced: true)
                if let group {
                    Text(group.nameZH)
                        .font(AppFont.chinese(9.5))
                        .foregroundStyle(.secondary)
                    Text(group.nameEN)
                        .font(.system(size: 8.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .padding(.top, 8)

            if reports.report(for: node.id) != nil {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 8.5, weight: .semibold))
                    Text("已有 AI 学科档案")
                        .font(AppFont.chinese(9.5, weight: .medium))
                }
                .foregroundStyle(AppTheme.gold)
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(AppTheme.gold.opacity(0.09), in: Capsule())
                .padding(.top, 9)
            }

            Text("这个学科与 \(neighbors.count) 个学科存在直接交叉关系。点击下方节点可沿图谱继续探索。")
                .font(AppFont.chinese(10.5))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            VStack(spacing: 7) {
                Button {
                    appState.openCategory(node.id, tab: .explore)
                } label: {
                    Label("AI 探索", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle(tint: node.color))

                HStack(spacing: 7) {
                    Button {
                        appState.openCategory(node.id, tab: .knowledgeTree)
                    } label: {
                        Label("知识树", systemImage: "list.bullet.indent")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryActionButtonStyle())

                    Button {
                        appState.openCategory(node.id, tab: .papers)
                    } label: {
                        Label("论文", systemImage: "doc.text")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
            }
            .padding(.top, 12)

            HairlineDivider()
                .padding(.vertical, 13)

            HStack {
                Text("直接关联")
                    .font(AppFont.chinese(10, weight: .semibold))
                Text("CONNECTIONS")
                    .font(.system(size: 7.5, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("\(neighbors.count)")
                    .font(AppFont.mono(8.5))
                    .foregroundStyle(.tertiary)
            }
            .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(neighbors) { item in
                        Button {
                            if let target = graph.nodes.first(where: { $0.id == item.id }) {
                                select(node: target, shouldFocus: true)
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 7) {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 5, height: 5)
                                    .padding(.top, 5)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(item.nameEN)
                                            .font(AppFont.body(10.5, weight: .semibold))
                                        Text(item.nameZH)
                                            .font(AppFont.chinese(9.5))
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(item.relationEN)
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    if !item.relationZH.isEmpty {
                                        Text(item.relationZH)
                                            .font(AppFont.chinese(9))
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(.quaternary)
                                    .padding(.top, 4)
                            }
                            .padding(7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.never)
        }
        .padding(16)
        .frame(width: 292)
        .frame(maxHeight: min(container.height - 34, 620), alignment: .top)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
        .padding(.trailing, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
    }

    private struct NeighborDetail: Identifiable {
        let id: String
        let nameEN: String
        let nameZH: String
        let relationEN: String
        let relationZH: String
        let color: Color
    }

    private func neighborDetails(for nodeID: String) -> [NeighborDetail] {
        var seen = Set<String>()
        var result: [NeighborDetail] = []
        for edge in selectedEdges {
            let otherID = edge.source == nodeID ? edge.target : edge.source
            guard seen.insert(otherID).inserted,
                  let node = graph.nodes.first(where: { $0.id == otherID }) else { continue }
            result.append(NeighborDetail(
                id: otherID,
                nameEN: node.category.nameEN,
                nameZH: node.category.nameZH,
                relationEN: edge.relationEN,
                relationZH: edge.relationZH,
                color: node.color
            ))
        }
        return result.sorted { $0.nameEN < $1.nameEN }
    }

    private func select(node: KnowledgeNode, shouldFocus: Bool) {
        withAnimation(.snappy(duration: 0.22)) {
            selectedID = node.id
        }
        if shouldFocus {
            focusNode(on: node)
        }
    }

    private func focusNode(on node: KnowledgeNode) {
        guard viewport.width > 0, viewport.height > 0 else { return }
        let newScale = clampScale(max(scale, 0.92))
        let centerX = contentSize.width / 2
        let centerY = contentSize.height / 2
        withAnimation(.snappy(duration: 0.35)) {
            scale = newScale
            pan = CGSize(
                width: (centerX - node.position.x) * newScale,
                height: (centerY - node.position.y) * newScale
            )
            if selectedID != node.id { selectedID = node.id }
        }
    }

    private func fitGraph() {
        guard viewport.width > 0, viewport.height > 0 else { return }
        let fit = min(viewport.width / contentSize.width, (viewport.height - 30) / contentSize.height) * 0.94
        withAnimation(.snappy(duration: 0.35)) {
            scale = clampScale(fit)
            pan = .zero
        }
    }

    private func initialViewportFit(in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let fit = min(size.width / contentSize.width, (size.height - 26) / contentSize.height)
        scale = clampScale(fit * 0.96)
        pan = .zero
    }

    private func centerSelectedOrReset() {
        if let node = selectedNode {
            focusNode(on: node)
        } else {
            fitGraph()
        }
    }

    private func clampScale(_ value: CGFloat) -> CGFloat {
        min(max(value, minScale), maxScale)
    }

    private func rebuildGraph() {
        let built = KnowledgeGraph.build(reports: reports.reports)
        graph = built
        if let selectedID, !built.nodes.contains(where: { $0.id == selectedID }) {
            self.selectedID = nil
        }
    }

    private func handleExternalFocus() {
        guard let target = appState.graphFocusCategory else { return }
        guard let node = graph.nodes.first(where: { $0.id == target }) else { return }
        selectedID = node.id
        DispatchQueue.main.async {
            focusNode(on: node)
            appState.graphFocusCategory = nil
        }
    }

    private func curvedPath(from: CGPoint, to: CGPoint, source: String, target: String) -> Path {
        var path = Path()
        path.move(to: from)
        let dx = to.x - from.x
        let dy = to.y - from.y
        let length = max(sqrt(dx * dx + dy * dy), 1)
        let curvature = CGFloat(sin(Double((source + target).unicodeScalars.reduce(0) { $0 + Int($1.value) }))) * 24
        let normal = CGPoint(x: -dy / length, y: dx / length)
        let control = CGPoint(
            x: (from.x + to.x) / 2 + normal.x * curvature,
            y: (from.y + to.y) / 2 + normal.y * curvature
        )
        path.addQuadCurve(to: to, control: control)
        return path
    }
}

struct GraphNodeCard: View {
    let node: KnowledgeNode
    let isSelected: Bool
    let isHovered: Bool
    let hasReport: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 1.5) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(node.color)
                        .frame(width: 4, height: 4)
                    Text(node.category.id)
                        .font(AppFont.mono(7.8, weight: .semibold))
                        .foregroundStyle(isSelected ? node.color : .secondary)
                    Spacer(minLength: 2)
                    if hasReport {
                        Image(systemName: "sparkles")
                            .font(.system(size: 6.5, weight: .semibold))
                            .foregroundStyle(AppTheme.gold)
                    }
                }
                Text(node.category.nameEN)
                    .font(AppFont.body(10.8, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.94))
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)
                Text(node.category.nameZH)
                    .font(AppFont.chinese(9.2))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .frame(width: 158, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(node.color.opacity(isSelected ? 0.18 : (isHovered ? 0.11 : 0.070)))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        node.color.opacity(isSelected ? 0.95 : (isHovered ? 0.52 : 0.26)),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
            .shadow(
                color: isSelected ? node.color.opacity(0.28) : Color.black.opacity(0.075),
                radius: isSelected ? 14 : 6,
                y: isSelected ? 5 : 2
            )
            .scaleEffect(isSelected ? 1.06 : (isHovered ? 1.025 : 1))
            .animation(.snappy(duration: 0.18), value: isSelected)
            .animation(.easeOut(duration: 0.14), value: isHovered)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
