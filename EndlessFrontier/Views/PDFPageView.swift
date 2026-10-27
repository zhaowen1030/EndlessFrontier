import SwiftUI
import PDFKit

struct PDFPageDisplayView: NSViewRepresentable {
    let document: PDFDocument
    let pageIndex: Int
    let fitMode: PDFFitMode
    var isLiveResizing = false

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> FittingPDFView {
        let view = FittingPDFView()
        view.backgroundColor = .underPageBackgroundColor
        view.displayMode = .singlePage
        view.displayDirection = .vertical
        view.displaysPageBreaks = false
        view.pageShadowsEnabled = true
        view.fitMode = fitMode
        context.coordinator.loadDocument(document, into: view)
        context.coordinator.goToPage(pageIndex, in: view)
        view.isLiveResizing = isLiveResizing
        return view
    }

    func updateNSView(_ view: FittingPDFView, context: Context) {
        view.isLiveResizing = isLiveResizing
        guard !isLiveResizing else { return }
        if view.fitMode != fitMode {
            view.fitMode = fitMode
        }
        context.coordinator.loadDocument(document, into: view)
        context.coordinator.goToPage(pageIndex, in: view)
    }

    final class Coordinator {
        private var displayedPageIndex: Int?

        func loadDocument(_ document: PDFDocument, into view: FittingPDFView) {
            guard view.document !== document else { return }
            view.document = document
            displayedPageIndex = nil
            view.refreshFit()
        }

        func goToPage(_ index: Int, in view: FittingPDFView) {
            guard let document = view.document, document.pageCount > 0 else { return }
            let clamped = min(max(index, 0), document.pageCount - 1)
            guard displayedPageIndex != clamped, let page = document.page(at: clamped) else { return }
            view.go(to: page)
            view.layoutDocumentView()
            displayedPageIndex = clamped
            view.refreshFit()
        }
    }
}

struct PDFTranslatedPageView: NSViewRepresentable {
    let document: PDFDocument
    let fitMode: PDFFitMode
    var isLiveResizing = false

    func makeNSView(context: Context) -> FittingPDFView {
        let view = FittingPDFView()
        view.backgroundColor = .underPageBackgroundColor
        view.displayMode = .singlePage
        view.displayDirection = .vertical
        view.displaysPageBreaks = false
        view.pageShadowsEnabled = true
        view.autoScales = true
        view.document = document
        if let page = document.page(at: 0) {
            view.go(to: page)
        }
        view.fitMode = fitMode
        view.isLiveResizing = isLiveResizing
        return view
    }

    func updateNSView(_ view: FittingPDFView, context: Context) {
        view.isLiveResizing = isLiveResizing
        guard !isLiveResizing else { return }
        if view.document !== document {
            view.document = document
            if let page = document.page(at: 0) {
                view.go(to: page)
            }
            view.refreshFit()
        }
        if view.fitMode != fitMode {
            view.fitMode = fitMode
        }
    }
}

final class FittingPDFView: PDFView {
    var fitMode: PDFFitMode = .automatic {
        didSet {
            lastFitSize = .zero
            lastLayoutSize = .zero
            if fitMode == .automatic {
                autoScales = true
            } else {
                applyCustomFit(force: true)
            }
        }
    }

    var isLiveResizing = false {
        didSet {
            guard oldValue != isLiveResizing else { return }
            if isLiveResizing {
                // Freeze the rendered scale while the user drags a divider so
                // PDFKit does not re-render on every mouse-move tick.
                let currentScale = scaleFactor
                autoScales = false
                scaleFactor = currentScale
            } else {
                refreshFit()
            }
        }
    }

    override var preservesContentDuringLiveResize: Bool { true }

    private var lastFitSize = CGSize.zero
    private var lastLayoutSize = CGSize.zero

    override func layout() {
        super.layout()
        guard !isLiveResizing else { return }
        let currentSize = bounds.size
        guard currentSize.width > 0, currentSize.height > 0,
              currentSize != lastLayoutSize else { return }
        lastLayoutSize = currentSize
        if fitMode == .automatic {
            autoScales = true
            layoutDocumentView()
        } else {
            applyCustomFit(force: true)
        }
        needsDisplay = true
    }

    func refreshFit() {
        lastFitSize = .zero
        lastLayoutSize = .zero
        if fitMode == .automatic {
            autoScales = true
            layoutDocumentView()
        } else {
            applyCustomFit(force: true)
        }
        needsDisplay = true
    }

    private func applyCustomFit(force: Bool = false) {
        guard fitMode != .automatic,
              let page = currentPage,
              bounds.width > 0,
              bounds.height > 0 else { return }

        let currentSize = bounds.size
        if !force,
           abs(currentSize.width - lastFitSize.width) < 0.5,
           abs(currentSize.height - lastFitSize.height) < 0.5 {
            return
        }
        lastFitSize = currentSize

        let pageBounds = page.bounds(for: .cropBox)
        let rotation = ((page.rotation % 360) + 360) % 360
        var pageSize = pageBounds.size
        if rotation == 90 || rotation == 270 {
            swap(&pageSize.width, &pageSize.height)
        }
        guard pageSize.width > 0, pageSize.height > 0 else { return }

        let padding: CGFloat = 20
        let availableWidth = max(currentSize.width - padding, 1)
        let availableHeight = max(currentSize.height - padding, 1)
        let targetScale: CGFloat
        switch fitMode {
        case .width:
            targetScale = availableWidth / pageSize.width
        case .height:
            targetScale = availableHeight / pageSize.height
        case .automatic:
            return
        }
        let clamped = min(max(targetScale, minScaleFactor), maxScaleFactor)
        autoScales = false
        if abs(scaleFactor - clamped) > 0.001 {
            scaleFactor = clamped
        }
    }
}
