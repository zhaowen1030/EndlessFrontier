import Foundation

/// Keeps one in-flight ExploreModel per discipline for the lifetime of the app.
/// Generation therefore survives navigation, and returning to a category shows
/// the same progress instead of offering a duplicate generation.
@MainActor
final class ReportGenerationCenter {
    private let settings: AppSettings
    private let reports: ReportStore
    private var models: [String: ExploreModel] = [:]

    init(settings: AppSettings, reports: ReportStore) {
        self.settings = settings
        self.reports = reports
    }

    func model(for category: ArxivCategory) -> ExploreModel {
        if let existing = models[category.id] {
            return existing
        }
        let model = ExploreModel(category: category, settings: settings, reports: reports)
        models[category.id] = model
        return model
    }
}
