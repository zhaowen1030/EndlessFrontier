import SwiftUI
import AppKit

struct FavoritesView: View {
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var translations: TranslationCache
    @EnvironmentObject private var downloads: DownloadManager
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            header
            HairlineDivider().opacity(0.6)
            content
        }
        .background(PageBackdrop(tint: AppTheme.gold))
        .navigationTitle("收藏论文")
        .navigationSubtitle("Saved Papers")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "star.fill")
                    .font(.system(size: 9.5, weight: .semibold))
                Text("PERSONAL LIBRARY")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.4)
                Text("本地收藏")
                    .font(AppFont.chinese(10))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(favorites.count) 篇")
                    .font(AppFont.mono(10, weight: .medium))
                    .foregroundStyle(AppTheme.gold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppTheme.gold.opacity(0.10), in: Capsule())
            }
            .foregroundStyle(AppTheme.gold)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Saved Papers")
                        .font(AppFont.display(29, weight: .semibold))
                    Text("收藏论文")
                        .font(AppFont.chinese(15, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    appState.openGraph()
                } label: {
                    Label("去探索学科", systemImage: "point.3.connected.trianglepath.dotted")
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }

            Text("按收藏时间倒序排列，最近收藏的论文显示在最上方。收藏数据只保存在本机。")
                .font(AppFont.chinese(10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 24)
        .padding(.top, 21)
        .padding(.bottom, 17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack(alignment: .topTrailing) {
                LinearGradient(
                    colors: [AppTheme.gold.opacity(0.16), AppTheme.gold.opacity(0.035), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(AppTheme.gold.opacity(0.08))
                    .frame(width: 250, height: 250)
                    .blur(radius: 8)
                    .offset(x: 90, y: -165)
            }
            .clipped()
        }
        .clipped()
    }

    @ViewBuilder
    private var content: some View {
        if favorites.count == 0 {
            EmptyState(
                icon: "star",
                titleEN: "No saved papers yet",
                titleZH: "还没有收藏论文",
                message: "在任意论文卡片右下角点击「收藏」，就能把论文保存到这里。收藏与排序信息只保存在本机。",
                actionTitle: "去探索学科",
                action: { appState.openGraph() }
            )
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 13) {
                    ForEach(favorites.sortedEntries) { entry in
                        PaperRow(
                            paper: entry.paper,
                            translation: translations.translation(for: entry.paper.id),
                            translationPending: false,
                            canTranslate: false,
                            translationError: nil,
                            downloadState: downloads.state(for: entry.paper.id),
                            onDownload: { downloads.download(entry.paper) },
                            onOpen: { NSWorkspace.shared.open(entry.paper.absURL) },
                            onReveal: { downloads.reveal(entry.paper) },
                            onRedownload: { downloads.download(entry.paper, force: true) },
                            onTranslate: {}
                        )
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(AppTheme.gold.opacity(0.7))
                        Text("已收藏 \(favorites.count) 篇 · 按收藏时间倒序 · 仅保存在本机")
                            .font(AppFont.chinese(9))
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                    .padding(.horizontal, 2)
                    .padding(.top, 6)
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 22)
                .padding(.top, 16)
                .frame(maxWidth: 1_000)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.automatic)
        }
    }
}
