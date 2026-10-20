import Foundation

struct KnowledgeTree: Codable, Identifiable, Hashable {
    let categoryID: String
    let categoryNameEN: String
    let categoryNameZH: String
    var generatedAt: Date
    var model: String
    var root: KnowledgeTreeNode

    var id: String { categoryID }

    var nodeCount: Int { root.nodeCount }

    var expandableNodeIDs: Set<String> {
        Set(root.allNodes.filter { !$0.children.isEmpty }.map(\.id))
    }

    var allNodeIDs: [String] {
        root.allNodes.map(\.id)
    }

    func node(id: String) -> KnowledgeTreeNode? {
        root.node(id: id)
    }

    func path(to nodeID: String) -> [KnowledgeTreeNode] {
        root.path(to: nodeID)
    }

    mutating func setDetail(_ detail: KnowledgeNodeDetail, for nodeID: String) -> Bool {
        root.setDetail(detail, for: nodeID)
    }
}

struct KnowledgeTreeNode: Codable, Identifiable, Hashable {
    var id: String
    var nameEN: String
    var nameZH: String
    var summaryEN: String
    var summaryZH: String
    var children: [KnowledgeTreeNode]
    var detail: KnowledgeNodeDetail?

    var nodeCount: Int {
        1 + children.reduce(0) { $0 + $1.nodeCount }
    }

    var allNodes: [KnowledgeTreeNode] {
        [self] + children.flatMap(\.allNodes)
    }

    func node(id: String) -> KnowledgeTreeNode? {
        if self.id == id { return self }
        for child in children {
            if let match = child.node(id: id) { return match }
        }
        return nil
    }

    func path(to nodeID: String) -> [KnowledgeTreeNode] {
        if id == nodeID { return [self] }
        for child in children {
            let childPath = child.path(to: nodeID)
            if !childPath.isEmpty { return [self] + childPath }
        }
        return []
    }

    mutating func setDetail(_ detail: KnowledgeNodeDetail, for nodeID: String) -> Bool {
        if id == nodeID {
            self.detail = detail
            return true
        }
        for index in children.indices {
            if children[index].setDetail(detail, for: nodeID) {
                return true
            }
        }
        return false
    }

    enum CodingKeys: String, CodingKey {
        case id
        case nameEN = "name_en"
        case nameZH = "name_zh"
        case summaryEN = "summary_en"
        case summaryZH = "summary_zh"
        case children
        case detail
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        nameEN = try container.decodeIfPresent(String.self, forKey: .nameEN) ?? ""
        nameZH = try container.decodeIfPresent(String.self, forKey: .nameZH) ?? ""
        summaryEN = try container.decodeIfPresent(String.self, forKey: .summaryEN) ?? ""
        summaryZH = try container.decodeIfPresent(String.self, forKey: .summaryZH) ?? ""
        children = try container.decodeIfPresent([KnowledgeTreeNode].self, forKey: .children) ?? []
        detail = try container.decodeIfPresent(KnowledgeNodeDetail.self, forKey: .detail)
    }

    init(
        id: String,
        nameEN: String,
        nameZH: String,
        summaryEN: String,
        summaryZH: String,
        children: [KnowledgeTreeNode] = [],
        detail: KnowledgeNodeDetail? = nil
    ) {
        self.id = id
        self.nameEN = nameEN
        self.nameZH = nameZH
        self.summaryEN = summaryEN
        self.summaryZH = summaryZH
        self.children = children
        self.detail = detail
    }
}

struct KnowledgeNodeDetail: Codable, Hashable {
    var definitionEN: String
    var definitionZH: String
    var relatedKnowledge: [KnowledgeRelatedItem]
    var keyFigures: [KnowledgeFigureItem]
    var applications: [BilingualNote]
    var generatedAt: Date
    var model: String

    enum CodingKeys: String, CodingKey {
        case definitionEN = "definition_en"
        case definitionZH = "definition_zh"
        case relatedKnowledge = "related_knowledge"
        case keyFigures = "key_figures"
        case applications
        case generatedAt = "generated_at"
        case model
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        definitionEN = try container.decodeIfPresent(String.self, forKey: .definitionEN) ?? ""
        definitionZH = try container.decodeIfPresent(String.self, forKey: .definitionZH) ?? ""
        relatedKnowledge = try container.decodeIfPresent([KnowledgeRelatedItem].self, forKey: .relatedKnowledge) ?? []
        keyFigures = try container.decodeIfPresent([KnowledgeFigureItem].self, forKey: .keyFigures) ?? []
        applications = try container.decodeIfPresent([BilingualNote].self, forKey: .applications) ?? []
        generatedAt = try container.decodeIfPresent(Date.self, forKey: .generatedAt) ?? Date()
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? ""
    }

    init(
        definitionEN: String,
        definitionZH: String,
        relatedKnowledge: [KnowledgeRelatedItem],
        keyFigures: [KnowledgeFigureItem],
        applications: [BilingualNote],
        generatedAt: Date = Date(),
        model: String = ""
    ) {
        self.definitionEN = definitionEN
        self.definitionZH = definitionZH
        self.relatedKnowledge = relatedKnowledge
        self.keyFigures = keyFigures
        self.applications = applications
        self.generatedAt = generatedAt
        self.model = model
    }
}

struct KnowledgeRelatedItem: Codable, Hashable {
    var nameEN: String
    var nameZH: String
    var relationEN: String
    var relationZH: String

    enum CodingKeys: String, CodingKey {
        case nameEN = "name_en"
        case nameZH = "name_zh"
        case relationEN = "relation_en"
        case relationZH = "relation_zh"
    }
}

struct KnowledgeFigureItem: Codable, Hashable {
    var nameEN: String
    var nameZH: String
    var contributionEN: String
    var contributionZH: String

    enum CodingKeys: String, CodingKey {
        case nameEN = "name_en"
        case nameZH = "name_zh"
        case contributionEN = "contribution_en"
        case contributionZH = "contribution_zh"
    }
}
