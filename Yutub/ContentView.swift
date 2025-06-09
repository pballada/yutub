//
//  ContentView.swift
//  Yutub
//
//  Created by Pau on 7/10/24.
//

import SwiftUI
@preconcurrency import WebKit

// MARK: - Main ContentView
struct ContentView: View {
    @State private var selectedTab = 0
    @StateObject private var webViewStore = WebViewStore()
    @State private var currentURL: URL = URL(string: "https://www.youtube.com")!
    @EnvironmentObject  var settings: SettingsStore
    
    var body: some View {
        TabView(selection: $selectedTab.onChange { newValue in
            // Pause video on tab switch to avoid overlapping audio
            updateWebViewURL(for: newValue)
        }) {
            // Home Tab
            Text("Home")
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)
            
            // Watch Later Tab
            Text("Watch Later")
                .tabItem { Label("Watch Later", systemImage: "clock") }
                .tag(1)
            
            // Subscriptions Tab
            Text("Subscriptions")
                .tabItem { Label("Subscriptions", systemImage: "rectangle.stack.person.crop") }
                .tag(2)
            
            // History Tab
            Text("History")
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
        .overlay(
            Group {
                if selectedTab != 4 {
                    YoutubeWebView(webViewStore: webViewStore)
                        .edgesIgnoringSafeArea(.all)
                }
            }
        )
        .ornament(attachmentAnchor: .scene(.top),
                  contentAlignment: .center
        ) {
            if selectedTab != 4 && webViewStore.canGoBack {
                Button {
                    webViewStore.goBack()
                } label: {
                    Text("Back")
                }
                .glassBackgroundEffect()
            }
        }
        .onAppear {
            webViewStore.webView.load(URLRequest(url: currentURL))
        }
    }
    
    private func updateWebViewURL(for tab: Int) {
        switch tab {
        case 0:
            currentURL = URL(string: "https://www.youtube.com")!
        case 1:
            currentURL = URL(string: "https://www.youtube.com/playlist?list=WL")!
        case 2:
            currentURL = URL(string: "https://www.youtube.com/feed/subscriptions")!
        case 3:
            currentURL = URL(string: "https://www.youtube.com/feed/history")!
        default:
            break
        }
        webViewStore.webView.load(URLRequest(url: currentURL))
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
