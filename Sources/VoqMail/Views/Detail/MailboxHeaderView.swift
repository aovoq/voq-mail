//
//  MailboxHeaderView.swift
//  VoqMail
//
//  The detail pane's top bar: the selected mailbox's icon, title, and a count of
//  the messages it holds. Spans the full width above the message list / message
//  detail split.
//

import SwiftUI

struct MailboxHeaderView: View {
    let mailbox: Mailbox
    let messageCount: Int
    /// Leading padding for the content. Animates wider when the sidebar collapses
    /// so the icon/title slide right, clearing the traffic lights and toggle button.
    var leadingPadding: CGFloat = Metrics.mailboxHeaderHorizontalPadding
    /// When set, the header shows a "New Message" button that opens the composer.
    var onCompose: (() -> Void)? = nil

    var body: some View {
        DetailPaneHeader(
            systemImage: mailbox.systemImage,
            title: mailbox.title,
            leadingPadding: leadingPadding
        ) {
            HStack(spacing: 12) {
                Text("\(messageCount) \(messageCount == 1 ? "message" : "messages")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let onCompose {
                    Button { onCompose() } label: {
                        Label("New Message", systemImage: "square.and.pencil")
                    }
                }
            }
        }
    }
}
