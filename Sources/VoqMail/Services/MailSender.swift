//
//  MailSender.swift
//  VoqMail
//
//  Orchestrates the two stateless steps of sending: build the RFC 2822 message
//  from the draft (`MimeMessageBuilder`), then hand the raw bytes to Gmail's
//  `users.messages.send` (`GmailClient`). Kept as its own struct so the view's
//  send path is a single call and the wire details stay out of the UI.
//

import Foundation

struct MailSender {
    var client = GmailClient()
    var builder = MimeMessageBuilder()

    func send(_ draft: MailDraft, accessToken: String) async throws {
        let raw = builder.makeRawMessage(draft)
        _ = try await client.sendMessage(raw: raw, threadId: draft.threadId, accessToken: accessToken)
    }
}
