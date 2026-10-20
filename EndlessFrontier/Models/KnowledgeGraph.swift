import SwiftUI

struct KnowledgeNode: Identifiable {
    let id: String
    let category: ArxivCategory
    let group: CategoryGroup?
    var position: CGPoint
    var hasAIReport: Bool
    var isSeed: Bool

    var color: Color {
        AppTheme.groupColor(category.groupID)
    }
}

struct KnowledgeEdge: Identifiable {
    let source: String
    let target: String
    var relationEN: String
    var relationZH: String
    var strength: Int
    var isAI: Bool

    var id: String {
        source < target ? "\(source)|\(target)" : "\(target)|\(source)"
    }
}

struct KnowledgeGraph {
    var nodes: [KnowledgeNode]
    var edges: [KnowledgeEdge]

    var nodeLookup: [String: KnowledgeNode] {
        Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
    }

    func neighbors(of nodeID: String) -> [KnowledgeEdge] {
        edges.filter { $0.source == nodeID || $0.target == nodeID }
    }

    func hasReport(_ id: String) -> Bool {
        nodes.first(where: { $0.id == id })?.hasAIReport ?? false
    }

    static func build(reports: [String: AIReport]) -> KnowledgeGraph {
        var nodeIDs = Set(seedNodeIDs)
        var edgeMap: [String: KnowledgeEdge] = [:]

        for seed in seedEdges {
            guard ArxivTaxonomy.category(seed.0) != nil,
                  ArxivTaxonomy.category(seed.1) != nil else { continue }
            let key = KnowledgeEdge(source: seed.0, target: seed.1, relationEN: "", relationZH: "", strength: seed.4, isAI: false).id
            edgeMap[key] = KnowledgeEdge(
                source: seed.0,
                target: seed.1,
                relationEN: seed.2,
                relationZH: seed.3,
                strength: seed.4,
                isAI: false
            )
        }

        for report in reports.values {
            guard ArxivTaxonomy.category(report.categoryID) != nil else { continue }
            nodeIDs.insert(report.categoryID)
            for relation in report.relations {
                guard ArxivTaxonomy.category(relation.categoryID) != nil else { continue }
                nodeIDs.insert(relation.categoryID)
                let edge = KnowledgeEdge(
                    source: report.categoryID,
                    target: relation.categoryID,
                    relationEN: relation.relationEN,
                    relationZH: relation.relationZH,
                    strength: relation.strength,
                    isAI: true
                )
                if let existing = edgeMap[edge.id] {
                    if existing.relationEN != edge.relationEN {
                        edgeMap[edge.id]?.relationEN = existing.relationEN + " · " + edge.relationEN
                        edgeMap[edge.id]?.relationZH = existing.relationZH + " · " + edge.relationZH
                    }
                    edgeMap[edge.id]?.strength = max(existing.strength, edge.strength)
                    edgeMap[edge.id]?.isAI = existing.isAI || edge.isAI
                } else {
                    edgeMap[edge.id] = edge
                }
            }
        }

        let categories = nodeIDs.compactMap { ArxivTaxonomy.category($0) }
        let edges = Array(edgeMap.values).filter {
            nodeIDs.contains($0.source) && nodeIDs.contains($0.target) && $0.source != $0.target
        }
        let positions = ForceGraphLayout.layout(
            nodeIDs: categories.map(\.id),
            edges: edges.map { ($0.source, $0.target) },
            size: CGSize(width: 1_440, height: 920)
        )
        let nodes = categories.map { category in
            KnowledgeNode(
                id: category.id,
                category: category,
                group: ArxivTaxonomy.group(category.groupID),
                position: positions[category.id] ?? .zero,
                hasAIReport: reports[category.id] != nil,
                isSeed: seedNodeIDs.contains(category.id)
            )
        }
        return KnowledgeGraph(nodes: nodes, edges: edges)
    }

    static let seedNodeIDs: Set<String> = [
        "cs.AI", "cs.LG", "cs.CL", "cs.CV", "cs.RO", "cs.NE", "cs.IT", "cs.SY",
        "cs.GT", "cs.HC", "cs.CR",
        "math.OC", "math.ST", "math.DS", "math.PR", "math.NA", "math-ph",
        "stat.ML",
        "eess.SP", "eess.IV",
        "econ.GN",
        "q-fin.PM", "q-fin.ST",
        "q-bio.BM", "q-bio.NC", "q-bio.QM",
        "physics.comp-ph", "physics.flu-dyn", "physics.optics",
        "quant-ph", "cond-mat.mtrl-sci", "astro-ph.CO", "hep-th", "nlin.AO"
    ]

