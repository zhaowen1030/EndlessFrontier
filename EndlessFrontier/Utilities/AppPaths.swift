import Foundation

enum AppPaths {
    static let supportDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("EndlessFrontier", isDirectory: true)
    }()

    static let reportsDirectory = supportDirectory.appendingPathComponent("Reports", isDirectory: true)
    static let annotationsDirectory = supportDirectory.appendingPathComponent("Annotations", isDirectory: true)
    static let knowledgeTreesDirectory = supportDirectory.appendingPathComponent("KnowledgeTrees", isDirectory: true)
    static let cacheDirectory = supportDirectory.appendingPathComponent("Cache", isDirectory: true)
    static let logsDirectory = supportDirectory.appendingPathComponent("Logs", isDirectory: true)

    static let translationCacheFile = cacheDirectory.appendingPathComponent("translations.json")
    static let favoritesFile = supportDirectory.appendingPathComponent("favorites.json")
    static let downloadHistoryFile = supportDirectory.appendingPathComponent("downloaded-papers.json")
    static let readerDirectory = supportDirectory.appendingPathComponent("Reader", isDirectory: true)

    static func annotationFileURL(categoryID: String) -> URL {
        annotationsDirectory.appendingPathComponent("\(categoryID).json")
    }

    static func knowledgeTreeFileURL(categoryID: String) -> URL {
        knowledgeTreesDirectory.appendingPathComponent("\(categoryID).json")
    }

    static func readerFileURL(paperID: String) -> URL {
        readerDirectory.appendingPathComponent("\(paperID).json")
    }

    static let downloadsDirectory: URL = {
        let base = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        return base.appendingPathComponent("无尽前沿论文", isDirectory: true)
    }()

    static func ensureDirectories() {
        for directory in [supportDirectory, reportsDirectory, annotationsDirectory, knowledgeTreesDirectory, cacheDirectory, logsDirectory, downloadsDirectory, readerDirectory] {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    static var katexDirectory: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("KaTeX", isDirectory: true)
    }

    @discardableResult
    static func writeAtomically(_ data: Data, to url: URL) throws -> URL {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        return url
    }
}

enum JSONExtractor {
    /// Models occasionally wrap JSON in prose or markdown fences. Extract the
    /// outermost JSON object without trying to interpret the content first.
    static func objectData(from text: String) -> Data? {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            if let firstNewline = cleaned.firstIndex(of: "\n") {
                cleaned = String(cleaned[cleaned.index(after: firstNewline)...])
            }
            if let range = cleaned.range(of: "```", options: .backwards) {
                cleaned = String(cleaned[..<range.lowerBound])
            }
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let start = cleaned.firstIndex(of: "{") else { return nil }
        var depth = 0
        var inString = false
        var escaped = false
        var index = start
        while index < cleaned.endIndex {
            let character = cleaned[index]
            if inString {
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    inString = false
                }
            } else {
                if character == "\"" {
                    inString = true
                } else if character == "{" {
                    depth += 1
                } else if character == "}" {
                    depth -= 1
                    if depth == 0 {
                        let json = String(cleaned[start...index])
                        guard let data = json.data(using: .utf8),
                              (try? JSONSerialization.jsonObject(with: data)) != nil else {
                            return nil
                        }
                        return data
                    }
                }
            }
            index = cleaned.index(after: index)
        }
        return nil
    }

    static func object(from text: String) -> [String: Any]? {
        guard let data = objectData(from: text) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfEmpty: String? {
        let value = trimmed
        return value.isEmpty ? nil : value
    }

    var cleanedForDisplay: String {
        replacingOccurrences(of: "\u{00a0}", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
