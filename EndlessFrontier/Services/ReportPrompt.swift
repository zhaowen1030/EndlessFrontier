import Foundation

enum ReportGenerationError: LocalizedError {
    case notConfigured(String)
    case invalidJSON(String)
    case incomplete(String)
    case empty

    var errorDescription: String? {
        switch self {
        case .notConfigured(let detail):
            return detail
        case .invalidJSON(let detail):
            return "AI 返回的内容不是有效的报告 JSON：\(detail)"
        case .incomplete(let detail):
            return "AI 报告内容不完整：\(detail)"
        case .empty:
            return "AI 没有返回可用的报告内容。"
        }
    }
}

enum ReportPrompt {
    static func systemPrompt() -> String {
        """
        You are the research cartographer behind "无尽前沿 / Endless Frontier", a rigorous bilingual atlas of scientific disciplines. You write publication-quality educational syntheses for a curious, technically literate audience.

        Epistemic rules:
        - Accuracy over completeness. Never invent papers, publication years, prize years, quotations, numerical values, institutions, or biographical details. If a specific fact is uncertain, omit it or use calibrated language such as "widely associated with" / "被广泛认为".
        - Distinguish established consensus, active debate, and speculative directions. Do not present a contested claim as settled.
        - Prefer durable concepts, methods, and well-known results over unverifiable micro-claims. Do not fabricate arXiv identifiers or paper titles.
        - Keep equations only when they are genuinely canonical and correct. Never invent notation. Use valid LaTeX math.
        - English and Chinese must be independent, equally substantive academic renderings, not a mechanical gloss. Use standard disciplinary terminology in both languages. On first use in Chinese, keep key acronyms and proper names in English, optionally with a Chinese gloss.
        - Every item must be specific to the discipline. No generic filler that would apply to any field.
        - Stay within the requested item counts and length guidelines. Completeness of the JSON is essential.

        Output rules:
        - Return exactly one valid JSON object and nothing else: no markdown fence, no preface, no trailing commentary.
        - Use the exact field names specified. Escape strings correctly. LaTeX backslashes must be valid JSON escapes (e.g. "\\\\frac{a}{b}").
        - This is an educational synthesis, not medical, legal, or investment advice.
        - You may note uncertainty in the caveat fields and within item details.
        """
    }

