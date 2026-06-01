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

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: mailbox.systemImage)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text(mailbox.title)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)

                Spacer()

                Text("\(messageCount) \(messageCount == 1 ? "message" : "messages")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, leadingPadding)
            .padding(.trailing, Metrics.mailboxHeaderHorizontalPadding)
            .frame(height: Metrics.mailboxHeaderHeight)

            // The 1pt border is attached *below* the content row rather than
            // carved out of it, so the header content stays a full
            // `mailboxHeaderHeight` and the border adds 1pt outside it.
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: Metrics.mailboxHeaderBorderWidth)
        }
    }
}
