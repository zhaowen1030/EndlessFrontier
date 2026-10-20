import Foundation
import AppKit

struct PaperDownloadState: Equatable {
    enum Phase: Equatable {
        case downloading
        case downloaded(URL)
        case failed(String)
    }

    var phase: Phase

    var isDownloading: Bool {
        if case .downloading = phase { return true }
        return false
    }

    var localURL: URL? {
        if case .downloaded(let url) = phase { return url }
        return nil
    }

    var errorMessage: String? {
        if case .failed(let message) = phase { return message }
        return nil
    }
}

struct DownloadedPaper: Codable, Identifiable, Hashable {
    let paper: Paper
    let downloadedAt: Date
    let localPath: String

    var id: String { paper.id }
    var localURL: URL { URL(fileURLWithPath: localPath) }
}

@MainActor
final class DownloadManager: ObservableObject {
    @Published private(set) var states: [String: PaperDownloadState] = [:]
    @Published private(set) var downloadedPapers: [DownloadedPaper] = []
    private var inFlight: Set<String> = []

    var downloadFolder: URL { AppPaths.downloadsDirectory }

    var sortedDownloadedPapers: [DownloadedPaper] {
        downloadedPapers.sorted {
            if $0.downloadedAt == $1.downloadedAt { return $0.paper.id < $1.paper.id }
            return $0.downloadedAt > $1.downloadedAt
        }
    }

    init() {
        AppPaths.ensureDirectories()
        loadHistory()
        importExistingDownloads()
    }