    static func userPrompt(category: ArxivCategory) -> String {
        let date = Date().formatted(.dateTime.year().month().day())
        return """
        Produce a bilingual knowledge synthesis for the arXiv discipline \(category.id) — \(category.nameEN) / \(category.nameZH).
        Current date: \(date). Focus on durable, well-established knowledge while identifying genuinely active research frontiers. Do not rely on invented recent specifics.

        Return one JSON object with EXACTLY this schema and these key names:

        {
          "category_id": "\(category.id)",
          "category_name_en": "\(category.nameEN)",
          "category_name_zh": "\(category.nameZH)",
          "overview_en": "A 100–150 word intellectual portrait: what the field studies, its central questions, methods, and why it matters.",
          "overview_zh": "A parallel, equally substantive 180–260 character academic Chinese overview. Not a literal translation.",
          "history": [
            {
              "period": "e.g. 1930s–1950s",
              "title_en": "short milestone title",
              "title_zh": "简短的中文里程碑标题",
              "detail_en": "45–80 words on the intellectual development, key ideas, and why this period mattered.",
              "detail_zh": "对应的中文叙述，约 80–140 字，信息量应与英文相当。"
            }
          ],
          "open_problems": [
            {
              "title_en": "specific unresolved question",
              "title_zh": "具体的中文未解难题",
              "detail_en": "55–95 words: why it remains open, competing approaches, and what would count as progress.",
              "detail_zh": "对应的中文说明，约 100–170 字。"
            }
          ],
          "frontiers": [
            {
              "title_en": "active research frontier",
              "title_zh": "活跃前沿方向",
              "detail_en": "50–90 words: the current frontier, enabling methods or observations, and the open edge.",
              "detail_zh": "对应的中文说明，约 90–160 字。"
            }
          ],
          "achievements": [
            {
              "title_en": "landmark result or capability",
              "title_zh": "标志性成果",
              "detail_en": "45–80 words explaining the result and its significance.",
              "detail_zh": "对应的中文说明，约 80–150 字。",
              "applications": [
                {"en": "Concrete real-world application", "zh": "具体的现实应用场景"}
              ]
            }
          ],
          "figures": [
            {
              "name_en": "Full name",
              "name_zh": "中文译名（可保留英文名）",
              "era": "life dates or active period, e.g. 1903–1957; omit rather than guess",
              "field_en": "primary subfield",
              "field_zh": "主要子领域",
              "contribution_en": "30–60 words: the person's specific foundational contribution, not a generic biography.",
              "contribution_zh": "对应的中文简介，约 50–100 字。"
            }
          ],
          "relations": [
            {
              "category_id": "a valid arXiv category ID from the taxonomy below",
              "name_en": "Name of the related discipline",
              "name_zh": "相关学科的中文名",
              "relation_en": "One sentence describing the substantive two-way intellectual exchange.",
              "relation_zh": "对应的一句中文说明。",
              "strength": 2
            }
          ],
          "terms": [
            {
              "term_en": "key term",
              "term_zh": "标准中文译名",
              "definition_en": "20–45 word precise definition.",
              "definition_zh": "对应的中文定义，约 40–80 字。"
            }
          ],
          "equations": [
            {
              "name_en": "name of the equation or law",
              "name_zh": "方程或定律的中文名",
              "latex": "canonical LaTeX, e.g. \\\\nabla \\\\cdot \\\\mathbf{E} = \\\\rho / \\\\varepsilon_0",
              "explanation_en": "1–3 sentences on its meaning and domain of validity.",
              "explanation_zh": "对应的中文解释。"
            }
          ],
          "caveat_en": "One sentence about the limits of an AI-generated overview.",
          "caveat_zh": "对应的中文说明。"
        }

        Content requirements:
        - history: 4–6 items, chronological, from foundations to the present.
        - open_problems: 4–6 items, genuinely unsolved and specific.
        - frontiers: 4–6 items, active directions rather than settled textbook material.
        - achievements: 3–5 items, each with 2–3 concrete applications. Applications should name real sectors, technologies, or everyday uses.
        - figures: 5–7 widely recognized contributors. Include only people whose contributions you can state confidently. If dates are uncertain, set "era" to an empty string rather than guessing.
        - relations: 4–6 items. Use ONLY category IDs listed in the arXiv taxonomy below. Prefer genuinely interdisciplinary exchanges over superficial overlaps. strength: 1 = adjacent, 2 = strong exchange, 3 = deeply intertwined.
        - terms: 6–10 essential terms.
        - equations: 2–5 canonical equations if the field has them; otherwise return fewer or an empty array. Do not force equations into fields without canonical quantitative laws.
        - All English content and all Chinese content must be at matching depth. Do not leave Chinese fields as English copies.
        - Be concise and information-dense. Prefer specific mechanisms, methods, and consequences over general praise.
        - The complete JSON must fit comfortably within the response budget. Do not truncate it.
        - Do not include markdown, HTML, citations, or commentary outside the JSON.

        arXiv subject taxonomy (ID | English | Chinese):
        \(ArxivTaxonomy.promptCategoryIndex)
        """
    }

    static func parse(_ raw: String, category: ArxivCategory, model: String) throws -> AIReport {
        guard let data = JSONExtractor.objectData(from: raw) else {
            throw ReportGenerationError.invalidJSON("未找到完整的 JSON 对象。")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var report: AIReport
        do {
            report = try decoder.decode(AIReport.self, from: data)
        } catch {
            throw ReportGenerationError.invalidJSON(error.localizedDescription)
        }
        report.normalize(for: category, model: model)

        guard report.hasContent else {
            throw ReportGenerationError.empty
        }
        let populatedSections = [
            !report.history.isEmpty,
            !report.openProblems.isEmpty,
            !report.frontiers.isEmpty,
            !report.achievements.isEmpty,
            !report.figures.isEmpty,
            !report.relations.isEmpty,
            !report.terms.isEmpty,
            !report.equations.isEmpty
        ].filter { $0 }.count
        guard populatedSections >= 4, !report.overviewEN.isEmpty || !report.overviewZH.isEmpty else {
            throw ReportGenerationError.incomplete("主要章节缺失，只生成了 \(populatedSections) 个有内容的章节。")
        }
        return report
    }
}
