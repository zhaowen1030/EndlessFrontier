import Foundation

struct Paper: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let abstract: String
    let authors: [String]
    let published: Date
    let updated: Date
    let primaryCategory: String
    let categories: [String]
    let absURL: URL
    let pdfURL: URL
    let comment: String?
    let journalReference: String?

    var authorLine: String {
        guard !authors.isEmpty else { return "Unknown authors" }
        if authors.count <= 4 { return authors.joined(separator: ", ") }
        return authors.prefix(3).joined(separator: ", ") + " et al."
    }

    var arxivURL: URL {
        URL(string: "https://arxiv.org/abs/\(id)") ?? absURL
    }

    var year: String {
        String(Calendar.current.component(.year, from: published))
    }
}

struct PaperTranslation: Codable, Hashable {
    let arxivID: String
    var titleZH: String
    var abstractZH: String
    var model: String
    var createdAt: Date
}

struct ArxivPage {
    let papers: [Paper]
    let totalResults: Int
    let startIndex: Int
}

enum ArxivSort: String, CaseIterable, Identifiable {
    case newest
    case updated
    case relevance

    var id: String { rawValue }

    var labelEN: String {
        switch self {
        case .newest: return "Newest"
        case .updated: return "Recently updated"
        case .relevance: return "Relevance"
        }
    }

    var labelZH: String {
        switch self {
        case .newest: return "最新提交"
        case .updated: return "最近更新"
        case .relevance: return "相关度"
        }
    }
}

enum ArxivError: LocalizedError {
    case invalidURL
    case network(String)
    case http(Int)
    case parse(String)
    case empty

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无法构建 arXiv 请求。"
        case .network(let detail):
            return "无法连接 arXiv：\(detail)"
        case .http(let status):
            if status == 429 {
                return "arXiv 暂时限制了请求频率，请稍后再试。"
            }
            return "arXiv 返回了 HTTP \(status)。"
        case .parse(let detail):
            return "无法解析 arXiv 响应：\(detail)"
        case .empty:
            return "这个分类下暂时没有找到论文。"
        }
    }
}
