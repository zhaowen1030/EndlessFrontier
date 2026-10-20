import SwiftUI
import AppKit

struct DownloadsView: View {
    @EnvironmentObject private var downloads: DownloadManager
    @EnvironmentObject private var translations: TranslationCache
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var appState: AppState

    @State private var readerRecord: DownloadedPaper?

    var body: some View {
        Group {
            if let record = readerRecord {
                PDFBilingualReaderView(
                    record: record,
                    settings: settings,
                    onClose: { readerRecord = nil }
                )
                .id(record.paper.id)
            } else {
                libraryView
            }
        }
        .background(PageBackdrop(tint: AppTheme.cyan))
    }

    private var libraryView: some View {
        VStack(spacing: 0) {
            header
            HairlineDivider().opacity(0.6)
            content
        }
        .navigationTitle("下载论文")
        .navigationSubtitle("Downloaded Papers")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 9.5, weight: .semibold))
                Text("LOCAL PDF LIBRARY")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.4)
                Text("本地论文库")
                    .font(AppFont.chinese(10))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(downloads.downloadedPapers.count) 篇")
                    .font(AppFont.mono(10, weight: .medium))
                    .foregroundStyle(AppTheme.cyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppTheme.cyan.opacity(0.10), in: Capsule())
            }
            .foregroundStyle(AppTheme.cyan)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Downloaded Papers")
                        .font(AppFont.display(29, weight: .semibold))
                    Text("下载论文")
                        .font(AppFont.chinese(15, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 7) {
                    Button {
                        downloads.openDownloadsFolder()
                    } label: {
                        Label("打开文件夹", systemImage: "folder")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())

                    Button {
                        appState.openGraph()
                    } label: {
                        Label("去探索学科", systemImage: "point.3.connected.trianglepath.dotted")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
            }

            Text("仅展示已完成下载的论文，按完成下载时间倒序排列。PDF 原文件与双语阅读数据只保存在本机。")
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
                    colors: [AppTheme.cyan.opacity(0.14), AppTheme.cyan.opacity(0.03), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(AppTheme.cyan.opacity(0.07))
                    .frame(width: 240, height: 240)
                    .blur(radius: 8)
                    .offset(x: 85, y: -165)
            }
            .clipped()
        }
        .clipped()
    }

    @ViewBuilder
    private var content: some View {
        if downloads.downloadedPapers.isEmpty {
            EmptyState(
                icon: "arrow.down.circle",
                titleEN: "No downloaded papers yet",
                titleZH: "还没有下载论文",
                message: "在论文卡片上点击「下载 PDF」。只有完整下载到本机的论文才会出现在这里，之后可打开 PDF 双语阅读。",
                actionTitle: "去探索学科",
                action: { appState.openGraph() }
            )
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 13) {
                    ForEach(downloads.sortedDownloadedPapers) { record in
                        PaperRow(
                            paper: record.paper,
                            translation: translations.translation(for: record.paper.id),
                            translationPending: false,
                            canTranslate: false,
                            translationError: nil,
                            downloadState: downloads.state(for: record.paper.id)
                                ?? .init(phase: .downloaded(record.localURL)),
                            onDownload: { downloads.download(record.paper) },
                            onOpen: { NSWorkspace.shared.open(record.paper.absURL) },
                            onReveal: { downloads.reveal(record.paper) },
                            onRedownload: { downloads.download(record.paper, force: true) },
                            onTranslate: {},
                            onReadPDF: { readerRecord = record },
                            downloadedAt: record.downloadedAt
                        )
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 8.5))
                            .foregroundStyle(AppTheme.positive.opacity(0.8))
                        Text("已完成下载 \(downloads.downloadedPapers.count) 篇 · 按完成下载时间倒序 · 仅保存在本机")
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
