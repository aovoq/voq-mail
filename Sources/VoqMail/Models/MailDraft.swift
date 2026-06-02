//
//  MailDraft.swift
//  VoqMail
//
//  Editable state for the composer sheet — both a fresh "New Message" and a
//  reply. A reply carries the thread-threading fields (threadId + the original
//  message's RFC Message-ID for In-Reply-To/References) so the sent message lands
//  back in the same Gmail conversation rather than starting a new one.
//

import Foundation

/// One file attached to an outgoing draft. The bytes are held in memory until the
/// draft is sent; the composer reads them off disk when the user picks a file.
struct DraftAttachment: Identifiable, Hashable {
    let id: String            // UUID().uuidString
    let filename: String
    let mimeType: String
    let data: Data
}

struct MailDraft: Identifiable, Hashable {
    let id: String
    /// The sending account's email — both the From address and the key deciding
    /// which token signs the send.
    var accountID: String
    var to: [String]
    var cc: [String]
    var bcc: [String]
    var subject: String
    var body: String
    var attachments: [DraftAttachment]
    /// Gmail thread to keep a reply in the same conversation (nil for a fresh
    /// compose, which starts a new thread).
    var threadId: String?
    /// Reserved for a future "save as draft" slice; stays nil for now.
    var draftId: String?
    /// The original message's RFC `Message-ID` header value (with angle brackets),
    /// echoed into In-Reply-To on a reply.
    var inReplyTo: String?
    /// References header chain that threads the reply.
    var references: String?
    var replyingToMessageID: MailMessage.ID?
}

extension MailDraft {
    /// A blank draft for a brand-new message sent from the given account.
    static func compose(from accountID: String) -> MailDraft {
        MailDraft(
            id: UUID().uuidString,
            accountID: accountID,
            to: [],
            cc: [],
            bcc: [],
            subject: "",
            body: "",
            attachments: [],
            threadId: nil,
            draftId: nil,
            inReplyTo: nil,
            references: nil,
            replyingToMessageID: nil
        )
    }

    static func reply(to message: MailMessage) -> MailDraft {
        MailDraft(
            id: UUID().uuidString,
            accountID: message.accountID,
            to: [message.senderAddress].filter { !$0.isEmpty },
            cc: [],
            bcc: [],
            subject: replySubject(for: message.subject),
            body: replyBody(for: message),
            attachments: [],
            threadId: message.threadId,
            draftId: nil,
            inReplyTo: message.rfcMessageID,
            references: referencesChain(for: message),
            replyingToMessageID: message.id
        )
    }

    /// The reply's `References` header per RFC 2822 §3.6.4: the parent's existing
    /// References chain followed by the parent's own Message-ID. Falls back to just
    /// the Message-ID when the parent had no References (a thread root), and to the
    /// existing chain alone if the parent somehow lacks a Message-ID.
    private static func referencesChain(for message: MailMessage) -> String? {
        let chain = message.rfcReferences?.trimmingCharacters(in: .whitespacesAndNewlines)
        switch (chain, message.rfcMessageID) {
        case let (chain?, messageID?) where !chain.isEmpty:
            return "\(chain) \(messageID)"
        case let (chain?, nil) where !chain.isEmpty:
            return chain
        case (_, let messageID):
            return messageID
        }
    }

    private static func replySubject(for subject: String) -> String {
        let alreadyReply = subject.range(of: "Re:", options: [.anchored, .caseInsensitive]) != nil
        return alreadyReply ? subject : "Re: \(subject)"
    }

    private static func replyBody(for message: MailMessage) -> String {
        let receivedAt = message.receivedAt.formatted(date: .abbreviated, time: .shortened)
        return "\n\nOn \(receivedAt), \(message.sender) wrote:\n\(message.preview)"
    }
}
