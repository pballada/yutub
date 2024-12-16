//
//  ContentView.swift
//  Yutub
//
//  Created by Pau on 7/10/24.
//

import SwiftUI
@preconcurrency import WebKit

// MARK: - Centralized Settings Store
class SettingsStore: ObservableObject {
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    @AppStorage("autoplayEnabled") var autoplayEnabled: Bool = true
}

// MARK: - WebView Logic
struct YoutubeWebView: UIViewRepresentable {
    let url: URL
    @ObservedObject var webViewStore: WebViewStore
    @EnvironmentObject var settings: SettingsStore

    func makeUIView(context: Context) -> WKWebView {
        let webView = webViewStore.webView
        webView.navigationDelegate = context.coordinator
        webView.backgroundColor = settings.isDarkMode ? .black : .white
        webView.scrollView.backgroundColor = settings.isDarkMode ? .black : .white
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        applyCurrentSettingsToWebView(webView)
    }

    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(self)
    }
    
    func applyCurrentSettingsToWebView(_ webView: WKWebView) {
        // Check and apply dark mode script only if not already applied
            let checkAndApplyDarkModeScript = """
            (function() {
                const isDarkModeEnabled = document.body.getAttribute('dark') === 'true';
                if (isDarkModeEnabled !== \(settings.isDarkMode)) {
                    document.body.setAttribute('dark', '\(settings.isDarkMode ? "true" : "false")');
                    if (typeof yt !== 'undefined' && yt.config_) {
                        yt.config_.EXPERIMENT_FLAGS.web_dark_theme = \(settings.isDarkMode);
                        if (yt.config_.WEB_PLAYER_CONTEXT_CONFIGS && yt.config_.WEB_PLAYER_CONTEXT_CONFIGS['WEB_PLAYER_CONTEXT_ID_KEBAB']) {
                            yt.config_.WEB_PLAYER_CONTEXT_CONFIGS['WEB_PLAYER_CONTEXT_ID_KEBAB'].webPlayerContextConfig.darkTheme = \(settings.isDarkMode);
                        }
                    }
                }
            })();
            """

            // Check and apply autoplay script only if not already applied
            let checkAndApplyAutoplayScript = """
            (function() {
                if (typeof yt !== 'undefined' && yt.config_) {
                    const isAutoplayEnabled = yt.config_.EXPERIMENT_FLAGS.autoplay_video === \(settings.autoplayEnabled);
                    if (!isAutoplayEnabled) {
                        yt.config_.EXPERIMENT_FLAGS.autoplay_video = \(settings.autoplayEnabled);
                    }
                }
            })();
            """

        // Inject scripts and log errors if any
        webView.evaluateJavaScript(checkAndApplyDarkModeScript) { _, error in
            if let error = error {
                print("Error injecting dark mode script: \(error.localizedDescription)")
            }
        }

        webView.evaluateJavaScript(checkAndApplyAutoplayScript) { _, error in
            if let error = error {
                print("Error injecting autoplay script: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - WebView Store & Coordinator
class WebViewStore: NSObject, ObservableObject {
    @Published var webView: WKWebView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())

    override init() {
        super.init()
    }
}

class WebViewCoordinator: NSObject, WKNavigationDelegate {
    var parent: YoutubeWebView

    init(_ parent: YoutubeWebView) {
        self.parent = parent
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        if isYouTubeRelated(url: url) {
            // Allow navigation within the web view
            decisionHandler(.allow)
        } else {
            // Open non-YouTube links in Safari
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Initial settings application once page is loaded
        parent.applyCurrentSettingsToWebView(webView)
    }

    private func isYouTubeRelated(url: URL) -> Bool {
        let youtubeDomains = ["youtube.com", "youtu.be"]
        return youtubeDomains.contains { url.host?.contains($0) == true }
    }
}

// MARK: - Main ContentView
struct ContentView: View {
    @State private var selectedTab = 0
    @State private var webViewStores: [WebViewStore] = [
        WebViewStore(),
        WebViewStore(),
        WebViewStore(),
        WebViewStore()
    ]
    
    @StateObject private var settings = SettingsStore()
    
    var body: some View {
        TabView(selection: $selectedTab.onChange { newValue in
            // Pause video on tab switch to avoid overlapping audio
            pauseAllExceptCurrentTab(currentTab: newValue)
        }) {
            // Home Tab
            TabViewContentView(url: URL(string: "https://www.youtube.com")!, webViewStore: webViewStores[0])
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)
            
            // Watch Later Tab
            TabViewContentView(url: URL(string: "https://www.youtube.com/playlist?list=WL")!, webViewStore: webViewStores[1])
                .tabItem { Label("Watch Later", systemImage: "clock") }
                .tag(1)
            
            // Subscriptions Tab
            TabViewContentView(url: URL(string: "https://www.youtube.com/feed/subscriptions")!, webViewStore: webViewStores[2])
                .tabItem { Label("Subscriptions", systemImage: "rectangle.stack.person.crop") }
                .tag(2)
            
            // History Tab
            TabViewContentView(url: URL(string: "https://www.youtube.com/feed/history")!, webViewStore: webViewStores[3])
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(3)
            
            // Settings Tab
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(4)
        }
        // Bind the system color scheme to the setting
        .environment(\.colorScheme, settings.isDarkMode ? .dark : .light)
        .environmentObject(settings)
    }
    
    private func pauseAllExceptCurrentTab(currentTab: Int) {
        webViewStores.indices.forEach { index in
            if index != currentTab {
                webViewStores[index].webView.evaluateJavaScript("document.querySelector('video')?.pause();", completionHandler: nil)
            }
        }
    }
}

struct TabViewContentView: View {
    let url: URL
    @ObservedObject var webViewStore: WebViewStore
    @EnvironmentObject var settings: SettingsStore
    
    var body: some View {
        ZStack {
            YoutubeWebView(url: url, webViewStore: webViewStore)
                .edgesIgnoringSafeArea(.all)
        }
    }
}

extension Binding {
    func onChange(_ action: @escaping (Value) -> Void) -> Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: {
                self.wrappedValue = $0
                action($0)
            }
        )
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.largeTitle)
                .padding()

            // Dark Mode Toggle
            Toggle(isOn: $settings.isDarkMode) {
                Text("Dark Mode")
                    .font(.headline)
            }
            .tint(.red)
            .padding()

            // Autoplay Toggle
            Toggle(isOn: $settings.autoplayEnabled) {
                Text("Autoplay")
                    .font(.headline)
            }
            .tint(.red)
            .padding()

            Spacer()
        }
        .padding()
    }
}

// MARK: - App Entry
@main
struct VisionProApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