    /// Curated bilingual seed relations, expressed as
    /// (source category, target category, English relation, Chinese relation, strength).
    static let seedEdges: [(String, String, String, String, Int)] = [
        ("cs.AI", "cs.LG", "Learning and inference are two sides of modern AI", "学习与推理构成现代人工智能的两面", 3),
        ("cs.AI", "cs.CL", "Language is the interface for reasoning and generation", "语言是推理与生成的核心界面", 3),
        ("cs.AI", "cs.CV", "Visual perception supplies grounded world models", "视觉感知为世界模型提供现实依据", 3),
        ("cs.AI", "cs.RO", "Embodied intelligence closes the perception–action loop", "具身智能闭合感知—行动回路", 2),
        ("cs.AI", "cs.NE", "Neural and evolutionary metaphors shape learning systems", "神经与进化隐喻塑造学习系统", 2),
        ("cs.AI", "cs.HC", "Human–AI collaboration changes interface and trust design", "人机协同重塑界面与信任设计", 2),
        ("cs.AI", "cs.GT", "Multi-agent reasoning draws on strategic equilibrium", "多智能体推理依托策略均衡", 2),
        ("cs.LG", "stat.ML", "Statistical learning theory grounds generalization", "统计学习理论为泛化提供基础", 3),
        ("cs.LG", "math.OC", "Training is large-scale nonconvex optimization", "模型训练是大规模非凸优化问题", 3),
        ("cs.LG", "q-bio.NC", "Artificial networks borrow from neural computation", "人工网络借鉴神经计算机制", 2),
        ("cs.CL", "cs.IT", "Language models compress and transmit information", "语言模型压缩并传递信息", 2),
        ("cs.CV", "eess.IV", "Image formation, coding, and analysis share algorithms", "图像成像、编码与分析共享算法", 3),
        ("cs.RO", "cs.SY", "Autonomy requires feedback control and state estimation", "自主性依赖反馈控制与状态估计", 3),
        ("cs.RO", "cs.CV", "Robot perception turns images into actionable geometry", "机器人视觉将图像转化为可行动几何", 3),
        ("cs.SY", "math.OC", "Optimal and robust control are optimization problems", "最优与鲁棒控制本质上是优化问题", 3),
        ("cs.IT", "eess.SP", "Coding, modulation, and signal processing enable communication", "编码、调制与信号处理共同支撑通信", 3),
        ("cs.CR", "cs.IT", "Cryptography is information security under adversarial noise", "密码学是对抗噪声下的信息安全", 2),
        ("cs.DC", "math.NA", "Parallel numerical algorithms scale scientific computing", "并行数值算法扩展科学计算规模", 2),
        ("cs.HC", "q-bio.NC", "Interface design must account for human cognition", "界面设计必须理解人类认知", 2),
        ("math.OC", "q-fin.PM", "Portfolio construction is constrained optimization", "投资组合构建是约束优化", 3),
        ("q-fin.PM", "q-fin.ST", "Statistical evidence guides portfolio decisions", "统计证据指导投资组合决策", 3),
        ("q-fin.ST", "stat.ML", "Financial forecasting tests machine learning under nonstationarity", "金融预测检验非平稳条件下的机器学习", 3),
        ("econ.GN", "q-fin.ST", "Markets are economic experiments with high-frequency data", "市场是带高频数据的经济实验", 2),
        ("econ.GN", "stat.ML", "Causal inference sharpens economic prediction", "因果推断提升经济预测的可解释性", 2),
        ("econ.GN", "cs.GT", "Mechanism design shapes markets and institutions", "机制设计塑造市场与制度", 3),
        ("math.ST", "stat.ML", "Inference and learning share decision-theoretic foundations", "推断与学习共享决策论基础", 3),
        ("math.ST", "math.PR", "Probability supplies the language of statistical models", "概率论提供统计模型的语言", 3),
        ("math.PR", "q-fin.ST", "Stochastic processes model prices and risk", "随机过程刻画价格与风险", 3),
        ("math.NA", "physics.comp-ph", "Stable numerical schemes turn physical laws into simulation", "稳定数值格式把物理定律变成模拟", 3),
        ("math.DS", "nlin.AO", "Nonlinear dynamics explains self-organization", "非线性动力学解释自组织现象", 3),
        ("math.DS", "physics.flu-dyn", "Fluid flow is a dynamical system with conserved structure", "流体运动是带守恒结构的动力系统", 3),
        ("physics.comp-ph", "cond-mat.mtrl-sci", "Atomistic simulation accelerates materials discovery", "原子尺度模拟加速材料发现", 3),
        ("physics.comp-ph", "astro-ph.CO", "Cosmological simulations reconstruct structure formation", "宇宙学模拟重建结构形成", 2),
        ("physics.comp-ph", "q-bio.BM", "Molecular simulation connects structure to biological function", "分子模拟连接分子结构与生物功能", 2),
        ("quant-ph", "cs.IT", "Quantum information reshapes coding and communication limits", "量子信息重塑编码与通信极限", 3),
        ("quant-ph", "cond-mat.mtrl-sci", "Quantum materials host coherent and topological phases", "量子材料承载相干与拓扑物态", 3),
        ("quant-ph", "hep-th", "Quantum field theory links entanglement and spacetime", "量子场论联系纠缠与时空", 3),
        ("quant-ph", "physics.optics", "Photons are carriers of quantum information", "光子是量子信息的重要载体", 3),
        ("hep-th", "math-ph", "Gauge theory and geometry share a common language", "规范理论与几何共享语言", 3),
        ("q-bio.BM", "q-bio.QM", "Quantitative methods turn molecular data into models", "定量方法把分子数据转化为模型", 3),
        ("q-bio.NC", "nlin.AO", "Brains are self-organizing dynamical systems", "大脑是自组织的动力系统", 2),
        ("q-bio.NC", "cs.NE", "Neuromorphic computing learns from biological circuits", "神经形态计算向生物回路学习", 2),
        ("cs.SY", "eess.SP", "Estimation and filtering bridge control and signals", "估计与滤波连接控制与信号处理", 2),
        ("eess.SP", "math.NA", "Fast transforms and inverse problems rely on numerics", "快速变换与反问题依赖数值方法", 2),
        ("q-bio.QM", "stat.ML", "Biological discovery uses statistical machine learning", "生物学发现借助统计机器学习", 2),
        ("physics.optics", "cond-mat.mtrl-sci", "Photonic materials engineer light–matter interaction", "光子材料调控光与物质相互作用", 2)
    ]
}

