//
//  SidebarList.swift
//  VoqMail — Reference (not used by the running app)
//
//  A native SwiftUI `List` version of the sidebar, kept as a reference example.
//  The running app uses `CustomSidebarList` (Views/Sidebar) instead, which gives
//  finer control over row styling and the custom split-view background. Nothing
//  in the app references this type.
//

import SwiftUI

struct SidebarList: View {
    @Binding var selection: Mailbox.ID?

    var body: some View {
        List(selection: $selection) {
            Section("Mailboxes") {
                ForEach(Mailbox.samples) { mailbox in
                    Label {
                        HStack {
                            Text(mailbox.title)
                            Spacer()
                            if let count = mailbox.count {
                                Text(count, format: .number)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: mailbox.systemImage)
                    }
                    .tag(mailbox.id)
                }
            }
        }
        .listStyle(.sidebar)
    }
}
