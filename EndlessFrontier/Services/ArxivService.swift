import Foundation

actor ArxivService {
    static let shared = ArxivService()

    private let session: URLSession
    private var lastRequestAt: Date?

    private init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 40
        configuration.timeoutIntervalForResource = 90
        configuration.httpAdditionalHeaders = [
            "Accept": "application/atom+xml",
            "User-Agent": "EndlessFrontier/1.0 (macOS; arXiv reader)"
        ]
        session = URLSession(configuration: configuration)
    }

    func fetchPage(
        category: String,
        query: String = "",
        sort: ArxivSort = .newest,
        start: Int = 0,
        count: Int = 25
    ) async throws -> ArxivPage {
        try await throttle()
        let search = Self.makeSearchQuery(category: category, freeText: query)
        var components = URLComponents(string: "https://export.arxiv.org/api/query")
        components?.queryItems = [
            URLQueryItem(name: "search_query", value: search),
            URLQueryItem(name: "start", value: String(start)),
            URLQueryItem(name: "max_results", value: String(count)),
            URLQueryItem(name: "sortBy", value: sort.arxivValue),
            URLQueryItem(name: "sortOrder", value: "descending")
        ]
        guard let url = components?.url else { throw ArxivError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        let data = try await loadData(request)
        let parser = ArxivFeedParser()
        guard parser.parse(data) else {
            throw ArxivError.parse(parser.failureDescription)
        }
        return ArxivPage(
            papers: parser.papers,
            totalResults: parser.totalResults ?? parser.papers.count,
            startIndex: start
        )
    }

    private func throttle() async throws {
        if let lastRequestAt {
            let elapsed = Date().timeIntervalSince(lastRequestAt)
            let minimumGap = 1.15
            if elapsed < minimumGap {
                try await Task.sleep(nanoseconds: UInt64((minimumGap - elapsed) * 1_000_000_000))
            }
        }
        lastRequestAt = Date()
    }

    private func loadData(_ request: URLRequest) async throws -> Data {
        var lastError: Error?
        for attempt in 0..<3 {
            try Task.checkCancellation()
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw ArxivError.parse("响应不是 HTTP 响应。")
                }
                if (200..<300).contains(http.statusCode) {
                    return data
                }
                if (http.statusCode == 429 || http.statusCode >= 500), attempt < 2 {
                    let backoff = Double(attempt + 1) * 2.0
                    try await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
                    lastError = ArxivError.http(http.statusCode)
                    continue
                }
                throw ArxivError.http(http.statusCode)
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as URLError where error.code == .cancelled {
                throw CancellationError()
            } catch let error as ArxivError {
                if attempt == 2 { throw error }
                lastError = error
            } catch {
                if attempt == 2 { throw ArxivError.network(error.localizedDescription) }
                lastError = error
                try? await Task.sleep(nanoseconds: 900_000_000)
            }
        }
        throw lastError ?? ArxivError.network("未知错误")
    }

    static func makeSearchQuery(category: String, freeText: String) -> String {
        let base = "cat:\(category)"
        let cleaned = freeText
            .replacingOccurrences(of: "\\", with: " ")
            .replacingOccurrences(of: "\"", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return base }
        let escaped = cleaned.replacingOccurrences(of: ":", with: " ")
        return "\(base) AND (ti:\"\(escaped)\" OR abs:\"\(escaped)\" OR au:\"\(escaped)\")"
    }
}

private extension ArxivSort {
    var arxivValue: String {
        switch self {
        case .newest: return "submittedDate"
        case .updated: return "lastUpdatedDate"
        case .relevance: return "relevance"
        }
    }
}

private final class ArxivFeedParser: NSObject, XMLParserDelegate {
    private(set) var papers: [Paper] = []
    private(set) var totalResults: Int?
    private(set) var failureDescription = "未知的 XML 结构"

    private var inEntry = false
    private var insideAuthor = false
    private var currentText = ""
    private var entry = EntryDraft()

