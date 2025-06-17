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
        webView.backgroundColor = settings.isDarkMode ? .black : .white
        webView.scrollView.backgroundColor = settings.isDarkMode ? .black : .white
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        applyCurrentSettingsToWebView(webView)
    }
    
    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(self, showBackButton: $showBackButton)
    }
    
    func applyCurrentSettingsToWebView(_ webView: WKWebView) {
        // Helper to load JS from file
        func loadJS(named name: String) -> String? {
            guard let url = Bundle.main.url(forResource: name, withExtension: "js", subdirectory: ""),
                  let data = try? Data(contentsOf: url),
                  let js = String(data: data, encoding: .utf8) else { return nil }
            return js
        }
        
#if DEBUG
        // Load and inject debugConsole.js
        if let debugConsole = loadJS(named: "debugConsole") {
            webView.evaluateJavaScript(debugConsole) { _, error in
                if let error = error { print("Error debugConsole: \(error.localizedDescription)") }
            }
        }
#endif
        
        // Load and inject controlAlignment.js
        if let controlAlignmentJS = loadJS(named: "controlAlignment") {
            webView.evaluateJavaScript(controlAlignmentJS) { _, error in
                if let error = error { print("Error controlAlignment: \(error.localizedDescription)") }
            }
        }
        // Load and inject centeredControls.js
        if let centreTransportJS = loadJS(named: "centeredControls") {
            webView.evaluateJavaScript(centreTransportJS) { _, error in
                if let error = error { print("Error centering controls: \(error.localizedDescription)") }
            }
        }
        // Load and inject darkMode.js, replacing placeholder
        if var darkModeJS = loadJS(named: "darkMode") {
            darkModeJS = darkModeJS.replacingOccurrences(of: "/*__DARK_MODE__*/", with: settings.isDarkMode ? "true" : "false")
            webView.evaluateJavaScript(darkModeJS) { _, error in
                if let error = error { print("Error injecting dark mode script: \(error.localizedDescription)") }
            }
        }
        // Load and inject autoplay.js, replacing placeholder
        if var autoplayJS = loadJS(named: "autoplay") {
            autoplayJS = autoplayJS.replacingOccurrences(of: "/*__AUTOPLAY__*/", with: settings.autoplayEnabled ? "true" : "false")
            webView.evaluateJavaScript(autoplayJS) { _, error in
                if let error = error { print("Error injecting autoplay script: \(error.localizedDescription)") }
            }
        }
        // Load and inject scrubberButtonStyle.js
        if let scrubberButtonStyleJS = loadJS(named: "scrubberButtonStyle") {
            webView.evaluateJavaScript(scrubberButtonStyleJS) { _, error in
                if let error = error { print("Error modifying scrubber button size: \(error.localizedDescription)") }
            }
        }
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
        
        // Load debugConsole.js from file and add as user script
        if let debugConsoleURL = Bundle.main.url(forResource: "debugConsole", withExtension: "js"),
           let debugConsoleContent = try? String(contentsOf: debugConsoleURL) {
            let userScript = WKUserScript(source: debugConsoleContent, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            contentController.addUserScript(userScript)
        }
        
        // Add self as message handler
        contentController.add(self, name: "jsConsole")
        
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        if #available(macOS 12.3, *) {
            config.preferences.isElementFullscreenEnabled = true
        }
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
        
        if isYouTubeRelated(url: url) {
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
        // Initial settings application once page is loaded
        parent.applyCurrentSettingsToWebView(webView)
        
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
    
    private func isYouTubeRelated(url: URL) -> Bool {
        let youtubeDomains = ["youtube.com", "youtu.be", "accounts.google.com", "accounts.google"]
        return youtubeDomains.contains { url.host?.contains($0) == true }
    }
}
