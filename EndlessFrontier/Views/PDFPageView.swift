import SwiftUI
import PDFKit

struct PDFPageDisplayView: NSViewRepresentable {
    let url: URL
    let pageIndex: Int
    let fitMode: PDFFitMode

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
        context.coordinator.loadDocument(url: url, into: view)
        context.coordinator.goToPage(pageIndex, in: view)
        return view
    }

    func updateNSView(_ view: FittingPDFView, context: Context) {
        if view.fitMode != fitMode {
            view.fitMode = fitMode
        }
        context.coordinator.loadDocument(url: url, into: view)
        context.coordinator.goToPage(pageIndex, in: view)
    }

    final class Coordinator {
        private var loadedURL: URL?
        private var displayedPageIndex: Int?

        func loadDocument(url: URL, into view: FittingPDFView) {
            guard loadedURL != url else { return }
            view.document = PDFDocument(url: url)
            loadedURL = url
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

final class FittingPDFView: PDFView {
    var fitMode: PDFFitMode = .automatic {
        didSet {
            lastFitSize = .zero
            if fitMode == .automatic {
                autoScales = true
            } else {
                applyCustomFit(force: true)
            }
        }
    }

    private var lastFitSize = CGSize.zero

    override func layout() {
        super.layout()
        if fitMode != .automatic {
            applyCustomFit()
        }
    }

    func refreshFit() {
        lastFitSize = .zero
        if fitMode == .automatic {
            autoScales = true
        } else {
            applyCustomFit(force: true)
        }
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
