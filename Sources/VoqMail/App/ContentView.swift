//
//  ContentView.swift
//  VoqMail
//
//  The root view. Shows the main split layout and attaches WindowChromeConfigurator
//  as an invisible background so the host NSWindow receives its custom chrome.
//

import AppKit
import SwiftData
import SwiftUI

struct ContentView: View {
    let sidebarModel: SidebarModel
    let navigation: AppNavigation
    let accountStore: AccountStore
    let mailStore: MailStore
    let labelStore: LabelStore
    let contentStore: MessageContentStore
    let sendStore: SendStore
    let replyAssistStore: ReplyAssistStore  // reply-assist:
    let modelContainer: ModelContainer

    var body: some View {
        MainMailSplitView()
            .environment(sidebarModel)
            .environment(navigation)
            .environment(accountStore)
            .environment(mailStore)
            .environment(labelStore)
            .environment(contentStore)
            .environment(sendStore)
            .environment(replyAssistStore)  // reply-assist:
            // WindowChromeConfigurator renders nothing; it is attached only for its
            // side effect of reaching and configuring the enclosing NSWindow.
            .background(WindowChromeConfigurator())
            .ignoresSafeArea(.container, edges: .top)
            // Attach the persistent cache to the stores (issue #12) *before* restoring
            // accounts, so the first label/message load can paint from disk without
            // waiting on the network. Then wire the per-account purge/reauth hooks,
            // restore previously signed-in accounts, and start incremental polling.
            .task {
                mailStore.attach(context: modelContainer.mainContext)
                labelStore.attach(context: modelContainer.mainContext)

                accountStore.onAccountRemoved = { [labelStore, mailStore, contentStore, sendStore] id in
                    labelStore.purge(accountID: id)
                    mailStore.purge(accountID: id)
                    contentStore.purge(accountID: id)
                    sendStore.purge(accountID: id)
                }
                // After a re-auth, reload the slices that errored on the dead token —
                // sidebar labels and the open message list — so the account visibly
                // returns to normal without a manual mailbox switch (issue #11).
                accountStore.onAccountReauthenticated = { [weak accountStore, labelStore, mailStore] id in
                    guard let accountStore else { return }
                    labelStore.reload(accountID: id, authorizer: accountStore)
                    Task { await mailStore.reloadActive(accountID: id, authorizer: accountStore) }
                }
                await accountStore.restoreAccounts()

                startIncrementalSync()
            }
    }

    /// Drives incremental sync (issue #13): poll every signed-in account's
    /// `history.list` on a fixed cadence, and immediately whenever the app regains
    /// focus. Accounts behind the re-auth banner are skipped so a lapsed credential
    /// doesn't burn polls.
    ///
    /// The pollers are unstructured Tasks that outlive this view, so they are latched
    /// to start exactly once (`beginPolling`): `ContentView.task` can re-run — a second
    /// window or a re-created root view — and without the latch each recreation would
    /// stack another duplicate set of `history.list` loops that closing the window
    /// would not stop.
    private func startIncrementalSync() {
        guard mailStore.beginPolling() else { return }
        @Sendable @MainActor func syncAll() async {
            for account in accountStore.accounts where !accountStore.needsReauthentication(account.id) {
                await mailStore.historySync(accountID: account.id, authorizer: accountStore)
            }
        }
        // Focus sync: every app activation (return-to-app) triggers a poll.
        Task { @MainActor in
            let activations = NotificationCenter.default.notifications(
                named: NSApplication.didBecomeActiveNotification)
            for await _ in activations { await syncAll() }
        }
        // Interval sync: poll on a fixed cadence between activations.
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(SyncMetrics.pollInterval))
                await syncAll()
            }
        }
    }
}

#Preview {
    ContentView(
        sidebarModel: SidebarModel(),
        navigation: AppNavigation(),
        accountStore: AccountStore(),
        mailStore: MailStore(),
        labelStore: LabelStore(),
        contentStore: MessageContentStore(),
        sendStore: SendStore(),
        replyAssistStore: ReplyAssistStore(),  // reply-assist:
        modelContainer: try! ModelContainer(
            for: Schema([CachedMessage.self, CachedLabel.self, SyncState.self]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
}
