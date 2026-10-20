import SwiftUI
import AppKit

struct PaperRow: View {
    let paper: Paper
    let translation: PaperTranslation?
    let translationPending: Bool
    let canTranslate: Bool
    let translationError: String?
    let downloadState: PaperDownloadState?
    let onDownload: () -> Void
    let onOpen: () -> Void
    let onReveal: () -> Void
    let onRedownload: () -> Void
    let onTranslate: () -> Void
    var onReadPDF: (() -> Void)? = nil
    var downloadedAt: Date? = nil

    @EnvironmentObject private var favorites: FavoritesStore
    @State private var expanded = false
    @State private var hovering = false
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            metaRow
            titleBlock
            authorRow
            abstractBlock
            footerRow
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(hovering ? 0.82 : 0.62))
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(AppTheme.accent.opacity(hovering ? 0.028 : 0.012))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(hovering ? AppTheme.accent.opacity(0.20) : Color.primary.opacity(0.06), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(hovering ? 0.06 : 0.02), radius: hovering ? 14 : 5, y: 4)
        .animation(.easeOut(duration: 0.16), value: hovering)
        .onHover { hovering = $0 }
    }

    private var metaRow: some View {
        HStack(spacing: 7) {
            Text(paper.primaryCategory)
                .font(AppFont.mono(9.5, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(AppTheme.accent.opacity(0.09), in: Capsule())
            Text(paper.id)
                .font(AppFont.mono(9.2))
                .foregroundStyle(.tertiary)
            Text("·")
                .foregroundStyle(.quaternary)
            Text(paper.published.shortChinese)
                .font(AppFont.chinese(10))
                .foregroundStyle(.secondary)
            if let favorite = favorites.entry(for: paper.id) {
                Text("·")
                    .foregroundStyle(.quaternary)
                Image(systemName: "star.fill")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(AppTheme.gold)
                Text("收藏于 \(favorite.favoritedAt.shortChinese)")
                    .font(AppFont.chinese(9))
                    .foregroundStyle(AppTheme.gold.opacity(0.82))
                    .lineLimit(1)
            }
            if let downloadedAt {
                Text("·")
                    .foregroundStyle(.quaternary)
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(AppTheme.positive)
                Text("下载于 \(downloadedAt.shortChinese)")
                    .font(AppFont.chinese(9))
                    .foregroundStyle(AppTheme.positive.opacity(0.82))
                    .lineLimit(1)
            }
            if paper.categories.count > 1 {
                Text("+\(paper.categories.count - 1) cross-list")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 4)
            if translation != nil {
                HStack(spacing: 3.5) {
                    Image(systemName: "character.book.closed")
                        .font(.system(size: 8.5, weight: .medium))
                    Text("中英对照")
                        .font(AppFont.chinese(9))
                }
                .foregroundStyle(AppTheme.positive.opacity(0.9))
            } else if translationPending {
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("翻译中")
                        .font(AppFont.chinese(8.8))
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(ScienceText.display(paper.title))
                .font(AppFont.display(18, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.96))
                .lineSpacing(1.5)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            if let translation {
                Text(ScienceText.display(translation.titleZH))
                    .font(AppFont.chinese(14, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.72))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            } else if translationPending {
                HStack(spacing: 7) {
                    LanguageTag(text: "中文")
                    SkeletonBar(width: 300, height: 12)
                }
                .padding(.top, 1)
            }
        }
    }

    private var authorRow: some View {
        HStack(spacing: 5) {
            Image(systemName: "person.2")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.tertiary)
            Text(paper.authors.isEmpty ? "作者信息待补充" : paper.authorLine)
                .font(AppFont.body(10.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let comment = paper.comment {
                Text("·")
                    .foregroundStyle(.quaternary)
                Text(comment)
                    .font(AppFont.body(9.5))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var abstractBlock: some View {
        if !paper.abstract.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        LanguageTag(text: "EN")
                        Text("Abstract")
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Text(ScienceText.display(paper.abstract))
                        .font(AppFont.body(12.3))
                        .foregroundStyle(.primary.opacity(0.78))
                        .lineSpacing(3)
                        .lineLimit(expanded ? nil : 3)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }

                if let translation {
                    HairlineDivider().opacity(0.55)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            LanguageTag(text: "中文", highlighted: true)
                            Text("摘要")
                                .font(AppFont.chinese(9.5, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        Text(ScienceText.display(translation.abstractZH))
                            .font(AppFont.chinese(12.2))
                            .foregroundStyle(.primary.opacity(0.70))
                            .lineSpacing(4)
                            .lineLimit(expanded ? nil : 3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if translationPending {
                    HStack(spacing: 7) {
                        LanguageTag(text: "中文", highlighted: true)
                        SkeletonBar(width: 210, height: 9)
                    }
                }
            }
        }
    }

    private var footerRow: some View {
        HStack(spacing: 8) {
            if !paper.abstract.isEmpty {
                Button {
                    withAnimation(.snappy(duration: 0.22)) { expanded.toggle() }
                } label: {
                    Label(expanded ? "收起摘要" : "展开摘要", systemImage: expanded ? "chevron.up" : "chevron.down")
                        .font(AppFont.chinese(10.5, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 6)

            if let error = downloadState?.errorMessage {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.danger)
                    .help(error)
            }

            favoriteAction

            if translation == nil, canTranslate, !translationPending {
                Button(action: onTranslate) {
                    Label(
                        translationError == nil ? "翻译" : "重试翻译",
                        systemImage: translationError == nil ? "character.book.closed" : "arrow.clockwise"
                    )
                    .font(AppFont.chinese(10.5))
                }
                .buttonStyle(QuietIconButtonStyle())
                .help(translationError ?? "翻译本文标题与摘要 Translate this paper")
            }

            Button(action: copyCitation) {
                Label(copied ? "已复制" : "引用", systemImage: copied ? "checkmark" : "quote.opening")
                    .font(AppFont.chinese(10.5))
            }
            .buttonStyle(QuietIconButtonStyle())

            Button(action: onOpen) {
                Label("原文", systemImage: "arrow.up.right.square")
                    .font(AppFont.chinese(10.5))
            }
            .buttonStyle(QuietIconButtonStyle())

            downloadAction
        }
        .padding(.top, 1)
    }

    @ViewBuilder
    private var downloadAction: some View {
        switch downloadState?.phase {
        case .downloaded:
            HStack(spacing: 5) {
                if let onReadPDF {
                    Button(action: onReadPDF) {
                        Label("阅读", systemImage: "book")
                            .font(AppFont.chinese(10.5, weight: .semibold))
                    }
                    .buttonStyle(QuietIconButtonStyle())
                    .help("打开 PDF 双语阅读器")
                }

                Button {
                    onOpenPDF()
                } label: {
                    Label("打开 PDF", systemImage: "doc.richtext")
                        .font(AppFont.chinese(10.5, weight: .semibold))
                }
                .buttonStyle(QuietIconButtonStyle())

                Menu {
                    Button("在访达中显示") { onReveal() }
                    Button("重新下载") { onRedownload() }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 10, weight: .bold))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
        case .downloading:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.mini)
                Text("下载中")
                    .font(AppFont.chinese(10.5))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
        default:
            Button(action: onDownload) {
                Label("下载 PDF", systemImage: "arrow.down.circle")
                    .font(AppFont.chinese(10.5, weight: .semibold))
            }
            .buttonStyle(QuietIconButtonStyle())
        }
    }

    private var favoriteAction: some View {
        let saved = favorites.isFavorite(paper.id)
        return Button {
            withAnimation(.snappy(duration: 0.22)) {
                favorites.toggle(paper)
            }
        } label: {
            Label(saved ? "取消收藏" : "收藏", systemImage: saved ? "star.fill" : "star")
                .font(AppFont.chinese(10.5))
                .foregroundStyle(saved ? AppTheme.gold : .secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(
                    saved ? AppTheme.gold.opacity(0.10) : Color.primary.opacity(0.055),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            saved ? AppTheme.gold.opacity(0.22) : Color.primary.opacity(0.08),
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
        .help(saved ? "取消收藏 Remove from saved papers" : "收藏此论文 Save this paper locally")
    }

    private func onOpenPDF() {
        if let url = downloadState?.localURL {
            NSWorkspace.shared.open(url)
        }
    }

    private func copyCitation() {
        let authors = paper.authors.joined(separator: ", ")
        let citation = "\(authors). \(ScienceText.display(paper.title)). arXiv:\(paper.id)."
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(citation, forType: .string)
        copied = true
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            copied = false
        }
    }
}

struct PaperRowSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SkeletonBar(width: 76, height: 10)
                SkeletonBar(width: 52, height: 9)
                Spacer()
            }
            SkeletonBar(width: 430, height: 16)
            SkeletonBar(width: 290, height: 16)
            SkeletonBar(width: 310, height: 9)
            SkeletonBar(height: 9)
            SkeletonBar(width: 600, height: 9)
            SkeletonBar(width: 560, height: 9)
            HStack {
                SkeletonBar(width: 80, height: 10)
                Spacer()
                SkeletonBar(width: 70, height: 20)
            }
            .padding(.top, 3)
        }
        .padding(18)
        .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        }
    }
}
