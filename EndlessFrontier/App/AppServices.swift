import Foundation

@MainActor
final class AppServices: ObservableObject {
    let settings: AppSettings
    let reports: ReportStore
    let translations: TranslationCache
    let downloads: DownloadManager
    let favorites: FavoritesStore
    let systemTranslator: SystemTranslator
    let translationService: TranslationService
    let reportGenerationCenter: ReportGenerationCenter
    let knowledgeTrees: KnowledgeTreeStore
    let knowledgeTreeCenter: KnowledgeTreeCenter
    let state: AppState

    init() {
        AppPaths.ensureDirectories()
        let settings = AppSettings()
        let translations = TranslationCache()
        let systemTranslator = SystemTranslator()
        self.settings = settings
        self.translations = translations
        self.systemTranslator = systemTranslator
        self.translationService = TranslationService(
            settings: settings,
            cache: translations,
            systemTranslator: systemTranslator
        )
        let reports = ReportStore()
        self.reports = reports
        self.downloads = DownloadManager()
        self.favorites = FavoritesStore()
        self.reportGenerationCenter = ReportGenerationCenter(settings: settings, reports: reports)
        let knowledgeTrees = KnowledgeTreeStore()
        self.knowledgeTrees = knowledgeTrees
        self.knowledgeTreeCenter = KnowledgeTreeCenter(settings: settings, store: knowledgeTrees)
        self.state = AppState()
    }
}
