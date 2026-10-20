import SwiftUI

struct RootView: View {
    @EnvironmentObject private var services: AppServices
    @EnvironmentObject private var state: AppState
    @State private var didApplyDebugLaunch = false

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 268, ideal: 294, max: 350)
        } detail: {
            detail
                .background(PageBackdrop(tint: detailTint))
        }
        .navigationSplitViewStyle(.balanced)
        .background {
            SystemTranslationHost(translator: services.systemTranslator)
        }
        .tint(AppTheme.accent)
        .onAppear {
            #if DEBUG
            guard !didApplyDebugLaunch else { return }
            didApplyDebugLaunch = true
            if let categoryID = DebugLaunchOptions.categoryID {
                state.openCategory(categoryID, tab: DebugLaunchOptions.startTab ?? .papers)
                NSLog("EndlessFrontier debug launch: category=\(categoryID) tab=\(state.categoryTab.rawValue) args=\(ProcessInfo.processInfo.arguments)")
            }
            if let graphNode = DebugLaunchOptions.graphNodeID {
                state.openGraph(focus: graphNode)
            }
            if DebugLaunchOptions.openFavorites {
                state.openFavorites()
            }
            if DebugLaunchOptions.forceDark {
                NSApp.appearance = NSAppearance(named: .darkAqua)
            }
            if let path = DebugLaunchOptions.sidebarRenderPath {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    DebugSnapshotCoordinator.shared.renderSidebar(services: services, to: path)
                }
            }
            if let path = DebugLaunchOptions.sidebarWindowPath {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    DebugSnapshotCoordinator.shared.renderSidebarInWindow(services: services, to: path)
                }
            }
            if let path = DebugLaunchOptions.settingsWindowPath {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    DebugSnapshotCoordinator.shared.renderSettingsInWindow(services: services, to: path)
                }
            }
            if let path = DebugLaunchOptions.categoryWindowPath,
               let categoryID = DebugLaunchOptions.categoryID {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    DebugSnapshotCoordinator.shared.renderCategoryInWindow(services: services, categoryID: categoryID, to: path)
                }
            }
            DebugSnapshotCoordinator.shared.scheduleIfNeeded()
            #endif
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch state.selection {
        case .favorites:
            FavoritesView()
        case .downloads:
            DownloadsView()
        case .category(let id):
            if let category = ArxivTaxonomy.category(id) {
                CategoryView(category: category, services: services)
                    .id(category.id)
            } else {
                EmptyState(
                    icon: "questionmark.folder",
                    titleEN: "Category not found",
                    titleZH: "找不到该分类",
                    message: "请从左侧重新选择一个 arXiv 学科分类。"
                )
            }
        case .graph, .none:
            KnowledgeGraphView()
        }
    }

    private var detailTint: Color {
        switch state.selection {
        case .favorites:
            return AppTheme.gold
        case .downloads:
            return AppTheme.cyan
        case .category(let id):
            if let category = ArxivTaxonomy.category(id) {
                return AppTheme.groupColor(category.groupID)
            }
            return AppTheme.accent
        default:
            return AppTheme.accent
        }
    }
}
