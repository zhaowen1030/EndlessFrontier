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

struct PaperTextBlock: Codable, Hashable, Identifiable {
    var id: Int
    var source: String
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var fontSize: Double
    var isMath: Bool
    var isHeading: Bool

    var rect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

struct PaperTranslatedBlock: Codable, Hashable, Identifiable {
    var id: Int
    var source: String
    var chinese: String
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var fontSize: Double
    var isMath: Bool
    var isHeading: Bool

    var rect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

struct PaperTerm: Codable, Hashable {
    var source: String
    var target: String
}

struct PaperPageTranslation: Codable, Hashable {
    var lines: [PaperLineTranslation]
    var vocabulary: [PaperVocabularyEntry]
    var provider: String
    var model: String
    var translatedAt: Date
    var blocks: [PaperTranslatedBlock]? = nil
    var terms: [PaperTerm]? = nil

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

    var hasLayoutBlocks: Bool {
        !(blocks ?? []).isEmpty
    }

    var isLayoutComplete: Bool {
        guard let blocks, !blocks.isEmpty else { return false }
        return blocks
            .filter { !$0.isMath }
            .allSatisfy { !$0.chinese.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
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
    var glossary: [String: String]? = nil
}
