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
            senderAddress: "mina@example.com",
            recipients: ["demo@example.com"],
            subject: "Design pass",
            preview: "The sidebar options are ready to compare.",
            htmlBody: sampleHTML(
                title: "Design pass",
                body: "The original sidebar stays intact. This message body is rendered through WebKit so HTML mail can be shown in the detail pane."
            ),
            receivedAt: Date(timeIntervalSinceNow: -900),
            isRead: false,
            mailboxID: "inbox"
        ),
        MailMessage(
            id: "2",
            sender: "Theo",
            senderAddress: "theo@example.com",
            recipients: ["demo@example.com"],
            subject: "Build notes",
            preview: "SwiftPM bundle launch works cleanly now.",
            htmlBody: sampleHTML(
                title: "Build notes",
                body: "SwiftPM bundle launch works cleanly now. The detail pane now supports message selection, HTML rendering, attachments, and replies."
            ),
            receivedAt: Date(timeIntervalSinceNow: -3_600),
            isRead: true,
            attachments: [
                MailAttachment(id: "attachment-1", filename: "sync-plan.txt", byteCount: 1_840, contentType: "text/plain", localFileURL: nil)
            ],
            mailboxID: "inbox"
        ),
        MailMessage(
            id: "3",
            sender: "Ari",
            senderAddress: "ari@example.com",
            recipients: ["demo@example.com"],
            subject: "Draft copy",
            preview: "Keeping the first screen quiet and useful.",
            receivedAt: Date(timeIntervalSinceNow: -7_200),
            isRead: false,
            mailboxID: "drafts"
        ),
        MailMessage(
            id: "4",
            sender: "Voq",
            senderAddress: "demo@example.com",
            recipients: ["team@example.com"],
            subject: "Sent sample",
            preview: "A sent message preview for the middle column.",
            receivedAt: Date(timeIntervalSinceNow: -20_000),
            mailboxID: "sent"
        ),
        MailMessage(
            id: "5",
            sender: "System",
            senderAddress: "system@example.com",
            recipients: ["demo@example.com"],
            subject: "Archived thread",
            preview: "Older conversation moved out of the inbox.",
            receivedAt: Date(timeIntervalSinceNow: -80_000),
            mailboxID: "archive"
        )
    ]

    private static func sampleHTML(title: String, body: String) -> String {
        """
        <html>
        <body style="font: -apple-system-body; color: #1f2328;">
        <h2>\(title)</h2>
        <p>\(body)</p>
        </body>
        </html>
        """
    }
}
