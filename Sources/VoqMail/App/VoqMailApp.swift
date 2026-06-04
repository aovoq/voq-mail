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
import SwiftData
import SwiftUI

@main
struct VoqMailApp: App {
    // Bridges an AppKit application delegate into the SwiftUI app lifecycle.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    // The on-disk SwiftData cache (issue #12). Built once; handed to ContentView so
    // the stores can attach its main context before the first load.
    @State private var modelContainer = VoqMailApp.makeModelContainer()
    @State private var sidebarModel = SidebarModel()
    @State private var navigation = AppNavigation()
    @State private var accountStore = AccountStore()
    @State private var mailStore = MailStore()
    @State private var labelStore = LabelStore()
    // Held at scene scope so AccountStore's onAccountRemoved purge hook (wired in
    // ContentView) can reach it when an account is removed (issue #8).
    @State private var contentStore = MessageContentStore()
    // Per-account send-in-flight state, partitioned like the other stores (issue
    // #8) so a send completion can't surface on another account's UI.
    @State private var sendStore = SendStore()
    // reply-assist: AI reply-drafting state (codex app-server). Shared (one
    // composer is open at a time), so it isn't partitioned by account.
    @State private var replyAssistStore = ReplyAssistStore()

    var body: some Scene {
        WindowGroup("") {
            ContentView(
                sidebarModel: sidebarModel,
                navigation: navigation,
                accountStore: accountStore,
                mailStore: mailStore,
                labelStore: labelStore,
                contentStore: contentStore,
                sendStore: sendStore,
                replyAssistStore: replyAssistStore,  // reply-assist:
                modelContainer: modelContainer)
                .frame(minWidth: WindowMetrics.minSize.width, minHeight: WindowMetrics.minSize.height)
        }
        .modelContainer(modelContainer)
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

    /// Builds the on-disk message/label cache (issue #12). The store lives in
    /// Application Support, never in the `.app` bundle — `build_and_run.sh` deletes
    /// and re-signs the bundle every run, so a store inside it would be wiped (and a
    /// signed bundle is read-only). The cache holds no secrets (refresh tokens stay
    /// in the Keychain), so on an open/migration failure it is recreated destructively
    /// rather than carrying a migration plan: the network refills it on next launch.
    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([CachedMessage.self, CachedLabel.self, SyncState.self])
        let storeURL = URL.applicationSupportDirectory.appending(path: "VoqMail/cache.store")
        try? FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let config = ModelConfiguration(schema: schema, url: storeURL)
        if let container = try? ModelContainer(for: schema, configurations: config) {
            return container
        }
        // Incompatible / corrupt store: delete and retry once.
        try? FileManager.default.removeItem(at: storeURL)
        if let container = try? ModelContainer(for: schema, configurations: config) {
            return container
        }
        // Last resort: in-memory, so the app still launches (no persistence this run).
        let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: memory)
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