enum ForceGraphLayout {
    private struct SeededRandom {
        var state: UInt64
        mutating func next() -> Double {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            z = z ^ (z >> 31)
            return Double(z) / Double(UInt64.max)
        }
    }

    static func layout(
        nodeIDs: [String],
        edges: [(String, String)],
        size: CGSize
    ) -> [String: CGPoint] {
        guard !nodeIDs.isEmpty else { return [:] }
        let width = size.width
        let height = size.height
        let center = CGPoint(x: width / 2, y: height / 2)
        var rng = SeededRandom(state: 0xC0FFEE_2026)
        guard width > 0, height > 0 else { return [:] }

        var positions: [String: CGPoint] = [:]
        var groups: [String: [String]] = [:]
        for id in nodeIDs {
            let group = ArxivTaxonomy.category(id)?.groupID ?? "other"
            groups[group, default: []].append(id)
        }
        let groupKeys = groups.keys.sorted()
        let groupRadius = min(width, height) * 0.31
        var groupCenters: [String: CGPoint] = [:]
        for (index, key) in groupKeys.enumerated() {
            let angle = (Double(index) / Double(max(groupKeys.count, 1))) * 2 * Double.pi - Double.pi / 2
            groupCenters[key] = CGPoint(
                x: center.x + CGFloat(cos(angle)) * groupRadius,
                y: center.y + CGFloat(sin(angle)) * groupRadius
            )
        }

        for id in nodeIDs {
            let group = ArxivTaxonomy.category(id)?.groupID ?? "other"
            let anchor = groupCenters[group] ?? center
            let angle = rng.next() * 2 * Double.pi
            let radius = 30 + rng.next() * 175
            positions[id] = CGPoint(
                x: anchor.x + cos(angle) * radius,
                y: anchor.y + sin(angle) * radius
            )
        }

        let n = Double(nodeIDs.count)
        let area = width * height
        let k = sqrt(area / n) * 0.92
        var temperature = min(width, height) * 0.075

        for _ in 0..<420 {
            var displacement: [String: CGPoint] = [:]
            for id in nodeIDs { displacement[id] = .zero }

            for i in 0..<nodeIDs.count {
                let idA = nodeIDs[i]
                guard let pa = positions[idA] else { continue }
                for j in (i + 1)..<nodeIDs.count {
                    let idB = nodeIDs[j]
                    guard let pb = positions[idB] else { continue }
                    var dx = pa.x - pb.x
                    var dy = pa.y - pb.y
                    var distance = sqrt(dx * dx + dy * dy)
                    if distance < 0.8 {
                        dx = (rng.next() - 0.5) * 2
                        dy = (rng.next() - 0.5) * 2
                        distance = max(sqrt(dx * dx + dy * dy), 0.8)
                    }
                    let force = (k * k) / distance
                    let fx = (dx / distance) * force
                    let fy = (dy / distance) * force
                    displacement[idA]?.x += fx
                    displacement[idA]?.y += fy
                    displacement[idB]?.x -= fx
                    displacement[idB]?.y -= fy
                }
            }

            for (source, target) in edges {
                guard source != target,
                      let ps = positions[source],
                      let pt = positions[target] else { continue }
                var dx = ps.x - pt.x
                var dy = ps.y - pt.y
                let distance = max(sqrt(dx * dx + dy * dy), 0.8)
                let force = (distance * distance) / k * 0.72
                dx = (dx / distance) * force
                dy = (dy / distance) * force
                displacement[source]?.x -= dx
                displacement[source]?.y -= dy
                displacement[target]?.x += dx
                displacement[target]?.y += dy
            }

            for id in nodeIDs {
                guard var point = positions[id] else { continue }
                var delta = displacement[id] ?? .zero
                let group = ArxivTaxonomy.category(id)?.groupID ?? "other"
                let anchor = groupCenters[group] ?? center
                delta.x += (anchor.x - point.x) * 0.011
                delta.y += (anchor.y - point.y) * 0.011
                delta.x += (center.x - point.x) * 0.009
                delta.y += (center.y - point.y) * 0.009
                let length = max(sqrt(delta.x * delta.x + delta.y * delta.y), 0.001)
                let cap = min(length, temperature)
                point.x += (delta.x / length) * cap
                point.y += (delta.y / length) * cap
                let marginX = 150.0
                let marginY = 100.0
                point.x = min(max(point.x, marginX), width - marginX)
                point.y = min(max(point.y, marginY), height - marginY)
                positions[id] = point
            }
            temperature = max(1.2, temperature * 0.975)
        }

        // Normalize into a generous viewport.
        let xs = positions.values.map(\.x)
        let ys = positions.values.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else {
            return positions
        }
        let spanX = max(maxX - minX, 1)
        let spanY = max(maxY - minY, 1)
        let targetWidth = width * 0.82
        let targetHeight = height * 0.76
        let scale = min(targetWidth / spanX, targetHeight / spanY)
        for id in nodeIDs {
            guard let p = positions[id] else { continue }
            positions[id] = CGPoint(
                x: width / 2 + (p.x - (minX + maxX) / 2) * scale,
                y: height / 2 + (p.y - (minY + maxY) / 2) * scale
            )
        }

        // Node cards have a real footprint. A short collision pass removes
        // overlaps without destroying the force-directed topology.
        let minDX: CGFloat = 176
        let minDY: CGFloat = 64
        for _ in 0..<80 {
            for i in 0..<nodeIDs.count {
                for j in (i + 1)..<nodeIDs.count {
                    guard var a = positions[nodeIDs[i]],
                          var b = positions[nodeIDs[j]] else { continue }
                    let dx = b.x - a.x
                    let dy = b.y - a.y
                    guard abs(dx) < minDX, abs(dy) < minDY else { continue }
                    let overlapX = minDX - abs(dx)
                    let overlapY = minDY - abs(dy)
                    if overlapX < overlapY {
                        let direction: CGFloat = dx == 0 ? (a.y < b.y ? 1 : -1) : (dx > 0 ? 1 : -1)
                        a.x -= direction * (overlapX / 2 + 0.4)
                        b.x += direction * (overlapX / 2 + 0.4)
                    } else {
                        let direction: CGFloat = dy == 0 ? (a.x < b.x ? 1 : -1) : (dy > 0 ? 1 : -1)
                        a.y -= direction * (overlapY / 2 + 0.4)
                        b.y += direction * (overlapY / 2 + 0.4)
                    }
                    a.x = min(max(a.x, 95), width - 95)
                    b.x = min(max(b.x, 95), width - 95)
                    a.y = min(max(a.y, 46), height - 46)
                    b.y = min(max(b.y, 46), height - 46)
                    positions[nodeIDs[i]] = a
                    positions[nodeIDs[j]] = b
                }
            }
        }
        return positions
    }
}
