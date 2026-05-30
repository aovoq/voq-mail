//
//  MailboxDetail.swift
//  VoqMail
//
//  The detail pane shown beside the sidebar: a large icon, the mailbox title, and
//  a placeholder line. Falls back to a neutral prompt when nothing is selected.
//

import SwiftUI

struct MailboxDetail: View {
    let mailbox: Mailbox?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: mailbox?.systemImage ?? "tray")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.tint)

            Text(mailbox?.title ?? "Select a mailbox")
                .font(.largeTitle.weight(.semibold))

            Text("This detail pane changes with the sidebar selection.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
