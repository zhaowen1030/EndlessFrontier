import Foundation

@MainActor
final class KnowledgeTreeStore: ObservableObject {
    @Published private(set) var trees: [String: KnowledgeTree] = [:]
    @Published private(set) var loadError: String?

    init() {
        AppPaths.ensureDirectories()
        loadAll()
    }

    func tree(for categoryID: String) -> KnowledgeTree? {
        trees[categoryID]
    }

    func save(_ tree: KnowledgeTree) {
        trees[tree.categoryID] = tree
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(tree)
            try AppPaths.writeAtomically(
                data,
                to: AppPaths.knowledgeTreeFileURL(categoryID: tree.categoryID)
            )
            loadError = nil
        } catch {
            loadError = "无法保存知识树：\(error.localizedDescription)"
            NSLog("EndlessFrontier: knowledge tree save failed: \(error)")
        }
    }

    func delete(categoryID: String) {
        trees.removeValue(forKey: categoryID)
        let url = AppPaths.knowledgeTreeFileURL(categoryID: categoryID)
        try? FileManager.default.removeItem(at: url)
    }

    func deleteAll() {
        trees.removeAll()
        try? FileManager.default.removeItem(at: AppPaths.knowledgeTreesDirectory)
        AppPaths.ensureDirectories()
    }

    var count: Int { trees.count }

    var storageSizeDescription: String {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: AppPaths.knowledgeTreesDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        )) ?? []
        let bytes = files.reduce(0) { partial, url in
            partial + ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private func loadAll() {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: AppPaths.knowledgeTreesDirectory,
            includingPropertiesForKeys: nil
        )) ?? []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var loaded: [String: KnowledgeTree] = [:]
        for file in files where file.pathExtension == "json" {
            do {
                let data = try Data(contentsOf: file)
                let tree = try decoder.decode(KnowledgeTree.self, from: data)
                loaded[tree.categoryID] = tree
            } catch {
                NSLog("EndlessFrontier: failed to load knowledge tree \(file.lastPathComponent): \(error)")
            }
        }
        trees = loaded
    }
}
