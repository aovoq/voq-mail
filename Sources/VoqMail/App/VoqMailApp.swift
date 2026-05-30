//
//  VoqMailApp.swift
//  VoqMail
//
//  The app entry point. Declares the single window and hands control to ContentView.
//  An AppDelegate makes the app behave as a normal foreground app and brings it to
//  the front on launch — needed because a SwiftPM executable has no Info.plist to
//  set the activation policy.
//

import AppKit
import SwiftUI

@main
struct VoqMailApp: App {
    // Bridges an AppKit application delegate into the SwiftUI app lifecycle.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("") {
            ContentView()
                .frame(minWidth: WindowMetrics.minSize.width, minHeight: WindowMetrics.minSize.height)
        }
        .defaultSize(width: WindowMetrics.defaultSize.width, height: WindowMetrics.defaultSize.height)
        .windowStyle(.hiddenTitleBar)
    }
}

/// Handles process-level setup SwiftUI doesn't cover for a SwiftPM executable:
/// become a regular Dock app and activate (focus) the window on launch.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
