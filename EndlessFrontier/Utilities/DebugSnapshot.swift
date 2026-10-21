#if DEBUG
import AppKit
import SwiftUI

/// Development-only harness used to inspect the real running window without
/// requiring Screen Recording / Accessibility permissions.
enum DebugLaunchOptions {
    static var snapshotPath: String? {
        value(for: "--snapshot")
    }

    static var categoryID: String? {
        value(for: "--category")
    }

    static var graphNodeID: String? {
        value(for: "--graph-node")
    }

    static var reportSection: String? {
        value(for: "--report-section")
    }

    static var autoGenerateReport: Bool {
        ProcessInfo.processInfo.arguments.contains("--generate")
    }

    static var downloadFirstPaper: Bool {
        ProcessInfo.processInfo.arguments.contains("--download-first")
    }

    static var suppressAutoTranslation: Bool {
        ProcessInfo.processInfo.arguments.contains("--no-auto-translate")
    }

    static var forceAnnotationMode: Bool {
        ProcessInfo.processInfo.arguments.contains("--annotate")
    }

    static var startTab: CategoryTab? {
        guard let raw = value(for: "--tab") else { return nil }
        return CategoryTab(rawValue: raw)
    }

    static var sidebarRenderPath: String? {
        value(for: "--render-sidebar")
    }

    static var sidebarWindowPath: String? {
        value(for: "--sidebar-window")
    }

    static var settingsWindowPath: String? {
        value(for: "--settings-window")
    }

    static var settingsSection: String? {
        value(for: "--settings-section")
    }

    static var categoryWindowPath: String? {
        value(for: "--category-window")
    }

    static var openFavorites: Bool {
        ProcessInfo.processInfo.arguments.contains("--favorites")
    }

    static var openDownloads: Bool {
        ProcessInfo.processInfo.arguments.contains("--downloads")
    }

    static var openReader: Bool {
        ProcessInfo.processInfo.arguments.contains("--reader")
    }

    static var demoCapturePath: String? {
        value(for: "--demo-capture")
    }

    static var demoSidebarPath: String? {
        value(for: "--demo-sidebar")
    }

    static var knowledgeTreeNodeID: String? {
        value(for: "--tree-node")
    }

    static var forceDark: Bool {
        ProcessInfo.processInfo.arguments.contains("--dark")
    }

    static var snapshotDelay: TimeInterval {
        if let raw = value(for: "--snapshot-delay"), let value = TimeInterval(raw) {
            return value
        }
        return 7
    }

    private static func value(for flag: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: flag), index + 1 < args.count else { return nil }
        return args[index + 1]
    }
}

@MainActor
final class DebugSnapshotCoordinator {
    static let shared = DebugSnapshotCoordinator()
    private var hasScheduled = false

    func scheduleIfNeeded() {
        guard !hasScheduled, let path = DebugLaunchOptions.snapshotPath else { return }
        hasScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + DebugLaunchOptions.snapshotDelay) {
            self.capture(to: path)
        }
    }

    private var auxiliaryWindow: NSWindow?

    func renderCategoryInWindow(services: AppServices, categoryID: String, to path: String) {
        guard let category = ArxivTaxonomy.category(categoryID) else {
            NSLog("EndlessFrontier debug category window: unknown category \(categoryID)")
            NSApp.terminate(nil)
            return
        }
        services.state.categoryTab = DebugLaunchOptions.startTab ?? .papers
        let view = CategoryView(category: category, services: services)
            .environmentObject(services.state)
            .environmentObject(services.settings)
            .environmentObject(services.downloads)
            .environmentObject(services.reports)
            .environmentObject(services.translations)
            .environmentObject(services.favorites)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 1360, height: 880)
        let window = NSWindow(
            contentRect: NSRect(x: 120, y: 80, width: 1360, height: 880),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Category preview"
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        auxiliaryWindow = window
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
            hosting.layoutSubtreeIfNeeded()
            if let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) {
                hosting.cacheDisplay(in: hosting.bounds, to: rep)
                if let data = rep.representation(using: .png, properties: [:]) {
                    try? data.write(to: URL(fileURLWithPath: path))
                    NSLog("EndlessFrontier debug category window rendered to \(path)")
                }
            }
            NSApp.terminate(nil)
        }
    }

    func renderSettingsInWindow(services: AppServices, to path: String) {
        let view = SettingsView()
            .environmentObject(services)
            .environmentObject(services.settings)
            .environmentObject(services.reports)
            .environmentObject(services.translations)
            .environmentObject(services.downloads)
            .environmentObject(services.favorites)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 800, height: 640)
        let window = NSWindow(
            contentRect: NSRect(x: 220, y: 140, width: 800, height: 640),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings preview"
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        auxiliaryWindow = window
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            hosting.layoutSubtreeIfNeeded()
            if let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) {
                hosting.cacheDisplay(in: hosting.bounds, to: rep)
                if let data = rep.representation(using: .png, properties: [:]) {
                    try? data.write(to: URL(fileURLWithPath: path))
                    NSLog("EndlessFrontier debug settings window rendered to \(path)")
                }
            }
            NSApp.terminate(nil)
        }
    }

    func renderSidebarInWindow(services: AppServices, to path: String) {
        let view = SidebarView()
            .environmentObject(services.state)
            .environmentObject(services.settings)
            .environmentObject(services.reports)
            .environmentObject(services.translations)
            .environmentObject(services.downloads)
            .environmentObject(services.favorites)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 294, height: 880)
        let window = NSWindow(
            contentRect: NSRect(x: 200, y: 200, width: 294, height: 880),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Sidebar preview"
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        auxiliaryWindow = window
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            hosting.layoutSubtreeIfNeeded()
            if let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) {
                hosting.cacheDisplay(in: hosting.bounds, to: rep)
                if let data = rep.representation(using: .png, properties: [:]) {
                    try? data.write(to: URL(fileURLWithPath: path))
                    NSLog("EndlessFrontier debug sidebar window rendered to \(path)")
                }
            }
            NSApp.terminate(nil)
        }
    }

    func renderSidebar(services: AppServices, to path: String) {
        let view = SidebarView()
            .environmentObject(services.state)
            .environmentObject(services.settings)
            .environmentObject(services.reports)
            .environmentObject(services.translations)
            .environmentObject(services.downloads)
            .environmentObject(services.favorites)
            .frame(width: 294, height: 880)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        if let image = renderer.nsImage,
           let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
            NSLog("EndlessFrontier debug sidebar rendered to \(path)")
        } else {
            NSLog("EndlessFrontier debug sidebar render failed")
        }
        NSApp.terminate(nil)
    }

    private func capture(to path: String) {
        guard let window = NSApp.windows.first(where: { $0.isVisible && $0.contentView != nil }) else {
            NSLog("EndlessFrontier debug snapshot: no visible window")
            NSApp.terminate(nil)
            return
        }
        window.makeKeyAndOrderFront(nil)
        window.displayIfNeeded()
        guard let view = window.contentView else {
            NSApp.terminate(nil)
            return
        }
        let bounds = view.bounds
        guard let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else {
            NSLog("EndlessFrontier debug snapshot: could not create bitmap")
            NSApp.terminate(nil)
            return
        }
        view.cacheDisplay(in: bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
            NSLog("EndlessFrontier debug snapshot written to \(path)")
        }
        NSApp.terminate(nil)
    }
}

