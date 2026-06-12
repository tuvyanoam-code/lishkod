import SwiftUI
import WebKit

struct ContentView: View {
    var body: some View {
        LishkodWebView()
            .background(Color.white)
            .ignoresSafeArea(.container, edges: .bottom)
    }
}

struct LishkodWebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .white
        webView.scrollView.backgroundColor = .white
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic

        loadBundledSite(in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    private func loadBundledSite(in webView: WKWebView) {
        guard
            let webAppURL = Bundle.main.url(forResource: "WebApp", withExtension: "bundle"),
            let indexURL = Bundle(url: webAppURL)?.url(forResource: "index", withExtension: "html")
        else {
            webView.loadHTMLString(
                """
                <html dir="rtl" lang="he">
                  <body style="font-family:-apple-system;padding:24px">
                    לא נמצאו קבצי האתר בתוך האפליקציה.
                  </body>
                </html>
                """,
                baseURL: nil
            )
            return
        }

        webView.loadFileURL(indexURL, allowingReadAccessTo: webAppURL)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}

#Preview {
    ContentView()
}
