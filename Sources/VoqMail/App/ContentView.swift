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

    var body: some View {
        MainMailSplitView()
            .environment(sidebarModel)
            .environment(navigation)
            .environment(accountStore)
            .environment(mailStore)
            .environment(labelStore)
            .environment(contentStore)
            // WindowChromeConfigurator renders nothing; it is attached only for its
            // side effect of reaching and configuring the enclosing NSWindow.
            .background(WindowChromeConfigurator())
            .ignoresSafeArea(.container, edges: .top)
            // Wire the per-account purge once (the stores aren't reachable from
            // AccountStore itself), then restore previously signed-in accounts
            // (refresh token → access token → address) so the app shows signed-in
            // state without a re-login.
            .task {
                accountStore.onAccountRemoved = { [labelStore, mailStore, contentStore] id in
                    labelStore.purge(accountID: id)
                    mailStore.purge(accountID: id)
                    contentStore.purge(accountID: id)
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
        contentStore: MessageContentStore())
}
