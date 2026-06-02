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
    /// The Gmail label ids on this message. Read state is derived from these (the
    /// `UNREAD` label) rather than stored, so a label toggle flips `isRead`. Kept
    /// mutable so the store can update it optimistically.
    var labelIds: [String]
    let attachments: [MailAttachment]
    /// The Gmail thread (conversation) this message belongs to. A reply reuses it
    /// so the sent message stays in the same conversation.
    let threadId: String
    /// The RFC `Message-ID` header value (with angle brackets), used to thread a
    /// reply via In-Reply-To/References. Absent for sample data.
    let rfcMessageID: String?
    /// The original `References` header value (a space-separated chain of
    /// Message-IDs), carried so a reply can extend the chain per RFC 2822 §3.6.4
    /// rather than dropping it. Absent for sample data / a thread root.
    let rfcReferences: String?
    /// Links this message to its `Mailbox.id`.
    let mailboxID: String
    /// The account (email) this message belongs to. Decides which token fetches
    /// its body/attachments and keys it apart from a same-id message in another
    /// account (so `Hashable` no longer collides across accounts).
    let accountID: String

    /// True unless the message still carries Gmail's `UNREAD` label.
    var isRead: Bool { !labelIds.contains("UNREAD") }

    init(
        id: String,
        sender: String,
        senderAddress: String = "",
        recipients: [String] = [],
        subject: String,
        preview: String,
        htmlBody: String? = nil,
        receivedAt: Date = Date(),
        labelIds: [String] = [],
        attachments: [MailAttachment] = [],
        threadId: String = "",
        rfcMessageID: String? = nil,
        rfcReferences: String? = nil,
        mailboxID: String,
        accountID: String
    ) {
        self.id = id
        self.sender = sender
        self.senderAddress = senderAddress
        self.recipients = recipients
        self.subject = subject
        self.preview = preview
        self.htmlBody = htmlBody ?? Self.plainTextHTML(from: preview)
        self.receivedAt = receivedAt
        self.labelIds = labelIds
        self.attachments = attachments
        self.threadId = threadId
        self.rfcMessageID = rfcMessageID
        self.rfcReferences = rfcReferences
        self.mailboxID = mailboxID
        self.accountID = accountID
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

    /// A copy with the body and attachments replaced by fetched content. Used to
    /// merge a loaded full message onto its list-row metadata.
    func with(htmlBody: String, attachments: [MailAttachment]) -> MailMessage {
        MailMessage(
            id: id,
            sender: sender,
            senderAddress: senderAddress,
            recipients: recipients,
            subject: subject,
            preview: preview,
            htmlBody: htmlBody,
            receivedAt: receivedAt,
            labelIds: labelIds,
            attachments: attachments,
            threadId: threadId,
            rfcMessageID: rfcMessageID,
            rfcReferences: rfcReferences,
            mailboxID: mailboxID,
            accountID: accountID)
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
