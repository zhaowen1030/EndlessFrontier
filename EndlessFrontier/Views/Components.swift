import SwiftUI

struct BilingualText: View {
    let en: String
    var zh: String?
    var enFont: Font = AppFont.body(14, weight: .regular)
    var zhFont: Font = AppFont.chinese(13)
    var enColor: Color = .primary
    var zhColor: Color = .primary.opacity(0.62)
    var lineLimitEN: Int?
    var lineLimitZH: Int?
    var spacing: CGFloat = 5
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: spacing) {
            Text(en)
                .font(enFont)
                .foregroundStyle(enColor)
                .lineLimit(lineLimitEN)
                .fixedSize(horizontal: false, vertical: true)
            if let zh, !zh.trimmed.isEmpty {
                Text(zh)
                    .font(zhFont)
                    .foregroundStyle(zhColor)
                    .lineLimit(lineLimitZH)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .multilineTextAlignment(alignment == .center ? .center : .leading)
        .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
    }
}

struct LanguageTag: View {
    let text: String
    var highlighted: Bool = false

    var body: some View {
        Text(text)
            .font(.system(size: 8.5, weight: .bold, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(highlighted ? AppTheme.accent : Color.secondary.opacity(0.85))
            .padding(.horizontal, 5)
            .padding(.vertical, 2.5)
            .background(
                Capsule()
                    .fill(highlighted ? AppTheme.accent.opacity(0.12) : Color.primary.opacity(0.055))
            )
    }
}

struct SectionLabel: View {
    let english: String
    let chinese: String
    var color: Color = AppTheme.accent
    var symbol: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(english.uppercased())
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(color)
            Text(chinese)
                .font(AppFont.chinese(13, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.78))
        }
    }
}

struct Chip: View {
    let text: String
    var tint: Color = AppTheme.accent
    var filled: Bool = false
    var monospaced: Bool = false

    var body: some View {
        Text(text)
            .font(monospaced ? AppFont.mono(10.5, weight: .medium) : AppFont.body(10.5, weight: .medium))
            .foregroundStyle(filled ? .white : tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(filled ? tint : tint.opacity(0.10))
            )
            .overlay {
                if !filled {
                    Capsule().strokeBorder(tint.opacity(0.18), lineWidth: 1)
                }
            }
    }
}

struct SkeletonBar: View {
    var width: CGFloat? = nil
    var height: CGFloat = 10
    @State private var animate = false

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(Color.primary.opacity(0.10))
            .frame(width: width, height: height)
            .opacity(animate ? 0.35 : 0.85)
            .animation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true), value: animate)
            .onAppear { animate = true }
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    var tint: Color = AppTheme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.chinese(13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                LinearGradient(
                    colors: [tint, tint.opacity(0.82)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.20), lineWidth: 1)
            }
            .shadow(color: tint.opacity(configuration.isPressed ? 0.15 : 0.28), radius: 12, y: 5)
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.13), value: configuration.isPressed)
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    var tint: Color = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.chinese(12.5, weight: .medium))
            .foregroundStyle(tint.opacity(configuration.isPressed ? 0.6 : 0.88))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.10 : 0.055))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
            .contentShape(Rectangle())
    }
}

struct ErrorBanner: View {
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.warning)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppFont.chinese(12.5, weight: .semibold))
                Text(message)
                    .font(AppFont.chinese(12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(SecondaryActionButtonStyle())
            }
        }
        .padding(14)
        .background(AppTheme.warning.opacity(0.075), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(AppTheme.warning.opacity(0.18), lineWidth: 1)
        }
    }
}

struct InfoBanner: View {
    let icon: String
    let title: String
    let message: String
    var tint: Color = AppTheme.accent

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(tint)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppFont.chinese(12.5, weight: .semibold))
                Text(message)
                    .font(AppFont.chinese(11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .background(tint.opacity(0.06), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(tint.opacity(0.13), lineWidth: 1)
        }
    }
}

struct TagFlow: Layout {
    var spacing: CGFloat = 7
    var lineSpacing: CGFloat = 7

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 600
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct HairlineDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.075))
            .frame(height: 1)
    }
}

struct OrbitalMark: View {
    var size: CGFloat = 24
    var color: Color = AppTheme.accent
    @State private var rotate = false

    var body: some View {
        ZStack {
            Ellipse()
                .stroke(color.opacity(0.45), lineWidth: 1)
                .frame(width: size, height: size * 0.48)
                .rotationEffect(.degrees(-24))
            Ellipse()
                .stroke(color.opacity(0.28), lineWidth: 0.8)
                .frame(width: size * 0.72, height: size * 0.32)
                .rotationEffect(.degrees(32))
            Circle()
                .fill(color)
                .frame(width: size * 0.16, height: size * 0.16)
                .offset(x: size * 0.30, y: size * 0.06)
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: size * 0.07, height: size * 0.07)
        }
        .rotationEffect(.degrees(rotate ? 360 : 0))
        .animation(.linear(duration: 26).repeatForever(autoreverses: false), value: rotate)
        .onAppear { rotate = true }
    }
}

struct PageBackdrop: View {
    var tint: Color = AppTheme.accent

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            RadialGradient(
                colors: [tint.opacity(0.08), .clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 700
            )
            RadialGradient(
                colors: [AppTheme.gold.opacity(0.035), .clear],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 600
            )
        }
        .ignoresSafeArea()
    }
}

struct EmptyState: View {
    let icon: String
    let titleEN: String
    let titleZH: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(AppTheme.accent.opacity(0.8))
                .padding(.bottom, 2)
            Text(titleEN)
                .font(AppFont.display(19))
            Text(titleZH)
                .font(AppFont.chinese(13, weight: .medium))
                .foregroundStyle(.secondary)
            Text(message)
                .font(AppFont.chinese(12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(SecondaryActionButtonStyle())
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

struct SegmentedTabControl: View {
    @Binding var selection: CategoryTab
    var reportAvailable: Bool
    var treeAvailable: Bool = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(CategoryTab.allCases) { tab in
                segment(tab)
            }
        }
        .padding(3)
        .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }

    private func segment(_ tab: CategoryTab) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.22)) { selection = tab }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon(for: tab))
                    .font(.system(size: 10.5, weight: .semibold))
                Text(tab.labelZH)
                    .font(AppFont.chinese(11.5, weight: .semibold))
                Text(tab.labelEN)
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(selection == tab ? .white.opacity(0.62) : .secondary.opacity(0.7))
                if (tab == .explore && reportAvailable) || (tab == .knowledgeTree && treeAvailable) {
                    Circle()
                        .fill(selection == tab ? Color.white.opacity(0.8) : AppTheme.positive)
                        .frame(width: 4, height: 4)
                }
            }
            .foregroundStyle(selection == tab ? .white : .secondary)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background {
                if selection == tab {
                    RoundedRectangle(cornerRadius: 7.5, style: .continuous)
                        .fill(AppTheme.accentDeep)
                        .shadow(color: AppTheme.accentDeep.opacity(0.25), radius: 5, y: 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func icon(for tab: CategoryTab) -> String {
        switch tab {
        case .papers: return "doc.text"
        case .explore: return "sparkles"
        case .knowledgeTree: return "list.bullet.indent"
        }
    }
}

