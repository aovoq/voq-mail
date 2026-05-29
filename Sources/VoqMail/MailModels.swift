import Foundation

struct Mailbox: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String
    let count: Int?

    static let samples: [Mailbox] = [
        Mailbox(id: "inbox", title: "Inbox", systemImage: "tray.fill", count: 12),
        Mailbox(id: "sent", title: "Sent", systemImage: "paperplane.fill", count: nil),
        Mailbox(id: "drafts", title: "Drafts", systemImage: "doc.fill", count: 3),
        Mailbox(id: "archive", title: "Archive", systemImage: "archivebox.fill", count: nil),
        Mailbox(id: "trash", title: "Trash", systemImage: "trash.fill", count: nil)
    ]
}

struct MailMessage: Identifiable, Hashable {
    let id: String
    let sender: String
    let subject: String
    let preview: String
    let mailboxID: String

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
