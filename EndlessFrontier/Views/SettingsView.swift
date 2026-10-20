import SwiftUI
import AppKit

private enum SettingsSection: String, CaseIterable, Identifiable {
    case model
    case general
    case data
    case about

    var id: String { rawValue }
    var titleZH: String {
        switch self {
        case .model: return "模型连接"
        case .general: return "通用与翻译"
        case .data: return "数据与存储"
        case .about: return "关于"
        }
    }
    var titleEN: String {
        switch self {
        case .model: return "AI MODEL"
        case .general: return "GENERAL"
        case .data: return "STORAGE"
        case .about: return "ABOUT"
        }
    }
    var symbol: String {
        switch self {
        case .model: return "key.horizontal"
        case .general: return "slider.horizontal.3"
        case .data: return "internaldrive"
        case .about: return "info.circle"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var reports: ReportStore
    @EnvironmentObject private var translations: TranslationCache
    @EnvironmentObject private var downloads: DownloadManager

    @State private var section: SettingsSection = .model

    init() {
        #if DEBUG
        if let raw = DebugLaunchOptions.settingsSection,
           let value = SettingsSection(rawValue: raw) {
            _section = State(initialValue: value)
        }
        #endif
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 180)
                .background {
                    ZStack {
                        Color(nsColor: .windowBackgroundColor)
                        LinearGradient(
                            colors: [AppTheme.accent.opacity(0.06), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .ignoresSafeArea()
                }
            HairlineDivider()
                .frame(width: 1)
            ScrollView {
                Group {
                    switch section {
                    case .model: ModelSettingsPane()
                    case .general: GeneralSettingsPane()
                    case .data: DataSettingsPane()
                    case .about: AboutSettingsPane()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.vertical, 26)
            }
            .scrollIndicators(.automatic)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.26))
        }
        .frame(minWidth: 760, minHeight: 600)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(hex: "0D1C34"))
                    OrbitalMark(size: 20, color: AppTheme.cyan)
                }
                .frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 0) {
                    Text("无尽前沿")
                        .font(AppFont.display(14, weight: .semibold))
                    Text("设置 SETTINGS")
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 20)

            ForEach(SettingsSection.allCases) { item in
                Button {
                    section = item
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 11.5, weight: .medium))
                            .frame(width: 18)
                            .foregroundStyle(section == item ? AppTheme.accent : .secondary)
                        VStack(alignment: .leading, spacing: 0.5) {
                            Text(item.titleZH)
                                .font(AppFont.chinese(11.5, weight: section == item ? .semibold : .regular))
                            Text(item.titleEN)
                                .font(.system(size: 7.5, weight: .bold, design: .rounded))
                                .tracking(0.7)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        if item == .model && !settings.isConfigured {
                            Circle()
                                .fill(AppTheme.warning)
                                .frame(width: 5, height: 5)
                        }
                    }
                    .foregroundStyle(section == item ? .primary : .secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background {
                        if section == item {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(AppTheme.accent.opacity(0.09))
                                .overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(AppTheme.accent)
                                        .frame(width: 2, height: 17)
                                        .padding(.leading, 1)
                                }
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(settings.isConfigured ? AppTheme.positive : AppTheme.warning)
                        .frame(width: 5, height: 5)
                    Text(settings.isConfigured ? "模型可用" : "模型未配置")
                        .font(AppFont.chinese(9))
                        .foregroundStyle(.secondary)
                }
                Text("无尽前沿 1.0 · macOS")
                    .font(AppFont.mono(8))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
        }
    }
}

// MARK: - Model

