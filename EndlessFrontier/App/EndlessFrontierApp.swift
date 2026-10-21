import SwiftUI
import AppKit

@main
struct EndlessFrontierApp: App {
    @StateObject private var services = AppServices()
    #if DEBUG
    @NSApplicationDelegateAdaptor(DebugDemoAppDelegate.self) private var debugDemoDelegate
    #endif

    init() {
        // macOS 26 draws NavigationSplitView sidebars as inset floating glass
        // panels. Keep this app's sidebar flush with the window's left edge.
        UserDefaults.standard.set(
            false,
            forKey: "NSSplitViewItemSidebarDefaultsToFloatingAppearance"
        )
    }

    var body: some Scene {
        WindowGroup("无尽前沿") {
            RootView()
                .environmentObject(services)
                .environmentObject(services.state)
                .environmentObject(services.settings)
                .environmentObject(services.reports)
                .environmentObject(services.translations)
                .environmentObject(services.downloads)
                .environmentObject(services.favorites)
                .frame(minWidth: 1080, minHeight: 680)
        }
        .defaultSize(width: 1440, height: 920)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .windowResizability(.contentMinSize)
        .commands {
            AppCommands(state: services.state)
        }

        Settings {
            SettingsView()
                .environmentObject(services)
                .environmentObject(services.settings)
                .environmentObject(services.reports)
                .environmentObject(services.translations)
                .environmentObject(services.downloads)
                .environmentObject(services.favorites)
                .frame(width: 800, height: 640)
        }
    }
}

struct AppCommands: Commands {
    @ObservedObject var state: AppState

    var body: some Commands {
        CommandGroup(replacing: .newItem) {}

        CommandMenu("探索 Explore") {
            Button("搜索学科 Find Discipline") {
                NotificationCenter.default.post(name: .focusSidebarSearch, object: nil)
            }
            .keyboardShortcut("f", modifiers: [.command])

            Button("知识图谱 Knowledge Graph") {
                state.openGraph()
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])

            Button("AI 探索当前学科 Explore Discipline") {
                state.openExploreForCurrentCategory()
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(state.selectedCategoryID == nil)
        }

        CommandGroup(after: .toolbar) {
            Button("刷新论文 Refresh Papers") {
                NotificationCenter.default.post(name: .refreshPapers, object: nil)
            }
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(state.selectedCategoryID == nil)
        }
    }
}

extension Notification.Name {
    static let refreshPapers = Notification.Name("EndlessFrontier.refreshPapers")
    static let focusSidebarSearch = Notification.Name("EndlessFrontier.focusSidebarSearch")
}
