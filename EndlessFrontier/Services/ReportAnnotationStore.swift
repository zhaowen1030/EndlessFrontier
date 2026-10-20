import Foundation

@MainActor
final class ReportAnnotationStore: ObservableObject {
    @Published private(set) var highlights: [String: [TextHighlight]] = [:]

    let categoryID: String
    private var reportGeneratedAt: Date

    init(categoryID: String, reportGeneratedAt: Date) {
        self.categoryID = categoryID
        self.reportGeneratedAt = reportGeneratedAt
        AppPaths.ensureDirectories()
        load()
    }

    func highlights(for fieldID: String) -> [TextHighlight] {
        highlights[fieldID] ?? []
    }

    var hasAnyHighlights: Bool {
        highlights.values.contains { !$0.isEmpty }
    }

    func applyHighlight(fieldID: String, range: NSRange, color: HighlightColor?) {
        let existing = highlights[fieldID] ?? []
        let updated = HighlightRangeEditor.apply(existing, range: range, color: color)
        if updated.isEmpty {
            highlights.removeValue(forKey: fieldID)
        } else {
            highlights[fieldID] = updated
        }
        save()
    }

    func clearHighlights(for fieldID: String) {
        guard highlights.removeValue(forKey: fieldID) != nil else { return }
        save()
    }

    /// The generated report may change after a regeneration. Highlights are
    /// tied to character ranges in the old text, so they are discarded when the
    /// underlying report changes.
    func reconcile(reportGeneratedAt newValue: Date) {
        guard abs(newValue.timeIntervalSince(reportGeneratedAt)) >= 1 else { return }
        reportGeneratedAt = newValue
        if !highlights.isEmpty {
            highlights = [:]
        }
        save()
    }

    private func load() {
        let url = AppPaths.annotationFileURL(categoryID: categoryID)
        guard let data = try? Data(contentsOf: url) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let document = try? decoder.decode(ReportAnnotationDocument.self, from: data) else { return }
        if abs(document.reportGeneratedAt.timeIntervalSince(reportGeneratedAt)) < 1 {
            highlights = document.highlights
        } else {
            // A regenerated report has new text; ranges no longer apply.
            highlights = [:]
            save()
        }
    }

    private func save() {
        let document = ReportAnnotationDocument(
            categoryID: categoryID,
            reportGeneratedAt: reportGeneratedAt,
            highlights: highlights,
            updatedAt: Date()
        )
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(document)
            try AppPaths.writeAtomically(data, to: AppPaths.annotationFileURL(categoryID: categoryID))
        } catch {
            NSLog("EndlessFrontier: failed to save report annotations: \(error)")
        }
    }
}
