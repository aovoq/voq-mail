//
//  DemoViews.swift
//  VoqMail — Reference (not used by the running app)
//
//  Alternative layouts kept for learning and comparison. The running app uses
//  `MainMailSplitView` (Views/MainLayout); these demos show simpler two- and
//  three-column arrangements built from the same components. Nothing references them.
//

import SwiftUI

/// Reference: a plain two-column sidebar + detail layout, without the animated seam.
struct NativeTwoColumnDemo: View {
    @State private var selection: Mailbox.ID? = Mailbox.samples.first?.id

    var body: some View {
        HStack(spacing: 0) {
            CustomSidebarList(selection: $selection)
                .frame(width: 180)

            MailboxDetail(mailbox: selectedMailbox)
                .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var selectedMailbox: Mailbox? {
        Mailbox.sample(for: selection)
    }
}

/// Reference: a three-column layout — mailboxes, the selected mailbox's messages,
/// and the selected message — showing how the detail components compose.
struct ThreeColumnDemo: View {
    @State private var mailboxSelection: Mailbox.ID? = Mailbox.samples.first?.id
    @State private var messageSelection: MailMessage.ID? = MailMessage.samples.first?.id

    var body: some View {
        HStack(spacing: 0) {
            CustomSidebarList(selection: $mailboxSelection)
                .frame(width: 180)

            MessageList(messages: messages, selection: $messageSelection)
                .frame(width: 280)

            MessageDetail(message: selectedMessage)
                .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
        }
        // When the mailbox changes, reset the message selection to its first message.
        .onChange(of: mailboxSelection) { _, _ in
            messageSelection = messages.first?.id
        }
    }

    private var messages: [MailMessage] {
        MailMessage.samples(in: mailboxSelection)
    }

    private var selectedMessage: MailMessage? {
        messages.first { $0.id == messageSelection }
    }
}
