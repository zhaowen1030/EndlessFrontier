import Foundation

enum KnowledgeTreeGenerationError: LocalizedError {
    case notConfigured(String)
    case invalidJSON(String)
    case incomplete(String)
    case empty

    var errorDescription: String? {
        switch self {
        case .notConfigured(let detail): return detail
        case .invalidJSON(let detail): return "AI 返回的知识树格式无法解析：\(detail)"
        case .incomplete(let detail): return "AI 返回的知识树不完整：\(detail)"
        case .empty: return "AI 没有返回可用的知识树内容。"
        }
    }
}

enum KnowledgeTreePrompt {
    static func treeSystem() -> String {
        """
        You are a rigorous bilingual science curriculum cartographer building knowledge trees for arXiv disciplines.

        Requirements:
        - Build a top-down, hierarchical map of durable knowledge, not a list of administrative categories.
        - The root is the discipline itself. Below it are 4–6 core domains. Each domain has 3–5 concrete knowledge points. Do not go deeper than these two levels below the root.
        - Every node must be a meaningful, non-overlapping knowledge point or coherent subfield. Avoid vague labels such as "Introduction", "Miscellaneous", "Other topics", or "Future work".
        - Keep the total tree between 15 and 30 nodes. Quality and non-overlap matter more than breadth.
        - Every name and summary must be provided in English and in natural academic Simplified Chinese. The two versions must carry the same meaning.
        - Summaries should be one concise sentence explaining what the node covers. Do not invent dates, paper titles, numerical claims, prize years, or quotations.
        - Prefer established concepts and methods. If a frontier is genuinely unsettled, word it as an active area rather than a settled result.
        - Return one valid JSON object only. No markdown fences, no commentary.
        """
    }

    static func treeUserPrompt(category: ArxivCategory) -> String {
        """
        Build the top-down knowledge tree for \(category.id) — \(category.nameEN) / \(category.nameZH).

        Return exactly this JSON shape:
        {
          "root": {
            "name_en": "\(category.nameEN)",
            "name_zh": "\(category.nameZH)",
            "summary_en": "One-sentence definition of the discipline.",
            "summary_zh": "对应的一句中文定义。",
            "children": [
              {
                "name_en": "Core domain name",
                "name_zh": "核心领域中文名",
                "summary_en": "One-sentence summary.",
                "summary_zh": "对应的一句中文说明。",
                "children": [
                  {
                    "name_en": "Concrete knowledge point",
                    "name_zh": "具体知识点中文名",
                    "summary_en": "One-sentence summary.",
                    "summary_zh": "对应的一句中文说明。",
                    "children": []
                  }
                ]
              }
            ]
          }
        }

        Constraints:
        - 4–6 children of the root.
        - 3–5 children for each core domain.
        - Do not add children below the knowledge-point level; use an empty array.
        - 15–30 total nodes including the root.
        - Names must be specific to the discipline and should not repeat.
        - Chinese content must be genuine academic Chinese, not a transliteration or an English copy.
        - Return JSON only.
        """
    }

    static func detailSystem() -> String {
        """
        You are a rigorous bilingual science explainer expanding one node in a discipline knowledge tree.

        Requirements:
        - Explain the specific knowledge point in its discipline context. Be precise and information-dense.
        - Concept definition: 80–150 English words and a parallel Chinese explanation of comparable depth.
        - Related knowledge: 3–6 genuinely related concepts, with a clear one-sentence relationship in both languages.
        - Key figures: only widely recognized contributors whose contribution you can state confidently. If a concept has no clear individual attribution, return fewer or an empty array. Never invent biographies, dates, or prizes.
        - Applications: 2–4 concrete real-world scenarios, not generic claims.
        - Do not fabricate papers, benchmarks, numerical results, dates, or quotations. Distinguish established consensus from active debate; omit uncertain specifics.
        - English and Chinese must both be substantive and use standard disciplinary terminology.
        - Return one valid JSON object only. No markdown fences, no commentary.
        """
    }

    static func detailUserPrompt(
        category: ArxivCategory,
        path: [KnowledgeTreeNode],
        node: KnowledgeTreeNode
    ) -> String {
        let pathText = path.map { "\($0.nameEN) / \($0.nameZH)" }.joined(separator: " > ")
        return """
        Discipline: \(category.id) — \(category.nameEN) / \(category.nameZH)
        Tree path: \(pathText)
        Knowledge point: \(node.nameEN) / \(node.nameZH)
        Existing summary EN: \(node.summaryEN)
        Existing summary ZH: \(node.summaryZH)

        Expand this specific knowledge point. Return exactly:
        {
          "definition_en": "80–150 word precise definition and explanation.",
          "definition_zh": "对应的高质量中文学术解释，约 150–260 字。",
          "related_knowledge": [
            {
              "name_en": "related concept",
              "name_zh": "相关概念中文名",
              "relation_en": "One sentence explaining the relationship.",
              "relation_zh": "对应的一句中文说明。"
            }
          ],
          "key_figures": [
            {
              "name_en": "Person name",
              "name_zh": "中文译名或常用中文名",
              "contribution_en": "One or two sentences on their specific contribution to this concept.",
              "contribution_zh": "对应的中文说明。"
            }
          ],
          "applications": [
            {
              "en": "Concrete real-world application scenario.",
              "zh": "对应的中文应用场景。"
            }
          ]
        }

        Return JSON only. If there are no well-established key figures or applications, use an empty array rather than inventing them.
        """
    }