/// Hosts the real RootView in a standalone window for deterministic demo
/// capture, independent of the WindowGroup's state restoration behavior.
@MainActor
final class DebugDemoAppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var sidebarWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let path = DebugLaunchOptions.demoCapturePath else { return }

        let services = AppServices()
        if DebugLaunchOptions.openFavorites {
            services.state.openFavorites()
        } else if DebugLaunchOptions.openDownloads {
            services.state.openDownloads()
        } else if let categoryID = DebugLaunchOptions.categoryID {
            services.state.openCategory(categoryID, tab: DebugLaunchOptions.startTab ?? .papers)
        } else if let graphNode = DebugLaunchOptions.graphNodeID {
            services.state.openGraph(focus: graphNode)
        }

        let root = RootView()
            .environmentObject(services)
            .environmentObject(services.state)
            .environmentObject(services.settings)
            .environmentObject(services.reports)
            .environmentObject(services.translations)
            .environmentObject(services.downloads)
            .environmentObject(services.favorites)

        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(x: 0, y: 0, width: 1728, height: 1083)

        let window = NSWindow(
            contentRect: NSRect(x: 80, y: 80, width: 1728, height: 1083),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "无尽前沿"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isRestorable = false
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window

        let delay = max(DebugLaunchOptions.snapshotDelay, 2)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.capture(hosting, services: services, contentPath: path)
        }
    }

    private func capture(_ hosting: NSView, services: AppServices, contentPath: String) {
        hosting.layoutSubtreeIfNeeded()
        if let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) {
            hosting.cacheDisplay(in: hosting.bounds, to: rep)
            if let data = rep.representation(using: .png, properties: [:]) {
                try? data.write(to: URL(fileURLWithPath: contentPath))
                NSLog("EndlessFrontier demo captured to \(contentPath)")
            }
        }

        guard let sidebarPath = DebugLaunchOptions.demoSidebarPath else {
            NSApp.terminate(nil)
            return
        }

        // The NavigationSplitView sidebar lives in an AppKit glass layer that
        // does not draw through cacheDisplay, so render SidebarView on its own
        // at the same height for compositing next to the detail snapshot.
        let sidebar = SidebarView()
            .environmentObject(services.state)
            .environmentObject(services.settings)
            .environmentObject(services.reports)
            .environmentObject(services.translations)
            .environmentObject(services.downloads)
            .environmentObject(services.favorites)
            .frame(width: 294, height: 1083)
        let sideHosting = NSHostingView(rootView: sidebar)
        sideHosting.frame = NSRect(x: 0, y: 0, width: 294, height: 1083)
        let sideWindow = NSWindow(
            contentRect: NSRect(x: 80, y: 80, width: 294, height: 1083),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        sideWindow.contentView = sideHosting
        sideWindow.orderFront(nil)
        self.sidebarWindow = sideWindow

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            sideHosting.layoutSubtreeIfNeeded()
            if let rep = sideHosting.bitmapImageRepForCachingDisplay(in: sideHosting.bounds) {
                sideHosting.cacheDisplay(in: sideHosting.bounds, to: rep)
                if let data = rep.representation(using: .png, properties: [:]) {
                    try? data.write(to: URL(fileURLWithPath: sidebarPath))
                    NSLog("EndlessFrontier demo sidebar captured to \(sidebarPath)")
                }
            }
            NSApp.terminate(nil)
        }
    }
}
#endif
