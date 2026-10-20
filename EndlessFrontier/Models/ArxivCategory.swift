import SwiftUI

struct ArxivCategory: Identifiable, Hashable {
    let id: String
    let nameEN: String
    let nameZH: String
    let archiveID: String
    let groupID: String

    /// The short subject token, e.g. `AI` for `cs.AI`.
    var shortCode: String {
        id.split(separator: ".").last.map(String.init) ?? id
    }
}

struct CategoryArchive: Identifiable {
    let id: String
    let nameEN: String
    let nameZH: String
    let categories: [ArxivCategory]
}

struct CategoryGroup: Identifiable {
    let id: String
    let nameEN: String
    let nameZH: String
    let symbol: String
    let color: Color
    let archives: [CategoryArchive]

    var categories: [ArxivCategory] { archives.flatMap(\.categories) }

    var isNested: Bool { archives.count > 1 || archives.first?.id != id }
}

enum ArxivTaxonomy {
    private struct ArchiveSpec {
        let id: String
        let nameEN: String
        let nameZH: String
        let categories: [(String, String, String)]
    }

    private static func archive(
        _ id: String,
        _ nameEN: String,
        _ nameZH: String,
        _ categories: [(String, String, String)]
    ) -> ArchiveSpec {
        ArchiveSpec(id: id, nameEN: nameEN, nameZH: nameZH, categories: categories)
    }

    private static func group(
        _ id: String,
        _ nameEN: String,
        _ nameZH: String,
        _ symbol: String,
        _ color: String,
        _ archives: [ArchiveSpec]
    ) -> CategoryGroup {
        let builtArchives = archives.map { spec in
            CategoryArchive(
                id: spec.id,
                nameEN: spec.nameEN,
                nameZH: spec.nameZH,
                categories: spec.categories.map {
                    ArxivCategory(id: $0.0, nameEN: $0.1, nameZH: $0.2, archiveID: spec.id, groupID: id)
                }
            )
        }
        return CategoryGroup(
            id: id,
            nameEN: nameEN,
            nameZH: nameZH,
            symbol: symbol,
            color: Color(hex: color),
            archives: builtArchives
        )
    }

