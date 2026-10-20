import SwiftUI
import WebKit

struct FormulaWebView: NSViewRepresentable {
    let latex: String
    let isDark: Bool
    @Binding var height: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: "size")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsBackForwardNavigationGestures = false
        context.coordinator.webView = webView
        context.coordinator.load(latex: latex, isDark: isDark)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.currentLatex != latex || context.coordinator.currentDark != isDark {
            context.coordinator.load(latex: latex, isDark: isDark)
        }
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "size")
        nsView.stopLoading()
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: FormulaWebView
        weak var webView: WKWebView?
        var currentLatex: String = ""
        var currentDark: Bool = false

        init(parent: FormulaWebView) {
            self.parent = parent
        }

        func load(latex: String, isDark: Bool) {
            currentLatex = latex
            currentDark = isDark
            guard let webView else { return }
            let baseURL = AppPaths.katexDirectory
            let cssURL = baseURL?.appendingPathComponent("katex.min.css")
            let jsURL = baseURL?.appendingPathComponent("katex.min.js")
            guard let cssURL, let jsURL,
                  FileManager.default.fileExists(atPath: cssURL.path),
                  FileManager.default.fileExists(atPath: jsURL.path) else {
                let escaped = Self.htmlEscape(latex)
                webView.loadHTMLString("<html><body style='font-family:ui-monospace;color:#888;padding:8px'>\(escaped)</body></html>", baseURL: nil)
                return
            }
            let textColor = isDark ? "#E8EDF7" : "#172033"
            let codeColor = isDark ? "#9FB4D8" : "#5C6B8A"
            let latexLiteral = Self.jsString(latex)
            let html = """
            <!doctype html>
            <html>
            <head>
              <meta charset="utf-8">
              <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline' 'self'; script-src 'unsafe-inline' 'self'; font-src 'self';">
              <link rel="stylesheet" href="katex.min.css">
              <script src="katex.min.js"></script>
              <style>
                html, body { margin: 0; padding: 0; background: transparent; overflow: hidden; }
                #math { color: \(textColor); padding: 9px 6px 10px 6px; font-size: 17px; overflow-x: auto; overflow-y: hidden; }
                .katex-display { margin: 0; }
                .katex { font-size: 1.05em; }
                .fallback { white-space: pre-wrap; font-family: ui-monospace, monospace; font-size: 12px; color: \(codeColor); }
              </style>
            </head>
            <body>
              <div id="math"></div>
              <script>
                (function() {
                  const latex = \(latexLiteral);
                  const el = document.getElementById('math');
                  try {
                    if (window.katex) {
                      katex.render(latex, el, {displayMode: true, throwOnError: false, strict: false, trust: false});
                    } else {
                      el.textContent = latex;
                      el.className = 'fallback';
                    }
                  } catch (e) {
                    el.textContent = latex;
                    el.className = 'fallback';
                  }
                  function report() {
                    try {
                      const h = Math.max(38, Math.ceil(document.documentElement.scrollHeight || 0), Math.ceil(document.body.scrollHeight || 0));
                      window.webkit.messageHandlers.size.postMessage(h);
                    } catch (e) {}
                  }
                  setTimeout(report, 40);
                  setTimeout(report, 180);
                  if (document.fonts && document.fonts.ready) { document.fonts.ready.then(report); }
                })();
              </script>
            </body>
            </html>
            """
            webView.loadHTMLString(html, baseURL: baseURL)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "size", let value = message.body as? NSNumber else { return }
            let newHeight = min(max(CGFloat(truncating: value), 38), 420)
            if abs(parent.height - newHeight) > 1 {
                DispatchQueue.main.async { [weak self] in
                    self?.parent.height = newHeight
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                webView.evaluateJavaScript("""
                (function(){ try { window.webkit.messageHandlers.size.postMessage(Math.ceil(document.documentElement.scrollHeight)); } catch(e) {} })();
                """)
            }
        }

        private static func jsString(_ value: String) -> String {
            let encoder = JSONEncoder()
            guard let data = try? encoder.encode(value), var string = String(data: data, encoding: .utf8) else {
                return "\"\""
            }
            string = string.replacingOccurrences(of: "<", with: "\\u003c")
            string = string.replacingOccurrences(of: ">", with: "\\u003e")
            string = string.replacingOccurrences(of: "&", with: "\\u0026")
            string = string.replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            string = string.replacingOccurrences(of: "\u{2029}", with: "\\u2029")
            return string
        }

        private static func htmlEscape(_ value: String) -> String {
            value
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
        }
    }
}

struct EquationCard: View {
    let equation: EquationEntry
    @Environment(\.colorScheme) private var colorScheme
    @State private var height: CGFloat = 56
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(equation.nameEN)
                        .font(AppFont.body(12.5, weight: .semibold))
                    Text(equation.nameZH)
                        .font(AppFont.chinese(11.5))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(equation.latex, forType: .string)
                    copied = true
                    Task {
                        try? await Task.sleep(nanoseconds: 1_400_000_000)
                        copied = false
                    }
                } label: {
                    Label(copied ? "已复制" : "复制 LaTeX", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(AppFont.chinese(9.5))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            FormulaWebView(latex: equation.latex, isDark: colorScheme == .dark, height: $height)
                .frame(height: height)
                .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(equation.explanationEN)
                    .font(AppFont.body(11.5))
                    .foregroundStyle(.primary.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
                Text(equation.explanationZH)
                    .font(AppFont.chinese(11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color.primary.opacity(0.028), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}
