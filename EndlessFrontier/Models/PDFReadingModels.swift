import Foundation

struct PaperLineTranslation: Codable, Hashable {
    var id: Int
    var source: String
    var chinese: String
}

struct PaperVocabularyEntry: Codable, Identifiable, Hashable {
    var word: String
    var phonetic: String?
    var partOfSpeech: String?
    var meaning: String
    var example: String?
    var exampleTranslation: String?

    var id: String {
        "\(word.lowercased())|\(partOfSpeech ?? "")"
    }
}

struct PaperPageTranslation: Codable, Hashable {
    var lines: [PaperLineTranslation]
    var vocabulary: [PaperVocabularyEntry]
    var provider: String
    var model: String
    var translatedAt: Date

    func chinese(forSegmentIndex index: Int) -> String? {
        let target = index + 1
        if let line = lines.first(where: { $0.id == target }) {
            return line.chinese
        }
        if index >= 0, index < lines.count {
            return lines[index].chinese
        }
        return nil
    }

    func isComplete(for segments: [String]) -> Bool {
        guard !segments.isEmpty else { return false }
        for index in segments.indices {
            guard let chinese = chinese(forSegmentIndex: index),
                  !chinese.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return false
            }
        }
        return true
    }

    var missingLineCount: Int {
        lines.filter { $0.chinese.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }
}

struct StoredPaperPage: Codable {
    var pageIndex: Int
    var segments: [String]
    var translation: PaperPageTranslation?
}

struct PaperReadingDocument: Codable {
    var paperID: String
    var pdfPath: String
    var fingerprint: String
    var pages: [String: StoredPaperPage]
    var lastPageIndex: Int
    var updatedAt: Date
}
