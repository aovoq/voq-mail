//
//  MailDraft.swift
//  VoqMail
//
//  Editable state for the reply composer sheet.
//

import Foundation

struct MailDraft: Identifiable, Hashable {
    let id: String
    var to: [String]
    var subject: String
    var body: String
    var replyingToMessageID: MailMessage.ID?
}

extension MailDraft {
    static func reply(to message: MailMessage) -> MailDraft {
        MailDraft(
            id: UUID().uuidString,
            to: [message.senderAddress].filter { !$0.isEmpty },
            subject: replySubject(for: message.subject),
            body: replyBody(for: message),
            replyingToMessageID: message.id
        )
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