    var downloadedCount: Int {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: downloadFolder,
            includingPropertiesForKeys: nil
        )) ?? []
        return files.filter { $0.pathExtension.lowercased() == "pdf" }.count
    }

    var downloadsSizeDescription: String {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: downloadFolder,
            includingPropertiesForKeys: [.fileSizeKey]
        )) ?? []
        let bytes = files.reduce(0) { partial, url in
            partial + ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    func state(for paperID: String) -> PaperDownloadState? {
        states[paperID]
    }

    func isDownloading(_ paperID: String) -> Bool {
        states[paperID]?.isDownloading == true
    }

    func download(_ paper: Paper, force: Bool = false) {
        guard !inFlight.contains(paper.id) else { return }
        if !force, let existing = states[paper.id]?.localURL,
           FileManager.default.fileExists(atPath: existing.path) {
            states[paper.id] = .init(phase: .downloaded(existing))
            return
        }

        let destination = destinationURL(for: paper)
        if !force, FileManager.default.fileExists(atPath: destination.path) {
            states[paper.id] = .init(phase: .downloaded(destination))
            recordDownload(paper, at: destination, date: fileDate(destination))
            return
        }

        inFlight.insert(paper.id)
        states[paper.id] = .init(phase: .downloading)

        Task { [weak self] in
            guard let self else { return }
            do {
                AppPaths.ensureDirectories()
                var request = URLRequest(url: paper.pdfURL)
                request.timeoutInterval = 120
                request.setValue("EndlessFrontier/1.0 (macOS; arXiv reader)", forHTTPHeaderField: "User-Agent")
                let (temporaryURL, response) = try await URLSession.shared.download(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw DownloadError.invalidResponse
                }
                guard (200..<300).contains(http.statusCode) else {
                    throw DownloadError.http(http.statusCode)
                }
                let directory = destination.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.moveItem(at: temporaryURL, to: destination)
                self.inFlight.remove(paper.id)
                self.states[paper.id] = .init(phase: .downloaded(destination))
                self.recordDownload(paper, at: destination, date: Date())
            } catch {
                self.inFlight.remove(paper.id)
                self.states[paper.id] = .init(phase: .failed(error.localizedDescription))
            }
        }
    }

    func open(_ paper: Paper) {
        guard let url = states[paper.id]?.localURL else { return }
        NSWorkspace.shared.open(url)
    }

    func reveal(_ paper: Paper) {
        guard let url = states[paper.id]?.localURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func storageDescription() -> String {
        "\(downloadedCount) 个 PDF · \(downloadsSizeDescription)"
    }

    func openDownloadsFolder() {
        try? FileManager.default.createDirectory(at: downloadFolder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(downloadFolder)
    }

    func removeAllDownloads() {
        try? FileManager.default.removeItem(at: downloadFolder)
        try? FileManager.default.createDirectory(at: downloadFolder, withIntermediateDirectories: true)
        states.removeAll()
        downloadedPapers.removeAll()
        try? FileManager.default.removeItem(at: AppPaths.downloadHistoryFile)
    }

    func restoreDownloadedStates(for papers: [Paper]) {
        for paper in papers {
            if let existing = states[paper.id]?.localURL,
               FileManager.default.fileExists(atPath: existing.path) { continue }
            let destination = destinationURL(for: paper)
            if FileManager.default.fileExists(atPath: destination.path) {
                states[paper.id] = .init(phase: .downloaded(destination))
                if !downloadedPapers.contains(where: { $0.paper.id == paper.id }) {
                    recordDownload(paper, at: destination, date: fileDate(destination))
                }
            }
        }
    }

    private func recordDownload(_ paper: Paper, at url: URL, date: Date) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        downloadedPapers.removeAll { $0.paper.id == paper.id }
        downloadedPapers.append(DownloadedPaper(
            paper: paper,
            downloadedAt: date,
            localPath: url.path
        ))
        saveHistory()
    }

    private func fileDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
    }

    /// Older versions kept downloaded PDFs on disk without a local download
    /// history. Rebuild entries from the `<arXiv id> <title>.pdf` file names so
    /// those completed downloads appear in the library, then enrich the
    /// metadata from arXiv in the background.
    private func importExistingDownloads() {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: downloadFolder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        var knownIDs = Set(downloadedPapers.map(\.paper.id))
        var imported = false

        for file in files where file.pathExtension.lowercased() == "pdf" {
            guard let (id, title) = Self.arxivIDAndTitle(fromFileName: file.lastPathComponent),
                  knownIDs.insert(id).inserted else { continue }
            let date = fileDate(file)
            let paper = Paper(
                id: id,
                title: title,
                abstract: "",
                authors: [],
                published: date,
                updated: date,
                primaryCategory: "arXiv",
                categories: [],
                absURL: URL(string: "https://arxiv.org/abs/\(id)") ?? file,
                pdfURL: URL(string: "https://arxiv.org/pdf/\(id)") ?? file,
                comment: nil,
                journalReference: nil
            )
            downloadedPapers.append(DownloadedPaper(
                paper: paper,
                downloadedAt: date,
                localPath: file.path
            ))
            states[paper.id] = .init(phase: .downloaded(file))
            imported = true
        }

        if imported {
            saveHistory()
        }
        refreshMissingMetadata()
    }

    private func refreshMissingMetadata() {
        let ids = downloadedPapers
            .filter { $0.paper.abstract.isEmpty && $0.paper.authors.isEmpty }
            .map(\.paper.id)
        guard !ids.isEmpty else { return }
        Task { [weak self] in
            guard let self else { return }
            guard let fetched = try? await ArxivService.shared.fetchPapers(ids: ids),
                  !fetched.isEmpty else { return }
            self.applyMetadata(fetched)
        }
    }

    private func applyMetadata(_ papers: [Paper]) {
        var changed = false
        for paper in papers {
            guard let index = downloadedPapers.firstIndex(where: { $0.paper.id == paper.id }) else { continue }
            let existing = downloadedPapers[index]
            guard existing.paper.abstract.isEmpty || existing.paper.authors.isEmpty else { continue }
            downloadedPapers[index] = DownloadedPaper(
                paper: paper,
                downloadedAt: existing.downloadedAt,
                localPath: existing.localPath
            )
            changed = true
        }
        if changed {
            saveHistory()
        }
    }

    private static func arxivIDAndTitle(fromFileName name: String) -> (id: String, title: String)? {
        var base = name
        if base.lowercased().hasSuffix(".pdf") {
            base = String(base.dropLast(4))
        }
        base = base.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else { return nil }

        let token: String
        let remainder: String
        if let separator = base.firstIndex(where: \.isWhitespace) {
            token = String(base[..<separator])
            remainder = String(base[base.index(after: separator)...])
        } else {
            token = base
            remainder = ""
        }
        guard token.range(of: #"^\d{4}\.\d{4,5}(v\d+)?$"#, options: .regularExpression) != nil else {
            return nil
        }
        let id = token.replacingOccurrences(of: #"v\d+$"#, with: "", options: .regularExpression)
        let title = remainder.trimmingCharacters(in: .whitespacesAndNewlines)
        return (id, title.isEmpty ? id : title)
    }

    private func saveHistory() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(downloadedPapers)
            try AppPaths.writeAtomically(data, to: AppPaths.downloadHistoryFile)
        } catch {
            NSLog("EndlessFrontier: failed to save download history: \(error)")
        }
    }

    private func loadHistory() {
        guard let data = try? Data(contentsOf: AppPaths.downloadHistoryFile) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode([DownloadedPaper].self, from: data) else {
            NSLog("EndlessFrontier: failed to decode download history")
            return
        }
        var seen = Set<String>()
        var valid: [DownloadedPaper] = []
        for entry in decoded where seen.insert(entry.paper.id).inserted {
            guard FileManager.default.fileExists(atPath: entry.localPath) else { continue }
            valid.append(entry)
            states[entry.paper.id] = .init(phase: .downloaded(entry.localURL))
        }
        downloadedPapers = valid
        if valid.count != decoded.count {
            saveHistory()
        }
    }

    private func destinationURL(for paper: Paper) -> URL {
        let forbidden = CharacterSet(charactersIn: "/\\:*?\"<>|\n\r\t")
        var title = ScienceText.display(paper.title).components(separatedBy: forbidden).joined(separator: " ")
        title = title.cleanedForDisplay
        if title.count > 60 {
            title = String(title.prefix(60)).trimmingCharacters(in: .whitespaces)
        }
        if title.isEmpty { title = "paper" }
        return downloadFolder.appendingPathComponent("\(paper.id) \(title).pdf")
    }
}

enum DownloadError: LocalizedError {
    case invalidResponse
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "下载服务返回了无效响应。"
        case .http(let status):
            return "论文下载失败（HTTP \(status)）。"
        }
    }
}
