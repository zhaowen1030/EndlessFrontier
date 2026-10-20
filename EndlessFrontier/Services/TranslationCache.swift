import Foundation

@MainActor
final class TranslationCache: ObservableObject {
    @Published private(set) var entries: [String: PaperTranslation] = [:]
    var count: Int { entries.count }

    init() {
        load()
    }

    func translation(for paperID: String) -> PaperTranslation? {
        entries[paperID]
    }

    func translations(for paperIDs: [String]) -> [String: PaperTranslation] {
        var result: [String: PaperTranslation] = [:]
        for id in paperIDs {
            if let value = entries[id] { result[id] = value }
        }
        return result
    }

    func insert(_ translation: PaperTranslation) {
        entries[translation.arxivID] = translation
        saveNow()
    }

    func insert(_ translations: [PaperTranslation]) {
        guard !translations.isEmpty else { return }
        for translation in translations { entries[translation.arxivID] = translation }
        saveNow()
    }

    func removeAll() {
        entries.removeAll()
        try? FileManager.default.removeItem(at: AppPaths.translationCacheFile)
    }

    private func saveNow() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(entries)
            try AppPaths.writeAtomically(data, to: AppPaths.translationCacheFile)
        } catch {
            // Translation caching should never interrupt browsing.
            NSLog("EndlessFrontier: failed to save translation cache: \(error)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: AppPaths.translationCacheFile) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([String: PaperTranslation].self, from: data) {
            entries = decoded
        }
    }
}
