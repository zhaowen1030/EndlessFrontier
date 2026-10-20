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

@MainActor
final class DownloadManager: ObservableObject {
    @Published private(set) var states: [String: PaperDownloadState] = [:]
    private var inFlight: Set<String> = []

    var downloadFolder: URL { AppPaths.downloadsDirectory }

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
    }

    func restoreDownloadedStates(for papers: [Paper]) {
        for paper in papers {
            if let existing = states[paper.id]?.localURL,
               FileManager.default.fileExists(atPath: existing.path) { continue }
            let destination = destinationURL(for: paper)
            if FileManager.default.fileExists(atPath: destination.path) {
                states[paper.id] = .init(phase: .downloaded(destination))
            }
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
