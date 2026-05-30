//
//  SampleData.swift
//  VoqMail
//
//  Placeholder demo data standing in for a real mail backend. The mailboxes and
//  messages are defined together in one file because of an invariant they share:
//  every `MailMessage.mailboxID` must match some `Mailbox.id`. Keeping both lists
//  here makes that relationship easy to see and keep in sync.
//

import Foundation

extension Mailbox {
    /// Demo mailboxes shown in the sidebar.
    static let samples: [Mailbox] = [
        Mailbox(id: "inbox", title: "Inbox", systemImage: "tray.fill", count: 12),
        Mailbox(id: "sent", title: "Sent", systemImage: "paperplane.fill", count: nil),
        Mailbox(id: "drafts", title: "Drafts", systemImage: "doc.fill", count: 3),
        Mailbox(id: "archive", title: "Archive", systemImage: "archivebox.fill", count: nil),
        Mailbox(id: "trash", title: "Trash", systemImage: "trash.fill", count: nil)
    ]
}

extension MailMessage {
    /// Demo messages. Each `mailboxID` matches a `Mailbox.id` defined above.
    static let samples: [MailMessage] = [
        MailMessage(
            id: "1",
            sender: "Mina",
            subject: "Design pass",
            preview: "The sidebar options are ready to compare.",
            mailboxID: "inbox"
        ),
        MailMessage(
            id: "2",
            sender: "Theo",
            subject: "Build notes",
            preview: "SwiftPM bundle launch works cleanly now.",
            mailboxID: "inbox"
        ),
        MailMessage(
            id: "3",
            sender: "Ari",
            subject: "Draft copy",
            preview: "Keeping the first screen quiet and useful.",
            mailboxID: "drafts"
        ),
        MailMessage(
            id: "4",
            sender: "Voq",
            subject: "Sent sample",
            preview: "A sent message preview for the middle column.",
            mailboxID: "sent"
        ),
        MailMessage(
            id: "5",
            sender: "System",
            subject: "Archived thread",
            preview: "Older conversation moved out of the inbox.",
            mailboxID: "archive"
        )
    ]
}
