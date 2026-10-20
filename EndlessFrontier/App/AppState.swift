import SwiftUI

enum SidebarSelection: Hashable {
    case graph
    case favorites
    case category(String)
}

enum CategoryTab: String, CaseIterable, Identifiable {
    case papers
    case explore
    case knowledgeTree = "tree"

    var id: String { rawValue }

    var labelEN: String {
        switch self {
        case .papers: return "Papers"
        case .explore: return "AI Research"
        case .knowledgeTree: return "Tree"
        }
    }

    var labelZH: String {
        switch self {
        case .papers: return "最新论文"
        case .explore: return "AI 探索"
        case .knowledgeTree: return "知识树"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var selection: SidebarSelection? = .graph
    @Published var categoryTab: CategoryTab = .papers
    @Published var expandedGroups: Set<String> = []
    @Published var graphFocusCategory: String?
    @Published var sidebarSearch: String = ""

    var selectedCategoryID: String? {
        if case .category(let id) = selection { return id }
        return nil
    }

    func openGraph(focus: String? = nil) {
        graphFocusCategory = focus
        selection = .graph
    }

    func openFavorites() {
        selection = .favorites
    }

    func openCategory(_ categoryID: String, tab: CategoryTab = .papers) {
        if let group = ArxivTaxonomy.category(categoryID)?.groupID {
            expandedGroups.insert(group)
        }
        categoryTab = tab
        selection = .category(categoryID)
    }

    func toggleGroup(_ id: String) {
        if expandedGroups.contains(id) {
            expandedGroups.remove(id)
        } else {
            expandedGroups.insert(id)
        }
    }

    func openExploreForCurrentCategory() {
        if let id = selectedCategoryID {
            openCategory(id, tab: .explore)
        }
    }
}
