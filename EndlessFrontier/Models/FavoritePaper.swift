import Foundation

struct FavoritePaper: Codable, Identifiable, Hashable {
    let paper: Paper
    let favoritedAt: Date

    var id: String { paper.id }
}

@MainActor
final class FavoritesStore: ObservableObject {
    @Published private(set) var entries: [FavoritePaper] = []

    init() {
        load()
    }

    var count: Int { entries.count }

    var sortedEntries: [FavoritePaper] {
        entries.sorted {
            if $0.favoritedAt == $1.favoritedAt { return $0.paper.id < $1.paper.id }
            return $0.favoritedAt > $1.favoritedAt
        }
    }

    func isFavorite(_ paperID: String) -> Bool {
        entries.contains { $0.paper.id == paperID }
    }

    func entry(for paperID: String) -> FavoritePaper? {
        entries.first { $0.paper.id == paperID }
    }

    func toggle(_ paper: Paper) {
        if isFavorite(paper.id) {
            remove(paperID: paper.id)
        } else {
            add(paper)
        }
    }

    func add(_ paper: Paper) {
        entries.removeAll { $0.paper.id == paper.id }
        entries.append(FavoritePaper(paper: paper, favoritedAt: Date()))
        save()
    }

    func remove(paperID: String) {
        guard entries.contains(where: { $0.paper.id == paperID }) else { return }
        entries.removeAll { $0.paper.id == paperID }
        save()
    }

    func removeAll() {
        guard !entries.isEmpty else { return }
        entries.removeAll()
        save()
    }

    var storageSizeDescription: String {
        guard let values = try? URL(fileURLWithPath: AppPaths.favoritesFile.path)
            .resourceValues(forKeys: [.fileSizeKey]),
              let bytes = values.fileSize else { return "0 KB" }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(entries)
            try AppPaths.writeAtomically(data, to: AppPaths.favoritesFile)
        } catch {
            NSLog("EndlessFrontier: failed to save favorites: \(error)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: AppPaths.favoritesFile) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode([FavoritePaper].self, from: data) else {
            NSLog("EndlessFrontier: failed to decode favorites")
            return
        }
        var seen = Set<String>()
        entries = decoded.filter { seen.insert($0.paper.id).inserted }
    }
}