    static let groups: [CategoryGroup] = [
        group("cs", "Computer Science", "计算机科学", "cpu", "6C9BFF", [
            archive("cs", "Computer Science", "计算机科学", [
                ("cs.AI", "Artificial Intelligence", "人工智能"),
                ("cs.AR", "Hardware Architecture", "硬件体系结构"),
                ("cs.CC", "Computational Complexity", "计算复杂性"),
                ("cs.CE", "Computational Engineering, Finance, and Science", "计算工程、金融与科学"),
                ("cs.CG", "Computational Geometry", "计算几何"),
                ("cs.CL", "Computation and Language", "计算与语言"),
                ("cs.CR", "Cryptography and Security", "密码学与安全"),
                ("cs.CV", "Computer Vision and Pattern Recognition", "计算机视觉与模式识别"),
                ("cs.CY", "Computers and Society", "计算机与社会"),
                ("cs.DB", "Databases", "数据库"),
                ("cs.DC", "Distributed, Parallel, and Cluster Computing", "分布式、并行与集群计算"),
                ("cs.DL", "Digital Libraries", "数字图书馆"),
                ("cs.DM", "Discrete Mathematics", "离散数学"),
                ("cs.DS", "Data Structures and Algorithms", "数据结构与算法"),
                ("cs.ET", "Emerging Technologies", "新兴技术"),
                ("cs.FL", "Formal Languages and Automata Theory", "形式语言与自动机理论"),
                ("cs.GL", "General Literature", "综合文献"),
                ("cs.GR", "Graphics", "计算机图形学"),
                ("cs.GT", "Computer Science and Game Theory", "计算机科学与博弈论"),
                ("cs.HC", "Human-Computer Interaction", "人机交互"),
                ("cs.IR", "Information Retrieval", "信息检索"),
                ("cs.IT", "Information Theory", "信息论"),
                ("cs.LG", "Machine Learning", "机器学习"),
                ("cs.LO", "Logic in Computer Science", "计算机科学中的逻辑"),
                ("cs.MA", "Multiagent Systems", "多智能体系统"),
                ("cs.MM", "Multimedia", "多媒体"),
                ("cs.MS", "Mathematical Software", "数学软件"),
                ("cs.NA", "Numerical Analysis", "数值分析"),
                ("cs.NE", "Neural and Evolutionary Computing", "神经与进化计算"),
                ("cs.NI", "Networking and Internet Architecture", "网络与互联网体系结构"),
                ("cs.OH", "Other Computer Science", "其他计算机科学"),
                ("cs.OS", "Operating Systems", "操作系统"),
                ("cs.PF", "Performance", "性能"),
                ("cs.PL", "Programming Languages", "编程语言"),
                ("cs.RO", "Robotics", "机器人学"),
                ("cs.SC", "Symbolic Computation", "符号计算"),
                ("cs.SD", "Sound", "声音"),
                ("cs.SE", "Software Engineering", "软件工程"),
                ("cs.SI", "Social and Information Networks", "社会与信息网络"),
                ("cs.SY", "Systems and Control", "系统与控制"),
            ])
        ]),
        group("math", "Mathematics", "数学", "function", "B58CFF", [
            archive("math", "Mathematics", "数学", [
                ("math.AC", "Commutative Algebra", "交换代数"),
                ("math.AG", "Algebraic Geometry", "代数几何"),
                ("math.AP", "Analysis of PDEs", "偏微分方程分析"),
                ("math.AT", "Algebraic Topology", "代数拓扑"),
                ("math.CA", "Classical Analysis and ODEs", "经典分析与常微分方程"),
                ("math.CO", "Combinatorics", "组合数学"),
                ("math.CT", "Category Theory", "范畴论"),
                ("math.CV", "Complex Variables", "复分析"),
                ("math.DG", "Differential Geometry", "微分几何"),
                ("math.DS", "Dynamical Systems", "动力系统"),
                ("math.FA", "Functional Analysis", "泛函分析"),
                ("math.GM", "General Mathematics", "一般数学"),
                ("math.GN", "General Topology", "一般拓扑学"),
                ("math.GR", "Group Theory", "群论"),
                ("math.GT", "Geometric Topology", "几何拓扑"),
                ("math.HO", "History and Overview", "历史与概览"),
                ("math.IT", "Information Theory", "信息论"),
                ("math.KT", "K-Theory and Homology", "K-理论与同调"),
                ("math.LO", "Logic", "逻辑学"),
                ("math.MG", "Metric Geometry", "度量几何"),
                ("math.MP", "Mathematical Physics", "数学物理"),
                ("math.NA", "Numerical Analysis", "数值分析"),
                ("math.NT", "Number Theory", "数论"),
                ("math.OA", "Operator Algebras", "算子代数"),
                ("math.OC", "Optimization and Control", "优化与控制"),
                ("math.PR", "Probability", "概率论"),
                ("math.QA", "Quantum Algebra", "量子代数"),
                ("math.RA", "Rings and Algebras", "环与代数"),
                ("math.RT", "Representation Theory", "表示论"),
                ("math.SG", "Symplectic Geometry", "辛几何"),
                ("math.SP", "Spectral Theory", "谱理论"),
                ("math.ST", "Statistics Theory", "统计理论"),
            ])
        ]),
        group("physics", "Physics", "物理学", "atom", "F2A25C", [
            archive("astro-ph", "Astrophysics", "天体物理学", [
                ("astro-ph.CO", "Cosmology and Nongalactic Astrophysics", "宇宙学与非星系天体物理"),
                ("astro-ph.EP", "Earth and Planetary Astrophysics", "地球与行星天体物理"),
                ("astro-ph.GA", "Astrophysics of Galaxies", "星系天体物理"),
                ("astro-ph.HE", "High Energy Astrophysical Phenomena", "高能天体物理现象"),
                ("astro-ph.IM", "Instrumentation and Methods for Astrophysics", "天体物理仪器与方法"),
                ("astro-ph.SR", "Solar and Stellar Astrophysics", "太阳与恒星天体物理"),
            ]),
            archive("cond-mat", "Condensed Matter", "凝聚态物理", [
                ("cond-mat.dis-nn", "Disordered Systems and Neural Networks", "无序系统与神经网络"),
                ("cond-mat.mes-hall", "Mesoscale and Nanoscale Physics", "介观与纳米物理"),
                ("cond-mat.mtrl-sci", "Materials Science", "材料科学"),
                ("cond-mat.other", "Other Condensed Matter", "其他凝聚态物理"),
                ("cond-mat.quant-gas", "Quantum Gases", "量子气体"),
                ("cond-mat.soft", "Soft Condensed Matter", "软凝聚态物理"),
                ("cond-mat.stat-mech", "Statistical Mechanics", "统计力学"),
                ("cond-mat.str-el", "Strongly Correlated Electrons", "强关联电子"),
                ("cond-mat.supr-con", "Superconductivity", "超导"),
            ]),
            archive("gr-qc", "General Relativity and Quantum Cosmology", "广义相对论与量子宇宙学", [
                ("gr-qc", "General Relativity and Quantum Cosmology", "广义相对论与量子宇宙学"),
            ]),
            archive("hep-ex", "High Energy Physics - Experiment", "高能物理实验", [
                ("hep-ex", "High Energy Physics - Experiment", "高能物理实验"),
            ]),
            archive("hep-lat", "High Energy Physics - Lattice", "格点高能物理", [
                ("hep-lat", "High Energy Physics - Lattice", "格点高能物理"),
            ]),
            archive("hep-ph", "High Energy Physics - Phenomenology", "高能物理唯象学", [
                ("hep-ph", "High Energy Physics - Phenomenology", "高能物理唯象学"),
            ]),
            archive("hep-th", "High Energy Physics - Theory", "高能物理理论", [
                ("hep-th", "High Energy Physics - Theory", "高能物理理论"),
            ]),
            archive("math-ph", "Mathematical Physics", "数学物理", [
                ("math-ph", "Mathematical Physics", "数学物理"),
            ]),
            archive("nlin", "Nonlinear Sciences", "非线性科学", [
                ("nlin.AO", "Adaptation and Self-Organizing Systems", "适应与自组织系统"),
                ("nlin.CD", "Chaotic Dynamics", "混沌动力学"),
                ("nlin.CG", "Cellular Automata and Lattice Gases", "元胞自动机与晶格气体"),
                ("nlin.PS", "Pattern Formation and Solitons", "斑图形成与孤子"),
                ("nlin.SI", "Exactly Solvable and Integrable Systems", "精确可解与可积系统"),
            ]),
            archive("nucl-ex", "Nuclear Experiment", "核物理实验", [
                ("nucl-ex", "Nuclear Experiment", "核物理实验"),
            ]),
            archive("nucl-th", "Nuclear Theory", "核物理理论", [
                ("nucl-th", "Nuclear Theory", "核物理理论"),
            ]),
            archive("physics", "Physics", "物理学（综合）", [
                ("physics.acc-ph", "Accelerator Physics", "加速器物理"),
                ("physics.ao-ph", "Atmospheric and Oceanic Physics", "大气与海洋物理"),
                ("physics.app-ph", "Applied Physics", "应用物理"),
                ("physics.atm-clus", "Atomic and Molecular Clusters", "原子与分子团簇"),
                ("physics.atom-ph", "Atomic Physics", "原子物理"),
                ("physics.bio-ph", "Biological Physics", "生物物理"),
                ("physics.chem-ph", "Chemical Physics", "化学物理"),
                ("physics.class-ph", "Classical Physics", "经典物理"),
                ("physics.comp-ph", "Computational Physics", "计算物理"),
                ("physics.data-an", "Data Analysis, Statistics and Probability", "数据分析、统计与概率"),
                ("physics.ed-ph", "Physics Education", "物理教育"),
                ("physics.flu-dyn", "Fluid Dynamics", "流体力学"),
                ("physics.gen-ph", "General Physics", "普通物理"),
                ("physics.geo-ph", "Geophysics", "地球物理"),
                ("physics.hist-ph", "History and Philosophy of Physics", "物理学史与哲学"),
                ("physics.ins-det", "Instrumentation and Detectors", "仪器与探测器"),
                ("physics.med-ph", "Medical Physics", "医学物理"),
                ("physics.optics", "Optics", "光学"),
                ("physics.plasm-ph", "Plasma Physics", "等离子体物理"),
                ("physics.pop-ph", "Popular Physics", "大众物理"),
                ("physics.soc-ph", "Physics and Society", "物理与社会"),
                ("physics.space-ph", "Space Physics", "空间物理"),
            ]),
            archive("quant-ph", "Quantum Physics", "量子物理", [
                ("quant-ph", "Quantum Physics", "量子物理"),
            ]),
        ]),
        group("q-bio", "Quantitative Biology", "定量生物学", "leaf", "5BCB9A", [
            archive("q-bio", "Quantitative Biology", "定量生物学", [
                ("q-bio.BM", "Biomolecules", "生物大分子"),
                ("q-bio.CB", "Cell Behavior", "细胞行为"),
                ("q-bio.GN", "Genomics", "基因组学"),
                ("q-bio.MN", "Molecular Networks", "分子网络"),
                ("q-bio.NC", "Neurons and Cognition", "神经元与认知"),
                ("q-bio.OT", "Other Quantitative Biology", "其他定量生物学"),
                ("q-bio.PE", "Populations and Evolution", "种群与演化"),
                ("q-bio.QM", "Quantitative Methods", "定量方法"),
                ("q-bio.SC", "Subcellular Processes", "亚细胞过程"),
                ("q-bio.TO", "Tissues and Organs", "组织与器官"),
            ])
        ]),
        group("q-fin", "Quantitative Finance", "定量金融", "chart.line.uptrend.xyaxis", "E4C35B", [
            archive("q-fin", "Quantitative Finance", "定量金融", [
                ("q-fin.CP", "Computational Finance", "计算金融"),
                ("q-fin.EC", "Economics", "经济学"),
                ("q-fin.GN", "General Finance", "一般金融"),
                ("q-fin.MF", "Mathematical Finance", "数学金融"),
                ("q-fin.PM", "Portfolio Management", "投资组合管理"),
                ("q-fin.PR", "Pricing of Securities", "证券定价"),
                ("q-fin.RM", "Risk Management", "风险管理"),
                ("q-fin.ST", "Statistical Finance", "统计金融"),
                ("q-fin.TR", "Trading and Market Microstructure", "交易与市场微观结构"),
            ])
        ]),
        group("stat", "Statistics", "统计学", "chart.bar.xaxis", "59C9C9", [
            archive("stat", "Statistics", "统计学", [
                ("stat.AP", "Applications", "应用统计"),
                ("stat.CO", "Computation", "统计计算"),
                ("stat.ME", "Methodology", "统计方法"),
                ("stat.ML", "Machine Learning", "机器学习"),
                ("stat.OT", "Other Statistics", "其他统计"),
                ("stat.TH", "Statistics Theory", "统计理论"),
            ])
        ]),
        group("eess", "Electrical Engineering and Systems Science", "电气工程与系统科学", "waveform.path.ecg", "EA7E9B", [
            archive("eess", "Electrical Engineering and Systems Science", "电气工程与系统科学", [
                ("eess.AS", "Audio and Speech Processing", "音频与语音处理"),
                ("eess.IV", "Image and Video Processing", "图像与视频处理"),
                ("eess.SP", "Signal Processing", "信号处理"),
                ("eess.SY", "Systems and Control", "系统与控制"),
            ])
        ]),
        group("econ", "Economics", "经济学", "building.columns", "D2A46D", [
            archive("econ", "Economics", "经济学", [
                ("econ.EM", "Econometrics", "计量经济学"),
                ("econ.GN", "General Economics", "一般经济学"),
                ("econ.TH", "Theoretical Economics", "理论经济学"),
            ])
        ]),
    ]

