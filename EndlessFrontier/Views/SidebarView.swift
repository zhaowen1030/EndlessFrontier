import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var reports: ReportStore
    @EnvironmentObject private var translations: TranslationCache
    @EnvironmentObject private var favorites: FavoritesStore
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            brandHeader
            HairlineDivider().opacity(0.6)
            scrollContent
            HairlineDivider().opacity(0.6)
            footer
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusSidebarSearch)) { _ in
            searchFocused = true
        }
        .background {
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                LinearGradient(
                    colors: [AppTheme.accent.opacity(0.055), .clear, AppTheme.gold.opacity(0.018)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .ignoresSafeArea()
        }
    }

    private var brandHeader: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "142B4E"), Color(hex: "0B1930")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                        }
                    OrbitalMark(size: 27, color: AppTheme.cyan)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 1) {
                    Text("无尽前沿")
                        .font(AppFont.display(20, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("ENDLESS FRONTIER")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .tracking(1.8)
                        .foregroundStyle(.secondary.opacity(0.85))
                }
                Spacer(minLength: 4)
                Text("arXiv")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.4)
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(AppTheme.accent.opacity(0.10), in: Capsule())
            }

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("搜索学科 Search disciplines", text: $state.sidebarSearch)
                    .textFieldStyle(.plain)
                    .font(AppFont.chinese(11.5))
                    .focused($searchFocused)
                if !state.sidebarSearch.isEmpty {
                    Button {
                        state.sidebarSearch = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("⌘F")
                        .font(.system(size: 8.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 15)
        .padding(.bottom, 13)
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 5) {
                graphRow
                favoritesRow

                if state.sidebarSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HStack {
                        Text("学科分类")
                            .font(AppFont.chinese(10.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("DISCIPLINES")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .tracking(1.1)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text("\(ArxivTaxonomy.allCategories.count)")
                            .font(AppFont.mono(9))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 14)
                    .padding(.bottom, 3)

                    ForEach(ArxivTaxonomy.groups) { group in
                        groupSection(group)
                    }
                } else {
                    searchResults
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 22)
        }
        .scrollIndicators(.never)
    }

    private var graphRow: some View {
        let selected: Bool = {
            if case .graph = state.selection { return true }
            return false
        }()
        return Button {
            state.openGraph()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(selected ? .white : AppTheme.accent)
                    .frame(width: 27, height: 27)
                    .background(
                        (selected ? Color.white.opacity(0.15) : AppTheme.accent.opacity(0.10)),
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 1) {
                    Text("知识图谱")
                        .font(AppFont.chinese(12.5, weight: .semibold))
                    Text("KNOWLEDGE GRAPH")
                        .font(.system(size: 7.8, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(selected ? .white.opacity(0.62) : .secondary.opacity(0.8))
                }
                Spacer()
                if !reports.reports.isEmpty {
                    Text("\(reports.count)")
                        .font(AppFont.mono(9, weight: .medium))
                        .foregroundStyle(selected ? .white.opacity(0.75) : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(selected ? Color.white.opacity(0.12) : Color.primary.opacity(0.05), in: Capsule())
                }
            }
            .foregroundStyle(selected ? .white : .primary)
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.accentDeep.opacity(0.95), AppTheme.accentDeep.opacity(0.76)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: AppTheme.accentDeep.opacity(0.22), radius: 8, y: 3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 3)
    }

    private var favoritesRow: some View {
        let selected: Bool = {
            if case .favorites = state.selection { return true }
            return false
        }()
        return Button {
            state.openFavorites()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: selected ? "star.fill" : "star")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(selected ? .white : AppTheme.gold)
                    .frame(width: 27, height: 27)
                    .background(
                        (selected ? Color.white.opacity(0.15) : AppTheme.gold.opacity(0.10)),
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 1) {
                    Text("收藏论文")
                        .font(AppFont.chinese(12.5, weight: .semibold))
                    Text("SAVED PAPERS")
                        .font(.system(size: 7.8, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(selected ? .white.opacity(0.62) : .secondary.opacity(0.8))
                }
                Spacer()
                if favorites.count > 0 {
                    Text("\(favorites.count)")
                        .font(AppFont.mono(9, weight: .medium))
                        .foregroundStyle(selected ? .white.opacity(0.75) : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(selected ? Color.white.opacity(0.12) : Color.primary.opacity(0.05), in: Capsule())
                }
            }
            .foregroundStyle(selected ? .white : .primary)
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.accentDeep.opacity(0.95), AppTheme.accentDeep.opacity(0.76)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: AppTheme.accentDeep.opacity(0.22), radius: 8, y: 3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
    }

    private func groupSection(_ group: CategoryGroup) -> some View {
        let isExpanded = state.expandedGroups.contains(group.id)
        let selectedGroup = state.selectedCategoryID.flatMap { ArxivTaxonomy.category($0)?.groupID } == group.id
        return VStack(alignment: .leading, spacing: 2) {
            Button {
                withAnimation(.snappy(duration: 0.22)) {
                    state.toggleGroup(group.id)
                }
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: group.symbol)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(group.color)
                        .frame(width: 22, height: 22)
                        .background(group.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    VStack(alignment: .leading, spacing: 0.5) {
                        Text(group.nameEN)
                            .font(AppFont.body(11.5, weight: selectedGroup ? .semibold : .medium))
                            .lineLimit(1)
                        Text(group.nameZH)
                            .font(AppFont.chinese(10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 2)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 1) {
                    if group.isNested {
                        ForEach(group.archives) { archive in
                            Text(archive.nameEN + "  " + archive.nameZH)
                                .font(AppFont.body(9.5, weight: .semibold))
                                .foregroundStyle(.secondary.opacity(0.88))
                                .padding(.leading, 35)
                                .padding(.top, 6)
                                .padding(.bottom, 1)
                            ForEach(archive.categories) { category in
                                categoryRow(category)
                            }
                        }
                    } else {
                        ForEach(group.categories) { category in
                            categoryRow(category)
                        }
                    }
                }
                .padding(.leading, 20)
            }
        }
    }

    private func categoryRow(_ category: ArxivCategory) -> some View {
        let selected = state.selectedCategoryID == category.id
        let hasReport = reports.report(for: category.id) != nil
        let tint = AppTheme.groupColor(category.groupID)
        return Button {
            state.openCategory(category.id, tab: .papers)
        } label: {
            HStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(selected ? Color.white : tint.opacity(0.45))
                    .frame(width: 2, height: 25)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(category.nameEN)
                            .font(AppFont.body(11.5, weight: selected ? .semibold : .regular))
                            .lineLimit(1)
                        if hasReport {
                            Image(systemName: "sparkle")
                                .font(.system(size: 7.5, weight: .semibold))
                                .foregroundStyle(selected ? Color.white.opacity(0.9) : AppTheme.gold)
                        }
                    }
                    HStack(spacing: 5) {
                        Text(category.nameZH)
                            .font(AppFont.chinese(9.8))
                            .lineLimit(1)
                        Text(category.id)
                            .font(AppFont.mono(8.2))
                            .foregroundStyle(selected ? Color.white.opacity(0.62) : Color.secondary.opacity(0.55))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if state.selectedCategoryID == category.id {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .foregroundStyle(selected ? .white : .primary.opacity(0.92))
            .padding(.leading, 5)
            .padding(.trailing, 7)
            .padding(.vertical, 5)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(tint.opacity(0.82))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("\(category.nameEN) / \(category.nameZH) · \(category.id)")
    }

    private var searchResults: some View {
        let results = ArxivTaxonomy.search(state.sidebarSearch)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("搜索结果")
                    .font(AppFont.chinese(10.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("SEARCH RESULTS")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("\(results.reduce(0) { $0 + $1.categories.count })")
                    .font(AppFont.mono(9))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 9)
            .padding(.top, 14)
            .padding(.bottom, 3)

            if results.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("没有匹配的学科")
                        .font(AppFont.chinese(12, weight: .medium))
                    Text("Try an English name, Chinese name, or arXiv code.")
                        .font(AppFont.body(10.5))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
            } else {
                ForEach(results, id: \.group.id) { result in
                    HStack(spacing: 6) {
                        Image(systemName: result.group.symbol)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(result.group.color)
                        Text(result.group.nameEN)
                            .font(AppFont.body(9.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(result.group.nameZH)
                            .font(AppFont.chinese(9))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                    ForEach(result.categories) { category in
                        categoryRow(category)
                    }
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 7) {
                Circle()
                    .fill(settings.isConfigured ? AppTheme.positive : AppTheme.warning)
                    .frame(width: 6, height: 6)
                    .shadow(color: (settings.isConfigured ? AppTheme.positive : AppTheme.warning).opacity(0.5), radius: 4)
                VStack(alignment: .leading, spacing: 1) {
                    Text(settings.isConfigured ? settings.activeModel : "模型未配置")
                        .font(AppFont.mono(9.2, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let source = settings.credentialSource(for: settings.provider) {
                        Text(source == .environment ? "环境变量凭据 · \(translations.count) 条翻译" : "已连接 · \(translations.count) 条翻译")
                            .font(AppFont.chinese(8.8))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    } else {
                        Text("论文翻译：\(settings.translationMode.labelZH)")
                            .font(AppFont.chinese(8.8))
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer(minLength: 4)
                SettingsLink {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("设置 Settings")
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
        }
    }
}
