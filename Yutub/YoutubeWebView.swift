//
//  YoutubeWebView.swift
//  Yutub
//
//  Created by Pau on 9/6/25.
//

import SwiftUI
@preconcurrency import WebKit

// MARK: - WebView Logic
struct YoutubeWebView: UIViewRepresentable {
    @ObservedObject var webViewStore: WebViewStore
    @EnvironmentObject var settings: SettingsStore
    @Binding var showBackButton: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = webViewStore.webView!
        webView.navigationDelegate = context.coordinator
        applySettings(to: webView)
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // SwiftUI calls this on every state change (the back button, canGoBack…), so only the
        // settings are re-applied here; the page scripts are injected once per load, in didFinish.
        applySettings(to: webView)
    }
    
    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(self, showBackButton: $showBackButton)
    }
    
    /// Reads a script bundled in Yutub/scripts.
    private static func loadJS(named name: String) -> String? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "js"),
              let js = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return js
    }

    private static func run(_ js: String, in webView: WKWebView, label: String) {
        webView.evaluateJavaScript(js) { _, error in
            if let error { print("Error injecting \(label): \(error.localizedDescription)") }
        }
    }

    /// The scripts that reshape YouTube's player. They build DOM and add observers, so each one
    /// runs at most once per page: a flag on `window` makes a second injection a no-op.
    /// YouTube navigates between videos without reloading, so once per page load is enough.
    func injectPageScripts(into webView: WKWebView) {
        for name in ["controlAlignment", "centeredControls", "scrubberButtonStyle"] {
            guard let js = Self.loadJS(named: name) else { continue }
            let flag = "__yutub_\(name)"
            Self.run("if (!window.\(flag)) { window.\(flag) = true; \(js)\n}", in: webView, label: name)
        }
        applySettings(to: webView)
    }

    /// Dark mode and autoplay: cheap and idempotent, so they can run whenever a setting changes.
    func applySettings(to webView: WKWebView) {
        if let js = Self.loadJS(named: "darkMode") {
            Self.run(js.replacingOccurrences(of: "/*__DARK_MODE__*/", with: settings.isDarkMode ? "true" : "false"), in: webView, label: "darkMode")
        }
        if let js = Self.loadJS(named: "autoplay") {
            Self.run(js.replacingOccurrences(of: "/*__AUTOPLAY__*/", with: settings.autoplayEnabled ? "true" : "false"), in: webView, label: "autoplay")
        }
        let background: UIColor = settings.isDarkMode ? .black : .white
        webView.backgroundColor = background
        webView.scrollView.backgroundColor = background
    }
}

// MARK: - WebView Store & Coordinator
class WebViewStore: NSObject, ObservableObject, WKScriptMessageHandler {
    @Published var webView: WKWebView!
    @Published var canGoBack: Bool = false
    
    private var backObserver: NSKeyValueObservation?
    
    override init() {
        super.init()
        // Set up user content controller and configuration
        let contentController = WKUserContentController()
        
#if DEBUG
        // Forward the page's console to Xcode's, in debug builds only.
        if let debugConsoleURL = Bundle.main.url(forResource: "debugConsole", withExtension: "js"),
           let debugConsoleContent = try? String(contentsOf: debugConsoleURL, encoding: .utf8) {
            let userScript = WKUserScript(source: debugConsoleContent, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            contentController.addUserScript(userScript)
        }
        contentController.add(self, name: "jsConsole")
#endif
        
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        config.preferences.isElementFullscreenEnabled = true
        self.webView = WKWebView(frame: .zero, configuration: config)
        self.webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_4) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
        
        // Add KVO observer for canGoBack
        backObserver = webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] webView, change in
            DispatchQueue.main.async {
                self?.canGoBack = webView.canGoBack
            }
        }
    }
    
    deinit {
        backObserver?.invalidate()
    }
    
    // Function to go back in webview
    func goBack() {
        if webView.canGoBack {
            webView.goBack()
        }
    }
    
    // WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "jsConsole", let body = message.body as? [String: Any] {
            let type = body["type"] as? String ?? "log"
            let msg = body["message"] as? String ?? ""
            print("[JS \(type.uppercased())]: \(msg)")
        }
    }
}

class WebViewCoordinator: NSObject, WKNavigationDelegate {
    var parent: YoutubeWebView
    var showBackButton: Binding<Bool>
    private var lastNavigationType: WKNavigationType = .other
    
    init(_ parent: YoutubeWebView, showBackButton: Binding<Bool>) {
        self.parent = parent
        self.showBackButton = showBackButton
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        
        // Track the navigation type
        lastNavigationType = navigationAction.navigationType
        
        if Self.isAllowed(url) {
            // Allow navigation within the web view
            decisionHandler(.allow)
        } else if navigationAction.navigationType == .linkActivated {
            // Only open in Safari if user tapped a link
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        } else {
            // For other navigation types, just cancel (don't open Safari)
            decisionHandler(.cancel)
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        parent.injectPageScripts(into: webView)
        
        // Update navigation state
        DispatchQueue.main.async {
            self.parent.webViewStore.canGoBack = webView.canGoBack
            // Only show back button if navigation was user-initiated
            switch self.lastNavigationType {
            case .linkActivated, .formSubmitted, .backForward:
                self.showBackButton.wrappedValue = true
            default:
                break
            }
        }
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        // Update navigation state when navigation starts
        DispatchQueue.main.async {
            self.parent.webViewStore.canGoBack = webView.canGoBack
        }
    }
    
    /// Whether a URL may load inside the app: YouTube itself, and Google's sign-in on any of its
    /// country domains (accounts.google.com, accounts.google.es, accounts.google.co.uk…).
    /// Hosts are matched exactly or by subdomain, so look-alikes such as `youtube.com.example.net`
    /// or `notyoutube.com` open in Safari (if tapped) instead of inside the app.
    static func isAllowed(_ url: URL) -> Bool {
        guard ["https", "http"].contains(url.scheme?.lowercased() ?? ""), let host = url.host?.lowercased() else { return false }
        let domains = ["youtube.com", "youtu.be", "accounts.google.com"]
        if domains.contains(where: { host == $0 || host.hasSuffix("." + $0) }) { return true }
        return host.range(of: #"^accounts\.google\.(com?\.)?[a-z]{2,3}$"#, options: .regularExpression) != nil
    }
}
