//
//  ContentView.swift
//  VoqMail
//
//  The root view. Shows the main split layout and attaches WindowChromeConfigurator
//  as an invisible background so the host NSWindow receives its custom chrome.
//

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
            // Wire the per-account purge once (the stores aren't reachable from
            // AccountStore itself), then restore previously signed-in accounts
            // (refresh token → access token → address) so the app shows signed-in
            // state without a re-login.
            .task {
                accountStore.onAccountRemoved = { [labelStore, mailStore, contentStore, sendStore] id in
                    labelStore.purge(accountID: id)
                    mailStore.purge(accountID: id)
                    contentStore.purge(accountID: id)
                    sendStore.purge(accountID: id)
                }
                // After a re-auth, reload the slices that errored on the dead token —
                // sidebar labels and the open message list — so the account visibly
                // returns to normal without a manual mailbox switch (issue #11).
                accountStore.onAccountReauthenticated = { [labelStore, mailStore] id in
                    let token: @Sendable () async throws -> String = {
                        try await accountStore.accessToken(for: id)
                    }
                    labelStore.reload(accountID: id, token: token)
                    Task { await mailStore.reloadActive(accountID: id, token: token) }
                }
                await accountStore.restoreAccounts()
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
        replyAssistStore: ReplyAssistStore())  // reply-assist:
}
