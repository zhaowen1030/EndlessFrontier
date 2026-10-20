import SwiftUI
import AppKit

enum AnnotationFontWeight: String {
    case regular
    case medium
    case semibold

    var nsWeight: NSFont.Weight {
        switch self {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        }
    }
}

enum AnnotationTextTone: String {
    case primary
    case body
    case secondary

    func nsColor(isDark: Bool) -> NSColor {
        switch self {
        case .primary:
            return .labelColor
        case .body:
            return NSColor.labelColor.withAlphaComponent(isDark ? 0.86 : 0.80)
        case .secondary:
            return .secondaryLabelColor
        }
    }
}

struct AnnotationTextStyle: Equatable {
    var size: CGFloat
    var weight: AnnotationFontWeight = .regular
    var tone: AnnotationTextTone = .body
    var lineSpacing: CGFloat = 3.5
}

enum AnnotatedTextRenderer {
    static func attributedString(
        text: String,
        style: AnnotationTextStyle,
        highlights: [TextHighlight],
        isDark: Bool
    ) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = style.lineSpacing
        paragraph.paragraphSpacing = 0
        paragraph.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: style.size, weight: style.weight.nsWeight),
            .foregroundColor: style.tone.nsColor(isDark: isDark),
            .paragraphStyle: paragraph
        ]
        let attributed = NSMutableAttributedString(string: text, attributes: attributes)
        let length = attributed.length
        for highlight in highlights where highlight.length > 0 && highlight.location >= 0 && highlight.location < length {
            let safeLength = min(highlight.length, length - highlight.location)
            guard safeLength > 0 else { continue }
            attributed.addAttribute(
                .backgroundColor,
                value: highlight.color.backgroundColor(isDark: isDark),
                range: NSRange(location: highlight.location, length: safeLength)
            )
        }
        return attributed
    }

    static func height(
        text: String,
        style: AnnotationTextStyle,
        width: CGFloat
    ) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        let attributed = attributedString(text: text, style: style, highlights: [], isDark: false)
        let storage = NSTextStorage(attributedString: attributed)
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(
            containerSize: NSSize(width: max(width, 1), height: CGFloat.greatestFiniteMagnitude)
        )
        container.lineFragmentPadding = 0
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: container)
        return max(1, ceil(layoutManager.usedRect(for: container).height) + 1)
    }
}

private extension AnnotationFontWeight {
    var swiftUIWeight: Font.Weight {
        switch self {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        }
    }
}

private extension AnnotationTextTone {
    func swiftUIColor(isDark: Bool) -> Color {
        switch self {
        case .primary:
            return .primary
        case .body:
            return Color.primary.opacity(isDark ? 0.86 : 0.80)
        case .secondary:
            return Color.secondary
        }
    }
}

/// Fast, non-selectable rendering used while reading. Highlighted ranges are
/// represented as native SwiftUI text backgrounds. Selection/highlight editing
/// only swaps in NSTextView-backed text while the report is in annotation mode.
struct ReadOnlyHighlightedText: View {
    let text: String
    let style: AnnotationTextStyle
    let highlights: [TextHighlight]

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(attributed)
            .font(.system(size: style.size, weight: style.weight.swiftUIWeight))
            .foregroundStyle(style.tone.swiftUIColor(isDark: colorScheme == .dark))
            .lineSpacing(style.lineSpacing)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var attributed: AttributedString {
        var attributed = AttributedString(text)
        let length = text.utf16.count
        for highlight in highlights where highlight.length > 0 && highlight.location >= 0 && highlight.location < length {
            let end = min(highlight.location + highlight.length, length)
            let lower = String.Index(utf16Offset: highlight.location, in: text)
            let upper = String.Index(utf16Offset: end, in: text)
            guard let start = AttributedString.Index(lower, within: attributed),
                  let finish = AttributedString.Index(upper, within: attributed) else { continue }
            attributed[start..<finish].backgroundColor = highlight.color.swatchColor.opacity(
                colorScheme == .dark ? 0.36 : 0.29
            )
        }
        return attributed
    }
}