private struct ModelSettingsPane: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.openURL) private var openURL

    @State private var keyDraft = ""
    @State private var revealKey = false
    @State private var saveConfirmation = false
    @State private var testState: TestState = .idle

    private enum TestState: Equatable {
        case idle
        case testing
        case success(String)
        case failure(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            settingsHeader(
                title: "连接大语言模型",
                en: "CONNECT A LANGUAGE MODEL",
                description: "论文浏览不依赖模型；中文翻译与 AI 学科探索使用你接入的模型。密钥仅保存在本机 macOS 钥匙串中。"
            )

            settingsCard("服务提供方", "PROVIDER") {
                Picker("", selection: $settings.provider) {
                    ForEach(LLMProvider.allCases) { provider in
                        Text(provider.titleZH == provider.titleEN ? provider.titleZH : "\(provider.titleZH) · \(provider.titleEN)")
                            .tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .onChange(of: settings.provider) { _, _ in
                    keyDraft = ""
                    testState = .idle
                }

                if settings.provider == .anthropic {
                    Text("通过 Anthropic Messages API 调用 Claude。默认使用当前最强的 Claude Opus 5.5。")
                        .settingsNote()
                } else {
                    Text("适用于 OpenAI Chat Completions 兼容接口，例如 DeepSeek、Moonshot、Ollama 或自建网关。请填写完整的 Base URL。")
                        .settingsNote()
                }
            }

            settingsCard("API 密钥", "API KEY") {
                HStack(spacing: 8) {
                    Group {
                        if revealKey {
                            TextField(settings.provider.keyPlaceholder, text: $keyDraft)
                        } else {
                            SecureField(settings.provider.keyPlaceholder, text: $keyDraft)
                        }
                    }
                    .textFieldStyle(.plain)
                    .font(AppFont.mono(11))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .fieldSurface()

                    Button {
                        revealKey.toggle()
                    } label: {
                        Image(systemName: revealKey ? "eye.slash" : "eye")
                            .font(.system(size: 10.5))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help(revealKey ? "隐藏密钥" : "显示密钥")

                    Button("保存") {
                        saveKey()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .disabled(keyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                HStack(spacing: 8) {
                    if settings.hasKey(for: settings.provider) {
                        Label("密钥已保存到钥匙串", systemImage: "checkmark.shield")
                            .font(AppFont.chinese(9.5))
                            .foregroundStyle(AppTheme.positive)
                        Button("移除") {
                            settings.removeAPIKey(for: settings.provider)
                            keyDraft = ""
                            testState = .idle
                        }
                        .buttonStyle(.plain)
                        .font(AppFont.chinese(9.5))
                        .foregroundStyle(.secondary)
                    } else if let source = settings.credentialSource(for: settings.provider), source == .environment {
                        Label("正在使用环境变量中的凭据", systemImage: "terminal")
                            .font(AppFont.chinese(9.5))
                            .foregroundStyle(AppTheme.accent)
                    } else {
                        Label("尚未保存密钥", systemImage: "exclamationmark.circle")
                            .font(AppFont.chinese(9.5))
                            .foregroundStyle(AppTheme.warning)
                    }
                    if saveConfirmation {
                        Text("已保存")
                            .font(AppFont.chinese(9.5))
                            .foregroundStyle(AppTheme.positive)
                            .transition(.opacity)
                    }
                }

                Text("应用会将密钥写入 macOS 钥匙串；不会上传密钥到除所配置模型服务之外的任何地方。更推荐使用受限额度、可随时撤销的 API Key。")
                    .settingsNote()
            }

            settingsCard("模型与接口", "MODEL & ENDPOINT") {
                VStack(alignment: .leading, spacing: 7) {
                    fieldLabel("模型名称", "Model")
                    TextField(modelPlaceholder, text: modelBinding)
                        .textFieldStyle(.plain)
                        .font(AppFont.mono(11))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .fieldSurface()
                    if settings.provider == .anthropic {
                        HStack(spacing: 6) {
                            Text("推荐：")
                                .font(AppFont.chinese(9.5))
                                .foregroundStyle(.secondary)
                            ForEach(["claude-opus-5-5", "claude-sonnet-5-5", "claude-haiku-5-5"], id: \.self) { model in
                                Button(model) {
                                    settings.anthropicModel = model
                                    testState = .idle
                                }
                                .buttonStyle(.plain)
                                .font(AppFont.mono(8.5))
                                .foregroundStyle(model == settings.anthropicModel ? AppTheme.accent : .secondary)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 7) {
                    fieldLabel(settings.provider == .anthropic ? "接口地址（高级）" : "Base URL", "Endpoint")
                    TextField(baseURLPlaceholder, text: baseURLBinding)
                        .textFieldStyle(.plain)
                        .font(AppFont.mono(11))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .fieldSurface()
                    Text(settings.provider == .anthropic
                         ? "保持默认值即可。若通过代理或兼容网关访问 Claude，可修改为对应地址。"
                         : "示例：https://api.openai.com/v1、https://api.deepseek.com/v1、http://localhost:11434/v1。")
                        .settingsNote()
                }

                if let url = URL(string: settings.activeBaseURL), url.scheme == nil {
                    Label("接口地址需要包含 http:// 或 https://", systemImage: "exclamationmark.triangle")
                        .font(AppFont.chinese(9.5))
                        .foregroundStyle(AppTheme.warning)
                }

                HStack(spacing: 9) {
                    Button {
                        testConnection()
                    } label: {
                        HStack(spacing: 6) {
                            if testState == .testing { ProgressView().controlSize(.mini) }
                            Text(testState == .testing ? "正在测试…" : "测试连接")
                        }
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .disabled(testState == .testing || settings.activeBaseURL.isEmpty)

                    switch testState {
                    case .idle:
                        Text("将发送一个极小的测试请求，可能产生少量费用。")
                            .font(AppFont.chinese(9.5))
                            .foregroundStyle(.tertiary)
                    case .testing:
                        EmptyView()
                    case .success(let response):
                        Label("连接成功 · \(response)", systemImage: "checkmark.circle.fill")
                            .font(AppFont.chinese(9.8, weight: .medium))
                            .foregroundStyle(AppTheme.positive)
                            .lineLimit(1)
                    case .failure(let message):
                        Label(message, systemImage: "xmark.circle.fill")
                            .font(AppFont.chinese(9.5))
                            .foregroundStyle(AppTheme.danger)
                            .lineLimit(2)
                    }
                }
                .padding(.top, 2)
            }

            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Text("隐私：论文浏览与 PDF 下载直接连接 arXiv.org。翻译会发送论文标题与摘要；AI 探索会发送分类代码、名称与 arXiv 学科目录。生成内容保存在本机，不会自动再次生成。")
                    .font(AppFont.chinese(9.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(13)
            .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            if settings.provider == .anthropic {
                Link(destination: URL(string: "https://platform.claude.com/docs/en/api/messages")!) {
                    Label("Anthropic Messages API 文档", systemImage: "arrow.up.right")
                        .font(AppFont.chinese(9.5))
                }
                .foregroundStyle(AppTheme.accent)
            }
        }
    }

    private var modelBinding: Binding<String> {
        Binding(
            get: {
                switch settings.provider {
                case .anthropic: return settings.anthropicModel
                case .openAICompatible: return settings.openAIModel
                }
            },
            set: { value in
                switch settings.provider {
                case .anthropic: settings.anthropicModel = value
                case .openAICompatible: settings.openAIModel = value
                }
                testState = .idle
            }
        )
    }

    private var baseURLBinding: Binding<String> {
        Binding(
            get: {
                switch settings.provider {
                case .anthropic: return settings.anthropicBaseURL
                case .openAICompatible: return settings.openAIBaseURL
                }
            },
            set: { value in
                switch settings.provider {
                case .anthropic: settings.anthropicBaseURL = value
                case .openAICompatible: settings.openAIBaseURL = value
                }
                testState = .idle
            }
        )
    }

    private var modelPlaceholder: String {
        switch settings.provider {
        case .anthropic: return "claude-opus-5-5"
        case .openAICompatible: return "例如 deepseek-chat / gpt-4.1 / qwen3"
        }
    }

    private var baseURLPlaceholder: String {
        switch settings.provider {
        case .anthropic: return "https://api.anthropic.com"
        case .openAICompatible: return "https://api.openai.com/v1"
        }
    }

    private func saveKey() {
        settings.setAPIKey(keyDraft, for: settings.provider)
        keyDraft = ""
        saveConfirmation = true
        testState = .idle
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            saveConfirmation = false
        }
    }

    private func testConnection() {
        if !keyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            settings.setAPIKey(keyDraft, for: settings.provider)
            keyDraft = ""
        }
        testState = .testing
        Task {
            do {
                let response = try await LLMClient.shared.testConnection(settings: settings)
                testState = .success(String(response.prefix(40)))
            } catch {
                testState = .failure(error.localizedDescription)
            }
        }
    }
}

// MARK: - General

private struct GeneralSettingsPane: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            settingsHeader(
                title: "通用与翻译",
                en: "GENERAL & TRANSLATION",
                description: "控制论文自动翻译、翻译方式和每页加载数量。"
            )

            settingsCard("论文翻译", "PAPER TRANSLATION") {
                Toggle(isOn: $settings.autoTranslate) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("自动翻译已加载的论文")
                            .font(AppFont.chinese(12, weight: .medium))
                        Text("Automatically translate titles and abstracts to Chinese")
                            .font(AppFont.body(9.5))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.small)

                VStack(alignment: .leading, spacing: 7) {
                    fieldLabel("翻译方式", "Translation engine")
                    Picker("", selection: $settings.translationMode) {
                        ForEach(TranslationMode.allCases) { mode in
                            Text("\(mode.labelZH) · \(mode.labelEN)").tag(mode)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 320)
                }

                Text("自动选择会优先使用你配置的大语言模型；若未配置或调用失败，则尝试 Apple 系统翻译。系统翻译首次使用可能需要下载英语与简体中文语言包。翻译结果按 arXiv ID 缓存，避免重复请求。")
                    .settingsNote()

                if !settings.isConfigured {
                    InfoBanner(
                        icon: "character.book.closed",
                        title: "尚未配置大语言模型",
                        message: "论文仍可浏览和下载。启用 Apple 系统翻译后，无需 API 密钥也可以生成双语论文列表；AI 学科探索仍需要模型。"
                    )
                }
            }

            settingsCard("浏览", "BROWSING") {
                VStack(alignment: .leading, spacing: 7) {
                    fieldLabel("每页论文数", "Papers per page")
                    Picker("", selection: $settings.pageSize) {
                        Text("20").tag(20)
                        Text("25").tag(25)
                        Text("50").tag(50)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 220)
                }
                Text("较大的每页数量会增加首次翻译耗时与模型用量。")
                    .settingsNote()
            }

            settingsCard("快捷键", "SHORTCUTS") {
                shortcutRow("⌘ ⇧ G", "打开知识图谱", "Open knowledge graph")
                shortcutRow("⌘ ⇧ E", "AI 探索当前学科", "Explore current discipline")
                shortcutRow("⌘ R", "刷新论文", "Refresh papers")
                shortcutRow("⌘ ,", "打开设置", "Settings")
            }
        }
    }

    private func shortcutRow(_ keys: String, _ zh: String, _ en: String) -> some View {
        HStack {
            Text(keys)
                .font(AppFont.mono(9.5, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            Text(zh)
                .font(AppFont.chinese(10.5))
            Text(en)
                .font(AppFont.body(9.5))
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }
}

// MARK: - Data

private struct DataSettingsPane: View {
    @EnvironmentObject private var reports: ReportStore
    @EnvironmentObject private var translations: TranslationCache
    @EnvironmentObject private var downloads: DownloadManager

    @State private var confirmClearReports = false
    @State private var confirmClearTranslations = false
    @State private var confirmClearDownloads = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            settingsHeader(
                title: "数据与存储",
                en: "DATA & STORAGE",
                description: "AI 报告、翻译缓存与论文 PDF 都保存在本机。应用不上传你的本地文件。"
            )

            storageRow(
                icon: "sparkles.rectangle.stack",
                title: "AI 学科报告",
                en: "AI reports",
                detail: "\(reports.count) 份 · \(reports.storageSizeDescription)",
                path: AppPaths.reportsDirectory,
                actionTitle: "清除全部报告",
                destructive: true
            ) {
                confirmClearReports = true
            }

            storageRow(
                icon: "character.book.closed",
                title: "论文翻译缓存",
                en: "Translation cache",
                detail: "\(translations.count) 篇论文",
                path: AppPaths.cacheDirectory,
                actionTitle: "清除翻译缓存",
                destructive: false
            ) {
                confirmClearTranslations = true
            }

            storageRow(
                icon: "doc.richtext",
                title: "已下载论文",
                en: "Downloaded PDFs",
                detail: downloads.storageDescription(),
                path: downloads.downloadFolder,
                actionTitle: "打开下载文件夹",
                destructive: false
            ) {
                downloads.openDownloadsFolder()
            }

            settingsCard("位置", "LOCATIONS") {
                pathRow("应用支持目录", AppPaths.supportDirectory)
                pathRow("报告目录", AppPaths.reportsDirectory)
                pathRow("文本标注目录", AppPaths.annotationsDirectory)
                pathRow("知识树目录", AppPaths.knowledgeTreesDirectory)
                pathRow("收藏数据", AppPaths.favoritesFile)
                pathRow("下载记录", AppPaths.downloadHistoryFile)
                pathRow("PDF 双语阅读缓存", AppPaths.readerDirectory)
                pathRow("下载目录", AppPaths.downloadsDirectory)
                Text("可通过「在访达中打开」直接访问这些文件。删除报告后需要重新手动生成；翻译缓存删除后会在下次浏览时重新翻译。")
                    .settingsNote()
            }

            HStack {
                Spacer()
                Button("清除已下载 PDF") { confirmClearDownloads = true }
                    .buttonStyle(.plain)
                    .font(AppFont.chinese(9.5))
                    .foregroundStyle(.secondary)
            }
        }
        .confirmationDialog("删除全部 AI 报告？", isPresented: $confirmClearReports, titleVisibility: .visible) {
            Button("删除全部报告", role: .destructive) { reports.deleteAll() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这不会影响已下载的论文或翻译缓存，但已生成的本地报告将无法恢复。")
        }
        .confirmationDialog("清除全部翻译缓存？", isPresented: $confirmClearTranslations, titleVisibility: .visible) {
            Button("清除翻译缓存", role: .destructive) { translations.removeAll() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("下次打开论文列表时会重新请求翻译。")
        }
        .confirmationDialog("删除下载文件夹中的全部 PDF？", isPresented: $confirmClearDownloads, titleVisibility: .visible) {
            Button("删除全部 PDF", role: .destructive) { downloads.removeAllDownloads() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这会永久删除 \(AppPaths.downloadsDirectory.path) 中的文件。")
        }
    }

    private func storageRow(
        icon: String,
        title: String,
        en: String,
        detail: String,
        path: URL,
        actionTitle: String,
        destructive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 34, height: 34)
                .background(AppTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(AppFont.chinese(12, weight: .semibold))
                    Text(en)
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
                Text(detail)
                    .font(AppFont.chinese(9.5))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("在访达中显示") {
                try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
                NSWorkspace.shared.open(path)
            }
            .buttonStyle(.plain)
            .font(AppFont.chinese(9.5))
            .foregroundStyle(.secondary)
            Button(actionTitle) { action() }
                .buttonStyle(SecondaryActionButtonStyle(tint: destructive ? AppTheme.danger : .primary))
        }
        .padding(14)
        .cardSurface(radius: 12)
    }

    private func pathRow(_ title: String, _ path: URL) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(AppFont.chinese(9.5))
                .foregroundStyle(.secondary)
            Text(path.path)
                .font(AppFont.mono(8.5))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button {
                NSWorkspace.shared.open(path)
            } label: {
                Image(systemName: "arrow.up.forward.square")
                    .font(.system(size: 9.5))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - About

private struct AboutSettingsPane: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 15) {
                Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                    .resizable()
                    .frame(width: 72, height: 72)
                VStack(alignment: .leading, spacing: 3) {
                    Text("无尽前沿")
                        .font(AppFont.display(25, weight: .semibold))
                    Text("Endless Frontier")
                        .font(AppFont.body(12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("版本 1.0.0 · arXiv 科学前沿学习助手")
                        .font(AppFont.chinese(9.5))
                        .foregroundStyle(.tertiary)
                }
            }

            Text("一个面向 arXiv 的双语科学探索桌面应用：按完整学科分类浏览最新论文，自动生成中英对照，下载原始 PDF，并用你接入的大语言模型手动生成可离线保存的学科全景报告。学科之间的交叉关系以双语知识图谱呈现，每个节点都可以继续 AI 探索。")
                .font(AppFont.chinese(11.5))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            settingsCard("设计原则", "PRINCIPLES") {
                principle("手动触发的 AI 探索", "AI generation is never automatic; reports are cached locally.", "sparkles")
                principle("中英双语优先", "English above, Chinese below; both carry the same information.", "character.book.closed")
                principle("证据与校准", "Prompts instruct the model to avoid fabricated facts, dates, and equations.", "checkmark.shield")
                principle("本地优先", "Keys live in Keychain; reports, caches, and PDFs stay on your Mac.", "lock")
            }

            settingsCard("来源与致谢", "CREDITS") {
                Link(destination: URL(string: "https://arxiv.org")!) {
                    Label("论文元数据与 PDF：arXiv.org（非官方关联应用）", systemImage: "link")
                        .font(AppFont.chinese(10))
                }
                Link(destination: URL(string: "https://github.com/KaTeX/KaTeX")!) {
                    Label("公式渲染：KaTeX · MIT License", systemImage: "link")
                        .font(AppFont.chinese(10))
                }
                Text("无尽前沿不是 arXiv、康奈尔大学或 Anthropic 的官方产品。论文内容版权归原作者所有，请遵守 arXiv 的使用条款。")
                    .settingsNote()
            }
        }
    }

    private func principle(_ title: String, _ detail: String, _ symbol: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.chinese(10.8, weight: .medium))
                Text(detail)
                    .font(AppFont.body(9.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Shared settings components

private func settingsHeader(title: String, en: String, description: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(AppFont.display(21, weight: .semibold))
            Text(en)
                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(AppTheme.accent)
        }
        Text(description)
            .font(AppFont.chinese(10.5))
            .foregroundStyle(.secondary)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}

private func settingsCard<Content: View>(_ title: String, _ en: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 6) {
            Text(title)
                .font(AppFont.chinese(11.5, weight: .semibold))
            Text(en)
                .font(.system(size: 7.8, weight: .bold, design: .rounded))
                .tracking(0.9)
                .foregroundStyle(.tertiary)
        }
        content()
    }
    .padding(15)
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardSurface(radius: 12)
}

private func fieldLabel(_ zh: String, _ en: String) -> some View {
    HStack(spacing: 5) {
        Text(zh)
            .font(AppFont.chinese(10.5, weight: .medium))
        Text(en.uppercased())
            .font(.system(size: 7.5, weight: .bold, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(.tertiary)
    }
}

private extension Text {
    func settingsNote() -> some View {
        self
            .font(AppFont.chinese(9.5))
            .foregroundStyle(.tertiary)
            .lineSpacing(2.5)
            .fixedSize(horizontal: false, vertical: true)
    }
}
