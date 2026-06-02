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
    @State private var sidebarModel = SidebarModel()
    @State private var navigation = AppNavigation()
    @State private var accountStore = AccountStore()
    @State private var mailStore = MailStore()
    @State private var labelStore = LabelStore()
    // Held here (rather than locally in MailboxDetail) so account removal can purge
    // its per-account content via the environment (issue #8).
    @State private var contentStore = MessageContentStore()

    var body: some Scene {
        WindowGroup("") {
            ContentView(
                sidebarModel: sidebarModel,
                navigation: navigation,
                accountStore: accountStore,
                mailStore: mailStore,
                labelStore: labelStore,
                contentStore: contentStore)
                .frame(minWidth: WindowMetrics.minSize.width, minHeight: WindowMetrics.minSize.height)
        }
        .defaultSize(width: WindowMetrics.defaultSize.width, height: WindowMetrics.defaultSize.height)
        .windowStyle(.hiddenTitleBar)
        .commands {
            // Replace the disabled stock "Settings…" item (there is no SwiftUI
            // Settings scene) with one that toggles the in-window settings panel,
            // keeping the conventional ⌘, shortcut.
            CommandGroup(replacing: .appSettings) {
                Button("Settings…", action: navigation.toggleSettings)
                    .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(after: .toolbar) {
                Button("Toggle Sidebar", action: sidebarModel.toggleAnimated)
                    .keyboardShortcut("b", modifiers: .command)
            }
        }
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
