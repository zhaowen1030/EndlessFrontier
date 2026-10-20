import Foundation

@MainActor
final class ReportStore: ObservableObject {
    @Published private(set) var reports: [String: AIReport] = [:]
    @Published private(set) var loadError: String?

    init() {
        AppPaths.ensureDirectories()
        loadAll()
    }

    var count: Int { reports.count }

    func report(for categoryID: String) -> AIReport? {
        reports[categoryID]
    }

    func save(_ report: AIReport) {
        reports[report.categoryID] = report
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(report)
            let url = AppPaths.reportsDirectory.appendingPathComponent("\(report.categoryID).json")
            try AppPaths.writeAtomically(data, to: url)
            loadError = nil
        } catch {
            loadError = "无法保存报告：\(error.localizedDescription)"
            NSLog("EndlessFrontier: report save failed: \(error)")
        }
    }

    func delete(categoryID: String) {
        reports.removeValue(forKey: categoryID)
        let url = AppPaths.reportsDirectory.appendingPathComponent("\(categoryID).json")
        try? FileManager.default.removeItem(at: url)
    }

    func deleteAll() {
        reports.removeAll()
        try? FileManager.default.removeItem(at: AppPaths.reportsDirectory)
        AppPaths.ensureDirectories()
    }

    func reportFileURL(categoryID: String) -> URL {
        AppPaths.reportsDirectory.appendingPathComponent("\(categoryID).json")
    }

    var storageSizeDescription: String {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: AppPaths.reportsDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        )) ?? []
        let bytes = files.reduce(0) { partial, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return partial + size
        }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private func loadAll() {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: AppPaths.reportsDirectory,
            includingPropertiesForKeys: nil
        )) ?? []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var loaded: [String: AIReport] = [:]
        for file in files where file.pathExtension == "json" {
            do {
                let data = try Data(contentsOf: file)
                let report = try decoder.decode(AIReport.self, from: data)
                if !report.categoryID.isEmpty {
                    loaded[report.categoryID] = report
                }
            } catch {
                NSLog("EndlessFrontier: could not load \(file.lastPathComponent): \(error)")
            }
        }
        reports = loaded
    }
}
