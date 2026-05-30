//
//  MailMessage.swift
//  VoqMail
//
//  A single message preview. Belongs to a Mailbox via `mailboxID`. A plain value
//  type; its demo data lives in SampleData.swift.
//

import Foundation

/// A single mail message shown in a message list and detail pane.
struct MailMessage: Identifiable, Hashable {
    let id: String
    let sender: String
    let subject: String
    let preview: String
    /// Links this message to its `Mailbox.id`.
    let mailboxID: String
}

extension MailMessage {
    /// The sample messages that belong to the given mailbox id.
    static func samples(in mailboxID: Mailbox.ID?) -> [MailMessage] {
        samples.filter { $0.mailboxID == mailboxID }
    }
}
