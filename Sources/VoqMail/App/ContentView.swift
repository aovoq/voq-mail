//
//  ContentView.swift
//  VoqMail
//
//  The root view. Shows the main split layout and attaches WindowChromeConfigurator
//  as an invisible background so the host NSWindow receives its custom chrome.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        MainMailSplitView()
            // WindowChromeConfigurator renders nothing; it is attached only for its
            // side effect of reaching and configuring the enclosing NSWindow.
            .background(WindowChromeConfigurator())
            .ignoresSafeArea(.container, edges: .top)
    }
}

#Preview {
    ContentView()
}
