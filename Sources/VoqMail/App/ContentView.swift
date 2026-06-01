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
    let accountStore: AccountStore
    let mailStore: MailStore

    var body: some View {
        MainMailSplitView()
            .environment(sidebarModel)
            .environment(accountStore)
            .environment(mailStore)
            // WindowChromeConfigurator renders nothing; it is attached only for its
            // side effect of reaching and configuring the enclosing NSWindow.
            .background(WindowChromeConfigurator())
            .ignoresSafeArea(.container, edges: .top)
            // Restore previously signed-in accounts (refresh token → access token
            // → address) so the app shows signed-in state without a re-login.
            .task { await accountStore.restoreAccounts() }
    }
}

#Preview {
    ContentView(
        sidebarModel: SidebarModel(),
        accountStore: AccountStore(),
        mailStore: MailStore())
}
