import Foundation

struct HistoryMilestone: Codable, Hashable {
    var period: String
    var titleEN: String
    var titleZH: String
    var detailEN: String
    var detailZH: String

    enum CodingKeys: String, CodingKey {
        case period
        case titleEN = "title_en"
        case titleZH = "title_zh"
        case detailEN = "detail_en"
        case detailZH = "detail_zh"
    }
}

struct InsightItem: Codable, Hashable {
    var titleEN: String
    var titleZH: String
    var detailEN: String
    var detailZH: String

    enum CodingKeys: String, CodingKey {
        case titleEN = "title_en"
        case titleZH = "title_zh"
        case detailEN = "detail_en"
        case detailZH = "detail_zh"
    }
}

struct BilingualNote: Codable, Hashable {
    var en: String
    var zh: String
}

struct Achievement: Codable, Hashable {
    var titleEN: String
    var titleZH: String
    var detailEN: String
    var detailZH: String
    var applications: [BilingualNote]

    enum CodingKeys: String, CodingKey {
        case titleEN = "title_en"
        case titleZH = "title_zh"
        case detailEN = "detail_en"
        case detailZH = "detail_zh"
        case applications
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        titleEN = try c.decode(String.self, forKey: .titleEN)
        titleZH = try c.decode(String.self, forKey: .titleZH)
        detailEN = try c.decode(String.self, forKey: .detailEN)
        detailZH = try c.decode(String.self, forKey: .detailZH)
        applications = try c.decodeIfPresent([BilingualNote].self, forKey: .applications) ?? []
    }
}

struct KeyFigure: Codable, Hashable {
    var nameEN: String
    var nameZH: String
    var era: String?
    var fieldEN: String
    var fieldZH: String
    var contributionEN: String
    var contributionZH: String

    enum CodingKeys: String, CodingKey {
        case nameEN = "name_en"
        case nameZH = "name_zh"
        case era
        case fieldEN = "field_en"
        case fieldZH = "field_zh"
        case contributionEN = "contribution_en"
        case contributionZH = "contribution_zh"
    }
}

struct DisciplineRelation: Codable, Hashable {
    var categoryID: String
    var nameEN: String
    var nameZH: String
    var relationEN: String
    var relationZH: String
    var strength: Int

    enum CodingKeys: String, CodingKey {
        case categoryID = "category_id"
        case nameEN = "name_en"
        case nameZH = "name_zh"
        case relationEN = "relation_en"
        case relationZH = "relation_zh"
        case strength
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        categoryID = try c.decodeIfPresent(String.self, forKey: .categoryID) ?? ""
        nameEN = try c.decodeIfPresent(String.self, forKey: .nameEN) ?? ""
        nameZH = try c.decodeIfPresent(String.self, forKey: .nameZH) ?? ""
        relationEN = try c.decodeIfPresent(String.self, forKey: .relationEN) ?? ""
        relationZH = try c.decodeIfPresent(String.self, forKey: .relationZH) ?? ""
        strength = try c.decodeIfPresent(Int.self, forKey: .strength) ?? 2
    }
}

struct TermDefinition: Codable, Hashable {
    var termEN: String
    var termZH: String
    var definitionEN: String
    var definitionZH: String

    enum CodingKeys: String, CodingKey {
        case termEN = "term_en"
        case termZH = "term_zh"
        case definitionEN = "definition_en"
        case definitionZH = "definition_zh"
    }
}

struct EquationEntry: Codable, Hashable {
    var nameEN: String
    var nameZH: String
    var latex: String
    var explanationEN: String
    var explanationZH: String

    enum CodingKeys: String, CodingKey {
        case nameEN = "name_en"
        case nameZH = "name_zh"
        case latex
        case explanationEN = "explanation_en"
        case explanationZH = "explanation_zh"
    }
}

struct AIReport: Codable, Identifiable {
    var categoryID: String
    var categoryNameEN: String
    var categoryNameZH: String
    var generatedAt: Date
    var model: String
    var schemaVersion: Int

    var overviewEN: String
    var overviewZH: String
    var history: [HistoryMilestone]
    var openProblems: [InsightItem]
    var frontiers: [InsightItem]
    var achievements: [Achievement]
    var figures: [KeyFigure]
    var relations: [DisciplineRelation]
    var terms: [TermDefinition]
    var equations: [EquationEntry]
    var caveatEN: String?
    var caveatZH: String?

    var id: String { categoryID }

