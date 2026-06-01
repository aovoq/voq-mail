//
//  MailMessage.swift
//  VoqMail
//
//  A single message. Belongs to a Mailbox via `mailboxID`. A plain value type;
//  its demo data lives in SampleData.swift.
//

import Foundation

/// A single mail message shown in a message list and detail pane.
struct MailMessage: Identifiable, Hashable {
    let id: String
    let sender: String
    let senderAddress: String
    let recipients: [String]
    let subject: String
    let preview: String
    let htmlBody: String
    let receivedAt: Date
    let isRead: Bool
    let attachments: [MailAttachment]
    /// Links this message to its `Mailbox.id`.
    let mailboxID: String

    init(
        id: String,
        sender: String,
        senderAddress: String = "",
        recipients: [String] = [],
        subject: String,
        preview: String,
        htmlBody: String? = nil,
        receivedAt: Date = Date(),
        isRead: Bool = true,
        attachments: [MailAttachment] = [],
        mailboxID: String
    ) {
        self.id = id
        self.sender = sender
        self.senderAddress = senderAddress
        self.recipients = recipients
        self.subject = subject
        self.preview = preview
        self.htmlBody = htmlBody ?? Self.plainTextHTML(from: preview)
        self.receivedAt = receivedAt
        self.isRead = isRead
        self.attachments = attachments
        self.mailboxID = mailboxID
    }

    private static func plainTextHTML(from text: String) -> String {
        let escapedText = text.htmlEscaped.replacingOccurrences(of: "\n", with: "<br>")

        return """
        <html>
        <body style="font: -apple-system-body; color: #1f2328;">
        <p>\(escapedText)</p>
        </body>
        </html>
        """
    }
}

extension MailMessage {
    /// The sample messages that belong to the given mailbox id.
    static func samples(in mailboxID: Mailbox.ID?) -> [MailMessage] {
        samples.filter { $0.mailboxID == mailboxID }
    }
}

private extension String {
    var htmlEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