    static let allCategories: [ArxivCategory] = groups.flatMap(\.categories)

    static let categoriesByID: [String: ArxivCategory] = Dictionary(
        uniqueKeysWithValues: allCategories.map { ($0.id, $0) }
    )

    static let archivesByID: [String: CategoryArchive] = {
        var result: [String: CategoryArchive] = [:]
        for group in groups {
            for archive in group.archives { result[archive.id] = archive }
        }
        return result
    }()

    static func category(_ id: String) -> ArxivCategory? {
        categoriesByID[id]
    }

    static func group(_ id: String) -> CategoryGroup? {
        groups.first { $0.id == id }
    }

    static func archive(_ id: String) -> CategoryArchive? {
        archivesByID[id]
    }

    static func groupForCategory(_ id: String) -> CategoryGroup? {
        guard let category = category(id) else { return nil }
        return group(category.groupID)
    }

    /// Flat, compact category listing handed to the language model when it maps
    /// interdisciplinary relationships. Keeping the canonical taxonomy in the
    /// prompt makes the resulting graph edges resolvable.
    static var promptCategoryIndex: String {
        allCategories
            .map { "\($0.id) | \($0.nameEN) | \($0.nameZH)" }
            .joined(separator: "\n")
    }

    static func search(_ query: String) -> [(group: CategoryGroup, categories: [ArxivCategory])] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return groups.map { ($0, $0.categories) } }
        return groups.compactMap { group in
            let matches = group.categories.filter {
                $0.id.lowercased().contains(needle)
                    || $0.nameEN.lowercased().contains(needle)
                    || $0.nameZH.contains(needle)
            }
            return matches.isEmpty ? nil : (group, matches)
        }
    }
}