    static func parseTree(_ raw: String, category: ArxivCategory, model: String) throws -> KnowledgeTree {
        guard let rootObject = JSONExtractor.object(from: raw) else {
            throw KnowledgeTreeGenerationError.invalidJSON("未找到完整的 JSON 对象。")
        }
        let rootData = try JSONSerialization.data(withJSONObject: rootObject)
        let decoder = JSONDecoder()
        let draft: TreeDraft
        do {
            draft = try decoder.decode(TreeDraft.self, from: rootData)
        } catch {
            throw KnowledgeTreeGenerationError.invalidJSON(error.localizedDescription)
        }
        let root = buildNode(
            draft: draft.root,
            id: "root",
            depth: 0,
            maxDepth: 3,
            rootCategory: category
        )
        guard root.nodeCount >= 6 else {
            throw KnowledgeTreeGenerationError.incomplete("只生成了 \(root.nodeCount) 个节点。")
        }
        guard root.children.count >= 2 else {
            throw KnowledgeTreeGenerationError.incomplete("根节点下没有足够的核心领域。")
        }
        return KnowledgeTree(
            categoryID: category.id,
            categoryNameEN: category.nameEN,
            categoryNameZH: category.nameZH,
            generatedAt: Date(),
            model: model,
            root: root
        )
    }

    static func parseDetail(_ raw: String, model: String) throws -> KnowledgeNodeDetail {
        guard let object = JSONExtractor.object(from: raw),
              let data = try? JSONSerialization.data(withJSONObject: object) else {
            throw KnowledgeTreeGenerationError.invalidJSON("未找到完整的 JSON 对象。")
        }
        let draft: DetailDraft
        do {
            draft = try JSONDecoder().decode(DetailDraft.self, from: data)
        } catch {
            throw KnowledgeTreeGenerationError.invalidJSON(error.localizedDescription)
        }
        let definitionEN = draft.definitionEN.trimmed
        let definitionZH = draft.definitionZH.trimmed
        guard !definitionEN.isEmpty, !definitionZH.isEmpty else {
            throw KnowledgeTreeGenerationError.incomplete("概念定义缺少英文或中文内容。")
        }
        let related = (draft.relatedKnowledge ?? []).filter {
            !$0.nameEN.trimmed.isEmpty || !$0.nameZH.trimmed.isEmpty
        }
        let figures = (draft.keyFigures ?? []).filter {
            !$0.nameEN.trimmed.isEmpty || !$0.nameZH.trimmed.isEmpty
        }
        let applications = (draft.applications ?? []).filter {
            !$0.en.trimmed.isEmpty || !$0.zh.trimmed.isEmpty
        }
        guard !related.isEmpty, !figures.isEmpty || !applications.isEmpty else {
            throw KnowledgeTreeGenerationError.incomplete("关联知识、人物或应用场景内容不足。")
        }
        return KnowledgeNodeDetail(
            definitionEN: definitionEN,
            definitionZH: definitionZH,
            relatedKnowledge: related,
            keyFigures: figures,
            applications: applications,
            generatedAt: Date(),
            model: model
        )
    }

    private static func buildNode(
        draft: NodeDraft,
        id: String,
        depth: Int,
        maxDepth: Int,
        rootCategory: ArxivCategory
    ) -> KnowledgeTreeNode {
        let nameEN = depth == 0 ? rootCategory.nameEN : (draft.nameEN ?? "").trimmed
        let nameZH = depth == 0 ? rootCategory.nameZH : (draft.nameZH ?? "").trimmed
        let summaryEN = (draft.summaryEN ?? "").trimmed
        let summaryZH = (draft.summaryZH ?? "").trimmed
        var children: [KnowledgeTreeNode] = []
        if depth < maxDepth {
            children = (draft.children ?? []).prefix(8).enumerated().compactMap { index, child in
                let childNameEN = (child.nameEN ?? "").trimmed
                let childNameZH = (child.nameZH ?? "").trimmed
                guard !childNameEN.isEmpty || !childNameZH.isEmpty else { return nil }
                return buildNode(
                    draft: child,
                    id: "\(id).\(index)",
                    depth: depth + 1,
                    maxDepth: maxDepth,
                    rootCategory: rootCategory
                )
            }
        }
        return KnowledgeTreeNode(
            id: id,
            nameEN: nameEN,
            nameZH: nameZH,
            summaryEN: summaryEN,
            summaryZH: summaryZH,
            children: children
        )
    }

    private struct TreeDraft: Decodable {
        let root: NodeDraft
    }

    private struct NodeDraft: Decodable {
        let nameEN: String?
        let nameZH: String?
        let summaryEN: String?
        let summaryZH: String?
        let children: [NodeDraft]?

        enum CodingKeys: String, CodingKey {
            case nameEN = "name_en"
            case nameZH = "name_zh"
            case summaryEN = "summary_en"
            case summaryZH = "summary_zh"
            case children
        }
    }

    private struct DetailDraft: Decodable {
        let definitionEN: String
        let definitionZH: String
        let relatedKnowledge: [KnowledgeRelatedItem]?
        let keyFigures: [KnowledgeFigureItem]?
        let applications: [BilingualNote]?

        enum CodingKeys: String, CodingKey {
            case definitionEN = "definition_en"
            case definitionZH = "definition_zh"
            case relatedKnowledge = "related_knowledge"
            case keyFigures = "key_figures"
            case applications
        }
    }
}