    enum CodingKeys: String, CodingKey {
        case categoryID = "category_id"
        case categoryNameEN = "category_name_en"
        case categoryNameZH = "category_name_zh"
        case generatedAt = "generated_at"
        case model
        case schemaVersion = "schema_version"
        case overviewEN = "overview_en"
        case overviewZH = "overview_zh"
        case history
        case openProblems = "open_problems"
        case frontiers
        case achievements
        case figures
        case relations
        case terms
        case equations
        case caveatEN = "caveat_en"
        case caveatZH = "caveat_zh"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        categoryID = try c.decodeIfPresent(String.self, forKey: .categoryID) ?? ""
        categoryNameEN = try c.decodeIfPresent(String.self, forKey: .categoryNameEN) ?? ""
        categoryNameZH = try c.decodeIfPresent(String.self, forKey: .categoryNameZH) ?? ""
        generatedAt = try c.decodeIfPresent(Date.self, forKey: .generatedAt) ?? Date()
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? ""
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        overviewEN = try c.decodeIfPresent(String.self, forKey: .overviewEN) ?? ""
        overviewZH = try c.decodeIfPresent(String.self, forKey: .overviewZH) ?? ""
        history = try c.decodeIfPresent([HistoryMilestone].self, forKey: .history) ?? []
        openProblems = try c.decodeIfPresent([InsightItem].self, forKey: .openProblems) ?? []
        frontiers = try c.decodeIfPresent([InsightItem].self, forKey: .frontiers) ?? []
        achievements = try c.decodeIfPresent([Achievement].self, forKey: .achievements) ?? []
        figures = try c.decodeIfPresent([KeyFigure].self, forKey: .figures) ?? []
        relations = try c.decodeIfPresent([DisciplineRelation].self, forKey: .relations) ?? []
        terms = try c.decodeIfPresent([TermDefinition].self, forKey: .terms) ?? []
        equations = try c.decodeIfPresent([EquationEntry].self, forKey: .equations) ?? []
        caveatEN = try c.decodeIfPresent(String.self, forKey: .caveatEN)
        caveatZH = try c.decodeIfPresent(String.self, forKey: .caveatZH)
    }

    init(
        categoryID: String,
        categoryNameEN: String,
        categoryNameZH: String,
        generatedAt: Date,
        model: String,
        schemaVersion: Int = 1,
        overviewEN: String,
        overviewZH: String,
        history: [HistoryMilestone],
        openProblems: [InsightItem],
        frontiers: [InsightItem],
        achievements: [Achievement],
        figures: [KeyFigure],
        relations: [DisciplineRelation],
        terms: [TermDefinition],
        equations: [EquationEntry],
        caveatEN: String?,
        caveatZH: String?
    ) {
        self.categoryID = categoryID
        self.categoryNameEN = categoryNameEN
        self.categoryNameZH = categoryNameZH
        self.generatedAt = generatedAt
        self.model = model
        self.schemaVersion = schemaVersion
        self.overviewEN = overviewEN
        self.overviewZH = overviewZH
        self.history = history
        self.openProblems = openProblems
        self.frontiers = frontiers
        self.achievements = achievements
        self.figures = figures
        self.relations = relations
        self.terms = terms
        self.equations = equations
        self.caveatEN = caveatEN
        self.caveatZH = caveatZH
    }

    var hasContent: Bool {
        !overviewEN.trimmed.isEmpty
            || !overviewZH.trimmed.isEmpty
            || !history.isEmpty
            || !openProblems.isEmpty
            || !frontiers.isEmpty
    }

    mutating func normalize(for category: ArxivCategory, model: String) {
        categoryID = category.id
        categoryNameEN = category.nameEN
        categoryNameZH = category.nameZH
        self.model = model
        generatedAt = Date()
        schemaVersion = 1
        overviewEN = overviewEN.trimmed
        overviewZH = overviewZH.trimmed
        history = history.filter { !$0.titleEN.trimmed.isEmpty || !$0.titleZH.trimmed.isEmpty }
        openProblems = openProblems.filter { !$0.titleEN.trimmed.isEmpty || !$0.titleZH.trimmed.isEmpty }
        frontiers = frontiers.filter { !$0.titleEN.trimmed.isEmpty || !$0.titleZH.trimmed.isEmpty }
        achievements = achievements.filter { !$0.titleEN.trimmed.isEmpty || !$0.titleZH.trimmed.isEmpty }
        figures = figures.filter { !$0.nameEN.trimmed.isEmpty || !$0.nameZH.trimmed.isEmpty }
        terms = terms.filter { !$0.termEN.trimmed.isEmpty || !$0.termZH.trimmed.isEmpty }
        equations = equations.filter { !$0.latex.trimmed.isEmpty }
        relations = relations.filter {
            !$0.categoryID.trimmed.isEmpty && ArxivTaxonomy.category($0.categoryID) != nil
        }
        for index in relations.indices {
            relations[index].strength = min(max(relations[index].strength, 1), 3)
        }
        if let caveatEN, caveatEN.trimmed.isEmpty { self.caveatEN = nil }
        if let caveatZH, caveatZH.trimmed.isEmpty { self.caveatZH = nil }
    }
}
