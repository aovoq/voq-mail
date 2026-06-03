//
//  MailMessage+ReplyAssist.swift
//  VoqMail
//
//  Feature-owned (reply-assist) convenience on MailMessage: a plain-text
//  rendering of the body used as grounding context for AI reply drafting. Kept
//  off the core model so removing the feature is a single file deletion and the
//  AppKit/WebKit dependency of the extractor never enters the Models layer —
//  MailMessage.swift itself stays Foundation-only.
//
//  Read synchronously on the main actor (at `MailDraft.reply(to:)` construction
//  time) so the extractor takes its native WebKit path; see HTMLPlainText.
//

import Foundation

extension MailMessage {
    /// A plain-text rendering of the message body for AI reply context. Empty
    /// extractions fall back to the snippet `preview`.
    var plainTextBody: String {
        let extracted = HTMLPlainText.extract(fromHTML: htmlBody)
        return extracted.isEmpty ? preview : extracted
    }
}