    func parse(_ data: Data) -> Bool {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = false
        parser.shouldResolveExternalEntities = false
        let success = parser.parse()
        if !success {
            failureDescription = parser.parserError?.localizedDescription ?? "XML 解析失败"
        }
        return success
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentText = ""
        let element = Self.localName(elementName)
        switch element {
        case "entry":
            inEntry = true
            entry = EntryDraft()
        case "author":
            insideAuthor = true
        case "category":
            if inEntry, let term = attributeDict["term"] {
                entry.categories.append(term)
            }
        case "primary_category":
            if inEntry, let term = attributeDict["term"] {
                entry.primaryCategory = term
            }
        case "link":
            guard inEntry, let href = attributeDict["href"] else { break }
            let rel = attributeDict["rel"] ?? ""
            let title = attributeDict["title"] ?? ""
            let type = attributeDict["type"] ?? ""
            if rel == "alternate" {
                entry.absURL = href
            } else if title.lowercased() == "pdf" || type == "application/pdf" {
                entry.pdfURL = href
            }
            if entry.absURL == nil, rel == "alternate" {
                entry.absURL = href
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let element = Self.localName(elementName)
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        switch element {
        case "totalResults":
            totalResults = Int(text)
        case "id":
            if inEntry { entry.id = text }
        case "title":
            if inEntry { entry.title = Self.clean(text) }
        case "summary":
            if inEntry { entry.summary = Self.clean(text) }
        case "published":
            if inEntry { entry.published = Self.date(text) }
        case "updated":
            if inEntry { entry.updated = Self.date(text) }
        case "name":
            if inEntry, insideAuthor { entry.authors.append(Self.clean(text)) }
        case "author":
            insideAuthor = false
        case "comment":
            if inEntry { entry.comment = Self.clean(text) }
        case "journal_ref":
            if inEntry { entry.journalRef = Self.clean(text) }
        case "entry":
            if let paper = entry.build() { papers.append(paper) }
            inEntry = false
        default:
            break
        }
        currentText = ""
    }

    private static func localName(_ name: String) -> String {
        name.split(separator: ":").last.map(String.init) ?? name
    }

    private static func clean(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func date(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }

    private struct EntryDraft {
        var id = ""
        var title = ""
        var summary = ""
        var authors: [String] = []
        var categories: [String] = []
        var primaryCategory: String?
        var absURL: String?
        var pdfURL: String?
        var published: Date?
        var updated: Date?
        var comment: String?
        var journalRef: String?

        func build() -> Paper? {
            guard !title.isEmpty, !id.isEmpty else { return nil }
            let rawID = id.split(separator: "/").last.map(String.init) ?? id
            let baseID = rawID.replacingOccurrences(
                of: #"v\d+$"#,
                with: "",
                options: .regularExpression
            )
            guard !baseID.isEmpty else { return nil }
            let abs = normalizedURL(absURL) ?? URL(string: "https://arxiv.org/abs/\(baseID)")!
            let pdf = normalizedURL(pdfURL) ?? URL(string: "https://arxiv.org/pdf/\(baseID)")!
            let primary = primaryCategory ?? categories.first ?? ""
            return Paper(
                id: baseID,
                title: title,
                abstract: summary,
                authors: authors.filter { !$0.isEmpty },
                published: published ?? Date(),
                updated: updated ?? published ?? Date(),
                primaryCategory: primary,
                categories: categories,
                absURL: abs,
                pdfURL: pdf,
                comment: comment?.isEmpty == true ? nil : comment,
                journalReference: journalRef?.isEmpty == true ? nil : journalRef
            )
        }

        private func normalizedURL(_ string: String?) -> URL? {
            guard var string else { return nil }
            if string.hasPrefix("http://") {
                string = "https://" + string.dropFirst("http://".count)
            }
            return URL(string: string)
        }
    }
}
