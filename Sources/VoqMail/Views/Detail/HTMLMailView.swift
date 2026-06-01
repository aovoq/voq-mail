//
//  HTMLMailView.swift
//  VoqMail
//
//  Narrow WebKit bridge for rendering trusted/demo HTML mail content in the
//  detail pane. JavaScript is disabled and updates avoid unnecessary reloads.
//

import SwiftUI
import WebKit

struct HTMLMailView: NSViewRepresentable {
    let html: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastLoadedHTML != html else { return }
        context.coordinator.lastLoadedHTML = html
        webView.loadHTMLString(html, baseURL: nil)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastLoadedHTML: String?
    }
}