/// Selectable report prose with persistent text-background highlights.
/// Using a non-editable NSTextView keeps native selection and copy/paste while
/// allowing the surrounding SwiftUI report to retain its card layout.
struct HighlightableText: View {
    let text: String
    let style: AnnotationTextStyle
    let highlights: [TextHighlight]
    let onSelect: (NSRange) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        AnnotatedTextViewRepresentable(
            text: text,
            style: style,
            highlights: highlights,
            isDark: colorScheme == .dark,
            onSelect: onSelect
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AnnotatedTextViewRepresentable: NSViewRepresentable {
    let text: String
    let style: AnnotationTextStyle
    let highlights: [TextHighlight]
    let isDark: Bool
    let onSelect: (NSRange) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> ReportProseTextView {
        let textView = ReportProseTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 20))
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = false
        textView.minSize = .zero
        textView.maxSize = NSSize(width: .greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.allowsUndo = false
        textView.usesFontPanel = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.delegate = context.coordinator
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        context.coordinator.applyContent(to: textView, parent: self)
        return textView
    }

    func updateNSView(_ textView: ReportProseTextView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.applyContent(to: textView, parent: self)
        textView.textContainer?.containerSize = NSSize(
            width: max(textView.bounds.width, 1),
            height: CGFloat.greatestFiniteMagnitude
        )
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: ReportProseTextView,
        context: Context
    ) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        let height = context.coordinator.measuredHeight(width: width, parent: self)
        return CGSize(width: width, height: height)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: AnnotatedTextViewRepresentable
        private var lastRenderKey: RenderKey?
        private var isRestoringSelection = false

        private var cachedLayoutKey: LayoutKey?
        private var cachedWidth: CGFloat = 0
        private var cachedHeight: CGFloat = 0

        init(parent: AnnotatedTextViewRepresentable) {
            self.parent = parent
        }

        func applyContent(to textView: ReportProseTextView, parent: AnnotatedTextViewRepresentable) {
            let key = RenderKey(
                text: parent.text,
                style: parent.style,
                isDark: parent.isDark,
                highlights: parent.highlights
            )
            guard key != lastRenderKey else { return }
            lastRenderKey = key

            let previousSelection = textView.selectedRange()
            isRestoringSelection = true
            textView.textStorage?.setAttributedString(
                AnnotatedTextRenderer.attributedString(
                    text: parent.text,
                    style: parent.style,
                    highlights: parent.highlights,
                    isDark: parent.isDark
                )
            )
            let length = textView.string.utf16.count
            if previousSelection.location <= length {
                let safeLength = min(previousSelection.length, length - previousSelection.location)
                textView.setSelectedRange(NSRange(location: previousSelection.location, length: safeLength))
            }
            isRestoringSelection = false
            textView.needsDisplay = true
        }

        func measuredHeight(width: CGFloat, parent: AnnotatedTextViewRepresentable) -> CGFloat {
            let key = LayoutKey(text: parent.text, style: parent.style)
            if cachedLayoutKey == key, abs(cachedWidth - width) < 0.5 {
                return cachedHeight
            }
            let height = AnnotatedTextRenderer.height(text: parent.text, style: parent.style, width: width)
            cachedLayoutKey = key
            cachedWidth = width
            cachedHeight = height
            return height
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isRestoringSelection, let textView = notification.object as? NSTextView else { return }
            let range = textView.selectedRange()
            guard range.length > 0 else { return }
            parent.onSelect(range)
        }

        private struct LayoutKey: Equatable {
            let text: String
            let style: AnnotationTextStyle
        }

        private struct RenderKey: Equatable {
            let text: String
            let style: AnnotationTextStyle
            let isDark: Bool
            let highlights: [TextHighlight]
        }
    }
}

/// A read-only prose NSTextView that still lets a containing SwiftUI
/// ScrollView handle trackpad/wheel scrolling when the pointer is over text.
private final class ReportProseTextView: NSTextView {
    override func scrollWheel(with event: NSEvent) {
        if let enclosingScrollView {
            enclosingScrollView.scrollWheel(with: event)
        } else {
            nextResponder?.scrollWheel(with: event)
        }
    }
}

@MainActor
final class HighlightSelectionController: ObservableObject {
    @Published var selection: HighlightSelection?

    func select(fieldID: String, range: NSRange) {
        guard range.length > 0 else { return }
        selection = HighlightSelection(fieldID: fieldID, range: range)
    }

    func clear() {
        selection = nil
    }
}

struct HighlightPalette: View {
    @ObservedObject var controller: HighlightSelectionController
    let annotationStore: ReportAnnotationStore

    var body: some View {
        ZStack {
            if let selection = controller.selection {
                HStack(spacing: 10) {
                HStack(spacing: 5) {
                    Image(systemName: "paintbrush.pointed")
                        .font(.system(size: 10.5, weight: .medium))
                    Text("文本底色")
                        .font(AppFont.chinese(10.5, weight: .medium))
                }
                .foregroundStyle(.secondary)

                Rectangle()
                    .fill(Color.primary.opacity(0.10))
                    .frame(width: 1, height: 17)

                ForEach(HighlightColor.allCases) { color in
                    Button {
                        annotationStore.applyHighlight(
                            fieldID: selection.fieldID,
                            range: selection.range,
                            color: color
                        )
                        controller.clear()
                    } label: {
                        Circle()
                            .fill(color.swatchColor)
                            .frame(width: 18, height: 18)
                            .overlay {
                                Circle().strokeBorder(Color.white.opacity(0.65), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .help("\(color.labelZH) · \(color.labelEN)")
                }

                Rectangle()
                    .fill(Color.primary.opacity(0.10))
                    .frame(width: 1, height: 17)

                Button {
                    annotationStore.applyHighlight(
                        fieldID: selection.fieldID,
                        range: selection.range,
                        color: nil
                    )
                    controller.clear()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "eraser")
                            .font(.system(size: 10, weight: .medium))
                        Text("清除")
                            .font(AppFont.chinese(10.5))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("清除所选文字的底色 Clear highlight")

                Button {
                    controller.clear()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                        .background(Color.primary.opacity(0.05), in: Circle())
                }
                .buttonStyle(.plain)
                .help("关闭高亮工具 Close")
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
            .overlay {
                Capsule().strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
            }
                .shadow(color: .black.opacity(0.16), radius: 16, y: 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 16)
            }
        }
        .animation(.snappy(duration: 0.18), value: controller.selection)
    }
}
